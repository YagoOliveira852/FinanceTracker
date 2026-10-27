"""Confirmar, ignorar e confirmar em lote na revisão: a categoria ensina as
regras e nada é apagado."""

import uuid
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.modulos.cartoes import service as cartoes_service
from app.modulos.categorias.models import Categoria, RegraClassificacao
from tests.utils import HOJE, criar_conta, criar_transacao


@pytest.fixture
def conta(sessao):
    return criar_conta(sessao)


@pytest.fixture
def categoria(sessao):
    def _por_nome(nome: str) -> Categoria:
        return sessao.scalars(select(Categoria).where(Categoria.nome == nome)).one()

    return _por_nome


def _regra(sessao, padrao, categoria, origem="aprendida", vezes=0) -> RegraClassificacao:
    regra = RegraClassificacao(
        padrao=padrao, categoria_id=categoria.id, origem=origem, vezes_aplicada=vezes
    )
    sessao.add(regra)
    sessao.flush()
    return regra


def _regras(sessao) -> list[RegraClassificacao]:
    return list(sessao.scalars(select(RegraClassificacao).order_by(RegraClassificacao.padrao)))


def _confirmar(api, transacao, categoria, descricao=None, **extra):
    corpo = {"descricao": descricao or transacao.descricao, "categoria_id": str(categoria.id)}
    return api.post(f"/revisao/transacoes/{transacao.id}/confirmar", json=corpo | extra)


def test_confirmar_sem_regra_cria_a_aprendida(api, sessao, conta, categoria):
    transacao = criar_transacao(sessao, conta, "POSTO FICTICIO 0193 FORTALEZA BR")

    resposta = _confirmar(api, transacao, categoria("Transporte"), "Posto Fictício")

    assert resposta.status_code == 200, resposta.text
    assert resposta.json() == {"efeito": "criada", "regra_padrao": "posto ficticio fortaleza br"}
    sessao.refresh(transacao)
    assert transacao.status == "confirmada"
    assert transacao.categoria.nome == "Transporte"
    assert transacao.descricao == "Posto Fictício"
    assert transacao.descricao_original == "POSTO FICTICIO 0193 FORTALEZA BR"
    (regra,) = _regras(sessao)
    assert (regra.padrao, regra.categoria.nome, regra.origem) == (
        "posto ficticio fortaleza br",
        "Transporte",
        "aprendida",
    )


def test_corrigir_aprendida_troca_a_categoria_e_zera(api, sessao, conta, categoria):
    regra = _regra(sessao, "lanchonete exemplo", categoria("Lazer"), vezes=3)
    transacao = criar_transacao(sessao, conta, "PIX ENVIADO 25/10 LANCHONETE EXEMPLO")

    resposta = _confirmar(api, transacao, categoria("Alimentação"))

    assert resposta.json()["efeito"] == "corrigida"
    sessao.refresh(regra)
    assert (regra.categoria.nome, regra.vezes_aplicada) == ("Alimentação", 0)


def test_corrigir_manual_mantem_a_regra(api, sessao, conta, categoria):
    regra = _regra(sessao, "lanchonete", categoria("Lazer"), origem="manual")
    transacao = criar_transacao(sessao, conta, "LANCHONETE EXEMPLO")

    resposta = _confirmar(api, transacao, categoria("Alimentação"))

    assert resposta.json() == {"efeito": "manual_mantida", "regra_padrao": "lanchonete"}
    sessao.refresh(regra)
    assert regra.categoria.nome == "Lazer"
    sessao.refresh(transacao)
    assert transacao.categoria.nome == "Alimentação"


def test_categoria_incompativel_com_o_tipo(api, sessao, conta, categoria):
    transacao = criar_transacao(sessao, conta)

    resposta = _confirmar(api, transacao, categoria("Salário"))

    assert resposta.status_code == 422
    assert resposta.json()["campos"][0]["campo"] == "body.categoria_id"
    sessao.refresh(transacao)
    assert transacao.status == "rascunho"


def test_categoria_obrigatoria(api, sessao, conta):
    transacao = criar_transacao(sessao, conta)

    resposta = api.post(
        f"/revisao/transacoes/{transacao.id}/confirmar", json={"descricao": "Padaria"}
    )

    assert resposta.status_code == 422
    assert resposta.json()["campos"][0]["campo"] == "body.categoria_id"


def test_saida_nao_vira_entrada(api, sessao, conta, categoria):
    transacao = criar_transacao(sessao, conta)

    resposta = _confirmar(api, transacao, categoria("Salário"), tipo="receita")

    assert resposta.status_code == 422
    assert resposta.json()["campos"][0]["campo"] == "body.tipo"


def test_receita_vira_estorno_com_categoria_de_gasto(api, sessao, conta, categoria):
    transacao = criar_transacao(sessao, conta, "ESTORNO PADARIA PAO QUENTE", tipo="receita")

    resposta = _confirmar(api, transacao, categoria("Alimentação"), tipo="estorno")

    assert resposta.status_code == 200, resposta.text
    sessao.refresh(transacao)
    assert (transacao.tipo, transacao.categoria.nome) == ("estorno", "Alimentação")


def test_pagamento_que_era_outra_coisa_perde_a_fatura(api, sessao, conta, categoria):
    cartao = cartoes_service.criar_cartao(
        sessao,
        nome="Cartão Exemplo",
        nome_instituicao="Banco Exemplo",
        conta_pagamento_id=conta.id,
        dia_fechamento=3,
        dia_vencimento=10,
        limite=None,
        hoje=HOJE,
    )
    fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, date(2026, 11, 1))
    transacao = criar_transacao(
        sessao, conta, "PAGAMENTO LOJA EXEMPLO", tipo="pagamento_fatura", fatura_id=fatura.id
    )

    resposta = _confirmar(api, transacao, categoria("Compras"), tipo="despesa")

    assert resposta.status_code == 200, resposta.text
    sessao.refresh(transacao)
    assert (transacao.tipo, transacao.fatura_id) == ("despesa", None)


def test_compra_no_cartao_mantem_a_fatura(api, sessao, conta, categoria):
    cartao = cartoes_service.criar_cartao(
        sessao,
        nome="Cartão Exemplo",
        nome_instituicao="Banco Exemplo",
        conta_pagamento_id=conta.id,
        dia_fechamento=3,
        dia_vencimento=10,
        limite=None,
        hoje=HOJE,
    )
    fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, date(2026, 11, 1))
    transacao = criar_transacao(sessao, cartao.conta, "STREAMING EXEMPLO", fatura_id=fatura.id)

    _confirmar(api, transacao, categoria("Assinaturas"))

    sessao.refresh(transacao)
    assert transacao.fatura_id == fatura.id


def test_confirmar_de_novo_e_conflito(api, sessao, conta, categoria):
    transacao = criar_transacao(sessao, conta, status="confirmada")

    resposta = _confirmar(api, transacao, categoria("Alimentação"))

    assert resposta.status_code == 409
    assert resposta.json()["detail"] == "Esta transação já foi revisada."


def test_confirmar_inexistente(api, categoria):
    resposta = api.post(
        f"/revisao/transacoes/{uuid.uuid4()}/confirmar",
        json={"descricao": "Padaria", "categoria_id": str(categoria("Alimentação").id)},
    )

    assert resposta.status_code == 404
    assert resposta.json()["detail"] == "Transação não encontrada."


def test_ignorar(api, sessao, conta):
    transacao = criar_transacao(sessao, conta)

    resposta = api.post(f"/revisao/transacoes/{transacao.id}/ignorar")

    assert resposta.status_code == 204
    sessao.refresh(transacao)
    assert transacao.status == "ignorada"
    assert api.get("/revisao").json()["total"] == 0


def test_ignorar_ja_ignorada_e_conflito(api, sessao, conta):
    transacao = criar_transacao(sessao, conta, status="ignorada")

    assert api.post(f"/revisao/transacoes/{transacao.id}/ignorar").status_code == 409


def test_lote_confirma_so_os_sugeridos(api, sessao, conta, categoria):
    regra = _regra(sessao, "padaria pao quente", categoria("Alimentação"), vezes=1)
    sugerido = criar_transacao(sessao, conta, "PADARIA PAO QUENTE")
    sem_sugestao = criar_transacao(sessao, conta, "POSTO FICTICIO")
    ja_confirmado = criar_transacao(sessao, conta, "PADARIA PAO QUENTE", status="confirmada")

    resposta = api.post(
        "/revisao/confirmar-lote",
        json={"ids": [str(t.id) for t in (sugerido, sem_sugestao, ja_confirmado, sugerido)]},
    )

    assert resposta.status_code == 200, resposta.text
    assert resposta.json() == {"confirmados": 1}
    sessao.refresh(sugerido)
    sessao.refresh(sem_sugestao)
    sessao.refresh(regra)
    assert (sugerido.status, sugerido.categoria.nome) == ("confirmada", "Alimentação")
    assert sem_sugestao.status == "rascunho"
    assert regra.vezes_aplicada == 2


def test_lote_nao_confirma_decisoes(api, sessao, conta, categoria):
    dia_a_dia = criar_conta(sessao, "Conta do dia a dia")
    _regra(sessao, "conta dia a dia", categoria("Lazer"))
    saida = criar_transacao(sessao, conta, "CONTA DIA A DIA", valor=Decimal("300.00"))
    criar_transacao(sessao, dia_a_dia, "CONTA PRINCIPAL", tipo="receita", valor=Decimal("300.00"))

    resposta = api.post("/revisao/confirmar-lote", json={"ids": [str(saida.id)]})

    assert resposta.json() == {"confirmados": 0}


@pytest.mark.parametrize("corpo", [{"ids": []}, {"ids": ["nao-e-uuid"]}, {}])
def test_lote_invalido(api, corpo):
    assert api.post("/revisao/confirmar-lote", json=corpo).status_code == 422
