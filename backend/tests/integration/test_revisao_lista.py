"""`GET /revisao`: decisões, rascunhos comuns com a sugestão calculada agora e
o contador (spec `2026-10-19-revisao-classificacao`)."""

from datetime import UTC, date, datetime
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.modulos.cartoes import service as cartoes_service
from app.modulos.categorias.models import Categoria, RegraClassificacao
from app.modulos.revisao.models import ParRecusado
from tests.utils import HOJE, criar_conta, criar_transacao


@pytest.fixture
def conta(sessao):
    return criar_conta(sessao)


@pytest.fixture
def dia_a_dia(sessao):
    return criar_conta(sessao, "Conta do dia a dia")


@pytest.fixture
def categoria(sessao):
    def _por_nome(nome: str) -> Categoria:
        return sessao.scalars(select(Categoria).where(Categoria.nome == nome)).one()

    return _por_nome


@pytest.fixture
def cartao(sessao, conta):
    return cartoes_service.criar_cartao(
        sessao,
        nome="Cartão Exemplo",
        nome_instituicao="Banco Exemplo",
        conta_pagamento_id=conta.id,
        dia_fechamento=3,
        dia_vencimento=10,
        limite=None,
        hoje=HOJE,
    )


def _regra(sessao, padrao, categoria, origem="aprendida", **mudancas) -> RegraClassificacao:
    regra = RegraClassificacao(
        padrao=padrao, categoria_id=categoria.id, origem=origem, vezes_aplicada=0, **mudancas
    )
    sessao.add(regra)
    sessao.flush()
    return regra


def _lista(api) -> dict:
    resposta = api.get("/revisao")
    assert resposta.status_code == 200, resposta.text
    return resposta.json()


def test_sem_nada_para_revisar(api):
    assert _lista(api) == {
        "total": 0,
        "qtd_sugeridos": 0,
        "pares": [],
        "pagamentos": [],
        "duplicatas": [],
        "sumidas": [],
        "rascunhos": [],
    }


def test_rascunho_sem_regra_aprende_ao_confirmar(api, sessao, conta):
    criar_transacao(sessao, conta, "POSTO FICTICIO 0193 FORTALEZA BR", valor=Decimal("150.00"))

    corpo = _lista(api)

    (rascunho,) = corpo["rascunhos"]
    assert corpo["total"] == 1
    assert corpo["qtd_sugeridos"] == 0
    assert rascunho["sugestao"] is None
    assert rascunho["padrao"] == "posto ficticio fortaleza br"
    assert rascunho["efeito_confirmando"] == "criada"
    assert rascunho["efeito_corrigindo"] == "criada"
    assert rascunho["valor"] == "150.00"
    assert rascunho["conta"] == {"id": str(conta.id), "nome": "Conta principal", "tipo": "corrente"}
    assert rascunho["fonte"] == "pluggy"
    assert rascunho["fatura_competencia"] is None


def test_rascunho_com_sugestao_e_os_dois_efeitos(api, sessao, conta, categoria):
    regra = _regra(sessao, "lanchonete exemplo", categoria("Lazer"))
    criar_transacao(sessao, conta, "PIX ENVIADO 25/10 LANCHONETE EXEMPLO LTDA")

    corpo = _lista(api)

    (rascunho,) = corpo["rascunhos"]
    assert rascunho["sugestao"] == {
        "regra_id": str(regra.id),
        "padrao": "lanchonete exemplo",
        "origem": "aprendida",
        "categoria": {"id": str(categoria("Lazer").id), "nome": "Lazer", "grupo": "variavel"},
    }
    assert rascunho["efeito_confirmando"] == "reforcada"
    assert rascunho["efeito_corrigindo"] == "especializada"
    assert corpo["qtd_sugeridos"] == 1


@pytest.mark.parametrize(
    ("padrao", "origem", "corrigindo"),
    [
        ("lanchonete exemplo ltda", "aprendida", "corrigida"),
        ("lanchonete", "manual", "manual_mantida"),
    ],
)
def test_efeito_corrigindo(api, sessao, conta, categoria, padrao, origem, corrigindo):
    _regra(sessao, padrao, categoria("Lazer"), origem)
    criar_transacao(sessao, conta, "PIX ENVIADO 25/10 LANCHONETE EXEMPLO LTDA")

    (rascunho,) = _lista(api)["rascunhos"]

    assert rascunho["efeito_corrigindo"] == corrigindo


def test_descricao_so_com_termos_genericos_nao_aprende(api, sessao, conta):
    criar_transacao(sessao, conta, "Pagamento recebido", tipo="receita")

    (rascunho,) = _lista(api)["rascunhos"]

    assert rascunho["padrao"] == ""
    assert rascunho["efeito_confirmando"] == "nenhuma"


def test_regra_de_categoria_desativada_nao_sugere(api, sessao, conta, categoria):
    lazer = categoria("Lazer")
    _regra(sessao, "lanchonete exemplo", lazer)
    lazer.ativa = False
    criar_transacao(sessao, conta, "LANCHONETE EXEMPLO")

    corpo = _lista(api)

    assert corpo["rascunhos"][0]["sugestao"] is None
    assert corpo["qtd_sugeridos"] == 0


def test_regra_de_renda_nao_sugere_para_despesa(api, sessao, conta, categoria):
    _regra(sessao, "fulano de tal", categoria("Outras receitas"))
    criar_transacao(sessao, conta, "Transferência enviada pelo Pix - Fulano de Tal")

    assert _lista(api)["rascunhos"][0]["sugestao"] is None


def test_entrada_traz_sugestao_e_efeitos_do_outro_tipo(api, sessao, conta, categoria):
    """A sugestão depende do tipo: como receita, a regra de renda; como estorno,
    a de gasto. A folha mostra o efeito certo ao trocar o tipo."""
    renda = _regra(sessao, "loja exemplo", categoria("Outras receitas"))
    gasto = _regra(sessao, "loja exemplo", categoria("Compras"))
    criar_transacao(sessao, conta, "LOJA EXEMPLO", tipo="receita")

    (rascunho,) = _lista(api)["rascunhos"]

    assert rascunho["sugestao"]["regra_id"] == str(renda.id)
    (estorno,) = rascunho["outros_tipos"]
    assert estorno["tipo"] == "estorno"
    assert estorno["sugestao"]["regra_id"] == str(gasto.id)
    assert estorno["efeito_confirmando"] == "reforcada"
    assert estorno["efeito_corrigindo"] == "corrigida"


def test_outro_tipo_sem_regra_compativel_cria(api, sessao, conta, categoria):
    _regra(sessao, "loja exemplo", categoria("Outras receitas"))
    criar_transacao(sessao, conta, "LOJA EXEMPLO", tipo="receita")

    (rascunho,) = _lista(api)["rascunhos"]

    (estorno,) = rascunho["outros_tipos"]
    assert estorno["sugestao"] is None
    assert estorno["efeito_confirmando"] == "criada"
    assert estorno["efeito_corrigindo"] == "criada"


def test_saida_nao_tem_outro_tipo(api, sessao, conta):
    criar_transacao(sessao, conta, "PADARIA PAO QUENTE")

    (rascunho,) = _lista(api)["rascunhos"]

    assert rascunho["outros_tipos"] == []


@pytest.mark.parametrize("tipo", ["aporte", "resgate"])
def test_aporte_e_resgate_so_tem_o_proprio_tipo(api, sessao, conta, tipo):
    criar_transacao(sessao, conta, "DINHEIRO RESERVADO COFRINHO", tipo=tipo)

    (rascunho,) = _lista(api)["rascunhos"]

    assert rascunho["tipo"] == tipo
    assert rascunho["outros_tipos"] == []


def test_entrada_sem_categoria_traz_receita_e_estorno(api, sessao, conta):
    criar_transacao(sessao, conta, "PIX RECEBIDO FULANO", tipo="transferencia_entrada")

    (rascunho,) = _lista(api)["rascunhos"]

    assert [o["tipo"] for o in rascunho["outros_tipos"]] == ["receita", "estorno"]


def test_rascunhos_da_data_mais_recente(api, sessao, conta):
    criar_transacao(sessao, conta, "PADARIA PAO QUENTE", data=date(2026, 10, 18))
    criar_transacao(sessao, conta, "STREAMING EXEMPLO", data=date(2026, 10, 19))

    corpo = _lista(api)

    descricoes = [r["descricao"] for r in corpo["rascunhos"]]
    assert descricoes == ["STREAMING EXEMPLO", "PADARIA PAO QUENTE"]


def test_confirmadas_e_ignoradas_ficam_fora(api, sessao, conta):
    criar_transacao(sessao, conta, status="confirmada")
    criar_transacao(sessao, conta, status="ignorada")

    assert _lista(api)["total"] == 0


def test_tipo_sem_categoria_nao_tem_efeito(api, sessao, conta):
    criar_transacao(sessao, conta, "TRANSFERENCIA ENVIADA", tipo="transferencia_saida")

    (rascunho,) = _lista(api)["rascunhos"]

    assert rascunho["efeito_confirmando"] == "nenhuma"
    assert rascunho["efeito_corrigindo"] == "nenhuma"


def test_par_conta_um_e_os_lados_nao_aparecem_como_comuns(api, sessao, conta, dia_a_dia):
    saida = criar_transacao(sessao, conta, "PIX ENVIADO CONTA DIA A DIA", valor=Decimal("300.00"))
    entrada = criar_transacao(
        sessao,
        dia_a_dia,
        "PIX RECEBIDO CONTA PRINCIPAL",
        tipo="receita",
        valor=Decimal("300.00"),
        data=date(2026, 10, 20),
    )

    corpo = _lista(api)

    assert corpo["total"] == 1
    assert corpo["rascunhos"] == []
    (par,) = corpo["pares"]
    assert par["saida"]["id"] == str(saida.id)
    assert par["entrada"]["id"] == str(entrada.id)
    assert par["dias"] == 1


def test_par_recusado_volta_como_dois_comuns(api, sessao, conta, dia_a_dia):
    saida = criar_transacao(sessao, conta, valor=Decimal("300.00"))
    entrada = criar_transacao(sessao, dia_a_dia, tipo="receita", valor=Decimal("300.00"))
    sessao.add(ParRecusado(saida_id=saida.id, entrada_id=entrada.id))
    sessao.flush()

    corpo = _lista(api)

    assert corpo["pares"] == []
    assert corpo["total"] == 2


def test_cartao_nao_entra_em_par(api, sessao, conta, cartao):
    criar_transacao(sessao, cartao.conta, valor=Decimal("300.00"))
    criar_transacao(sessao, conta, tipo="receita", valor=Decimal("300.00"))

    assert _lista(api)["pares"] == []


def test_cartao_mostra_a_competencia_da_fatura(api, sessao, cartao):
    fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, date(2026, 11, 1))
    criar_transacao(sessao, cartao.conta, fatura_id=fatura.id)

    (rascunho,) = _lista(api)["rascunhos"]

    assert rascunho["fatura_competencia"] == "2026-11-01"
    assert rascunho["conta"]["tipo"] == "cartao_credito"


def test_pagamento_de_fatura_e_uma_decisao(api, sessao, conta):
    criar_transacao(sessao, conta, "PAGAMENTO DE FATURA", tipo="pagamento_fatura")

    corpo = _lista(api)

    assert corpo["rascunhos"] == []
    assert [p["descricao"] for p in corpo["pagamentos"]] == ["PAGAMENTO DE FATURA"]
    assert corpo["total"] == 1


def test_duplicata_mostra_as_duas_e_conta_uma(api, sessao, conta, categoria):
    outra = criar_transacao(
        sessao,
        conta,
        "COMPRA NO DEBITO MERCADO DO BAIRRO",
        fonte="ofx",
        status="confirmada",
        categoria_id=categoria("Mercado").id,
        descricao="Mercado do bairro",
    )
    rascunho = criar_transacao(
        sessao, conta, "MERCADO DO BAIRRO LTDA", possivel_duplicata_de=outra.id
    )

    corpo = _lista(api)

    (duplicata,) = corpo["duplicatas"]
    assert duplicata["rascunho"]["id"] == str(rascunho.id)
    assert duplicata["outra"]["id"] == str(outra.id)
    assert duplicata["outra"]["categoria"]["nome"] == "Mercado"
    assert corpo["total"] == 1


def test_duplicata_entre_rascunhos_nao_repete_a_outra(api, sessao, conta):
    outra = criar_transacao(sessao, conta, "MERCADO DO BAIRRO", fonte="ofx")
    criar_transacao(sessao, conta, "MERCADO DO BAIRRO LTDA", possivel_duplicata_de=outra.id)

    corpo = _lista(api)

    assert corpo["rascunhos"] == []
    assert corpo["total"] == 1


def test_duplicata_de_uma_ignorada_vira_comum(api, sessao, conta):
    outra = criar_transacao(sessao, conta, fonte="ofx", status="ignorada")
    criar_transacao(sessao, conta, possivel_duplicata_de=outra.id)

    corpo = _lista(api)

    assert corpo["duplicatas"] == []
    assert len(corpo["rascunhos"]) == 1


def test_duplicata_nao_entra_em_par(api, sessao, conta, dia_a_dia):
    outra = criar_transacao(sessao, conta, valor=Decimal("300.00"), status="confirmada")
    criar_transacao(sessao, conta, valor=Decimal("300.00"), possivel_duplicata_de=outra.id)
    criar_transacao(sessao, dia_a_dia, tipo="receita", valor=Decimal("300.00"))

    corpo = _lista(api)

    assert corpo["pares"] == []
    assert len(corpo["duplicatas"]) == 1
    assert len(corpo["rascunhos"]) == 1


def test_confirmada_que_sumiu_da_origem(api, sessao, conta):
    momento = datetime(2026, 10, 20, 10, 0, tzinfo=UTC)
    sumida = criar_transacao(sessao, conta, status="confirmada", removida_na_origem_em=momento)

    corpo = _lista(api)

    (item,) = corpo["sumidas"]
    assert item["id"] == str(sumida.id)
    assert item["removida_na_origem_em"] == "2026-10-20T10:00:00Z"
    assert corpo["total"] == 1


def test_sem_token(client):
    assert client.get("/revisao").status_code == 401
