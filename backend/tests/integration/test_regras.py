"""Regras de classificação pela API: cadastro, edição, exclusão e os rascunhos
que cada regra sugere agora."""

import uuid
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.modulos.categorias.models import Categoria, RegraClassificacao
from app.modulos.transacoes.models import Transacao


@pytest.fixture
def conta(api) -> dict:
    return _conta(api, "Conta principal")


@pytest.fixture
def carteira(api) -> dict:
    resposta = api.post(
        "/contas",
        json={
            "nome": "Carteira",
            "tipo": "carteira",
            "saldo_inicial": "0.00",
            "data_saldo_inicial": "2026-10-01",
        },
    )
    assert resposta.status_code == 201
    return resposta.json()


def _conta(api, nome: str) -> dict:
    resposta = api.post(
        "/contas",
        json={
            "nome": nome,
            "tipo": "corrente",
            "instituicao": "Banco Exemplo",
            "saldo_inicial": "0.00",
            "data_saldo_inicial": "2026-10-01",
        },
    )
    assert resposta.status_code == 201
    return resposta.json()


def _categoria(sessao, nome: str) -> str:
    return str(sessao.scalars(select(Categoria.id).where(Categoria.nome == nome)).one())


def _criar(api, **campos) -> dict:
    resposta = api.post("/regras", json=campos)
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


def _rascunho(sessao, conta, descricao, data=date(2026, 10, 19), **mudancas) -> Transacao:
    dados = {
        "conta_id": uuid.UUID(conta["id"]),
        "tipo": "despesa",
        "valor": Decimal("18.50"),
        "data": data,
        "descricao_original": descricao,
        "descricao": descricao.title(),
        "status": "rascunho",
        "fonte": "pluggy",
        "id_externo": str(uuid.uuid4()),
    }
    transacao = Transacao(**(dados | mudancas))
    sessao.add(transacao)
    sessao.flush()
    return transacao


def _campos(resposta) -> dict:
    assert resposta.status_code == 422, resposta.json()
    return {erro["campo"]: erro["mensagem"] for erro in resposta.json()["campos"]}


# --- cadastro ----------------------------------------------------------------


def test_cria_regra_manual_com_padrao_normalizado(api, sessao):
    alimentacao = _categoria(sessao, "Alimentação")

    regra = _criar(api, padrao="  Padaria Pão Quente 0349 ", categoria_id=alimentacao)

    assert regra["padrao"] == "padaria pao quente"
    assert regra["categoria"] == {"id": alimentacao, "nome": "Alimentação", "grupo": "variavel"}
    assert regra["conta"] is None
    assert regra["origem"] == "manual"
    assert regra["vezes_aplicada"] == 0
    assert regra["rascunhos"] == {"quantidade": 0, "exemplo": None}


def test_regra_restrita_a_uma_conta(api, sessao, conta):
    regra = _criar(
        api, padrao="posto", categoria_id=_categoria(sessao, "Transporte"), conta_id=conta["id"]
    )

    assert regra["conta"] == {"id": conta["id"], "nome": "Conta principal"}


def test_padrao_so_com_termos_genericos_e_recusado(api, sessao):
    resposta = api.post(
        "/regras", json={"padrao": "PIX ENVIADO 25/10", "categoria_id": _categoria(sessao, "Lazer")}
    )

    assert _campos(resposta) == {
        "body.padrao": "O padrão ficou vazio: use o nome do estabelecimento ou da pessoa."
    }


def test_categoria_desativada_ou_inexistente_e_recusada(api, sessao):
    educacao = sessao.scalars(select(Categoria).where(Categoria.nome == "Educação")).one()
    educacao.ativa = False
    sessao.flush()

    desativada = api.post("/regras", json={"padrao": "curso", "categoria_id": str(educacao.id)})
    inexistente = api.post("/regras", json={"padrao": "curso", "categoria_id": str(uuid.uuid4())})

    assert _campos(desativada) == {"body.categoria_id": "Esta categoria está desativada."}
    assert _campos(inexistente) == {"body.categoria_id": "Categoria não encontrada."}


def test_conta_inexistente_e_recusada(api, sessao):
    resposta = api.post(
        "/regras",
        json={
            "padrao": "posto",
            "categoria_id": _categoria(sessao, "Transporte"),
            "conta_id": str(uuid.uuid4()),
        },
    )

    assert _campos(resposta) == {"body.conta_id": "Conta não encontrada."}


def test_regra_repetida_na_mesma_natureza_e_recusada(api, sessao):
    _criar(api, padrao="fulano", categoria_id=_categoria(sessao, "Lazer"))

    resposta = api.post(
        "/regras", json={"padrao": "Fulano", "categoria_id": _categoria(sessao, "Mercado")}
    )

    assert _campos(resposta) == {"body.padrao": "Já existe uma regra com esse padrão."}


def test_mesmo_padrao_em_outra_natureza_ou_outra_conta_e_aceito(api, sessao, conta):
    _criar(api, padrao="fulano", categoria_id=_categoria(sessao, "Lazer"))

    _criar(api, padrao="fulano", categoria_id=_categoria(sessao, "Outras receitas"))
    _criar(api, padrao="fulano", categoria_id=_categoria(sessao, "Lazer"), conta_id=conta["id"])

    assert len(api.get("/regras").json()) == 3


def test_lista_manuais_primeiro_e_depois_as_mais_usadas(api, sessao):
    lazer = uuid.UUID(_categoria(sessao, "Lazer"))
    sessao.add_all(
        [
            RegraClassificacao(
                padrao="cinema", categoria_id=lazer, origem="aprendida", vezes_aplicada=2
            ),
            RegraClassificacao(
                padrao="teatro", categoria_id=lazer, origem="aprendida", vezes_aplicada=5
            ),
        ]
    )
    sessao.flush()
    _criar(api, padrao="show", categoria_id=str(lazer))

    assert [r["padrao"] for r in api.get("/regras").json()] == ["show", "teatro", "cinema"]


# --- edição e exclusão -------------------------------------------------------


def test_editar_aprendida_torna_manual_e_mantem_a_contagem(api, sessao, conta):
    regra = RegraClassificacao(
        padrao="padaria pao quente",
        categoria_id=uuid.UUID(_categoria(sessao, "Lazer")),
        origem="aprendida",
        vezes_aplicada=3,
    )
    sessao.add(regra)
    sessao.flush()

    resposta = api.put(
        f"/regras/{regra.id}",
        json={
            "padrao": "padaria",
            "categoria_id": _categoria(sessao, "Alimentação"),
            "conta_id": conta["id"],
        },
    )

    assert resposta.status_code == 200, resposta.json()
    corpo = resposta.json()
    assert corpo["padrao"] == "padaria"
    assert corpo["categoria"]["nome"] == "Alimentação"
    assert corpo["conta"]["id"] == conta["id"]
    assert corpo["origem"] == "manual"
    assert corpo["vezes_aplicada"] == 3


def test_editar_sem_mudar_nao_conta_como_repetida(api, sessao):
    lazer = _categoria(sessao, "Lazer")
    regra = _criar(api, padrao="cinema", categoria_id=lazer)

    resposta = api.put(f"/regras/{regra['id']}", json={"padrao": "Cinema", "categoria_id": lazer})

    assert resposta.status_code == 200


def test_editar_mantendo_categoria_desativada_e_aceito(api, sessao):
    regra = _criar(api, padrao="curso", categoria_id=_categoria(sessao, "Educação"))
    educacao = sessao.get(Categoria, uuid.UUID(regra["categoria"]["id"]))
    educacao.ativa = False
    sessao.flush()

    resposta = api.put(
        f"/regras/{regra['id']}",
        json={"padrao": "curso de ingles", "categoria_id": regra["categoria"]["id"]},
    )

    assert resposta.status_code == 200


def test_exclui_regra(api, sessao):
    regra = _criar(api, padrao="cinema", categoria_id=_categoria(sessao, "Lazer"))

    resposta = api.delete(f"/regras/{regra['id']}")

    assert resposta.status_code == 204
    assert api.get(f"/regras/{regra['id']}").status_code == 404


@pytest.mark.parametrize("metodo", ["get", "put", "delete"])
def test_regra_inexistente_e_404(api, sessao, metodo):
    corpo = {"padrao": "cinema", "categoria_id": _categoria(sessao, "Lazer")}
    kwargs = {"json": corpo} if metodo == "put" else {}

    resposta = getattr(api, metodo)(f"/regras/{uuid.uuid4()}", **kwargs)

    assert resposta.status_code == 404
    assert resposta.json() == {"detail": "Regra não encontrada."}


def test_sem_token_e_401(client):
    assert client.get("/regras").status_code == 401


# --- rascunhos que a regra sugere --------------------------------------------


def test_conta_os_rascunhos_que_a_regra_sugere_com_o_mais_recente(api, sessao, conta):
    _rascunho(sessao, conta, "PIX ENVIADO 12/10 PADARIA PAO QUENTE", data=date(2026, 10, 12))
    _rascunho(sessao, conta, "PADARIA PAO QUENTE 0349", data=date(2026, 10, 25))
    _rascunho(sessao, conta, "MERCADO DO BAIRRO")

    regra = _criar(api, padrao="padaria", categoria_id=_categoria(sessao, "Alimentação"))

    assert regra["rascunhos"] == {
        "quantidade": 2,
        "exemplo": {"descricao": "Padaria Pao Quente 0349", "data": "2026-10-25"},
    }
    assert api.get(f"/regras/{regra['id']}").json()["rascunhos"]["quantidade"] == 2


def test_nao_conta_o_que_nao_e_rascunho_sem_categoria(api, sessao, conta):
    lazer = _categoria(sessao, "Lazer")
    _rascunho(sessao, conta, "CINEMA EXEMPLO", status="confirmada")
    _rascunho(sessao, conta, "CINEMA EXEMPLO", status="ignorada")
    _rascunho(sessao, conta, "CINEMA EXEMPLO", categoria_id=uuid.UUID(lazer))
    _rascunho(sessao, conta, "CINEMA EXEMPLO", tipo="transferencia_saida")

    regra = _criar(api, padrao="cinema", categoria_id=lazer)

    assert regra["rascunhos"]["quantidade"] == 0


def test_nao_conta_rascunho_de_tipo_incompativel(api, sessao, conta):
    _rascunho(sessao, conta, "PIX RECEBIDO FULANO", tipo="receita")
    _rascunho(sessao, conta, "PIX ENVIADO FULANO")

    gasto = _criar(api, padrao="fulano", categoria_id=_categoria(sessao, "Lazer"))
    renda = _criar(api, padrao="fulano", categoria_id=_categoria(sessao, "Outras receitas"))

    assert gasto["rascunhos"]["quantidade"] == 1
    assert renda["rascunhos"]["quantidade"] == 1


def test_nao_conta_rascunho_de_outra_conta(api, sessao, conta, carteira):
    _rascunho(sessao, carteira, "POSTO FICTICIO")

    regra = _criar(
        api, padrao="posto", categoria_id=_categoria(sessao, "Transporte"), conta_id=conta["id"]
    )

    assert regra["rascunhos"]["quantidade"] == 0


def test_conta_so_os_que_a_regra_vence(api, sessao, conta):
    _rascunho(sessao, conta, "PADARIA PAO QUENTE")
    _criar(api, padrao="padaria pao quente", categoria_id=_categoria(sessao, "Lazer"))

    # Mais curta e geral: perde para a outra manual, mais longa.
    curta = _criar(api, padrao="padaria", categoria_id=_categoria(sessao, "Alimentação"))

    assert curta["rascunhos"]["quantidade"] == 0


def test_regra_de_categoria_desativada_nao_sugere(api, sessao, conta):
    _rascunho(sessao, conta, "CURSO DE INGLES")
    regra = _criar(api, padrao="curso", categoria_id=_categoria(sessao, "Educação"))
    educacao = sessao.get(Categoria, uuid.UUID(regra["categoria"]["id"]))
    educacao.ativa = False
    sessao.flush()

    assert api.get(f"/regras/{regra['id']}").json()["rascunhos"]["quantidade"] == 0
