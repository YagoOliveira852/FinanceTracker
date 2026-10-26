"""Categorias pela API: lista do seed, cadastro, edição e desativação."""

import uuid
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.modulos.categorias.models import Categoria, RegraClassificacao
from app.modulos.contas.models import Conta
from app.modulos.transacoes.models import Transacao

GRUPO_COM_TRANSACOES = (
    "Esta categoria já tem transações; troque o grupo só entre essencial e variável."
)


def _id(sessao, nome: str) -> uuid.UUID:
    return sessao.scalars(select(Categoria.id).where(Categoria.nome == nome)).one()


def _por_nome(api) -> dict[str, dict]:
    resposta = api.get("/categorias")
    assert resposta.status_code == 200
    return {c["nome"]: c for c in resposta.json()}


def _transacao_com_categoria(sessao, categoria_id) -> None:
    conta = Conta(
        nome="Carteira",
        tipo="carteira",
        saldo_inicial=Decimal("0.00"),
        data_saldo_inicial=date(2026, 10, 1),
    )
    sessao.add(conta)
    sessao.flush()
    sessao.add(
        Transacao(
            conta_id=conta.id,
            tipo="despesa",
            valor=Decimal("18.50"),
            data=date(2026, 10, 19),
            descricao_original="Padaria Pão Quente",
            descricao="Padaria Pão Quente",
            status="confirmada",
            fonte="manual",
            categoria_id=categoria_id,
        )
    )
    sessao.flush()


def _campos(resposta) -> dict:
    assert resposta.status_code == 422, resposta.json()
    return {erro["campo"]: erro["mensagem"] for erro in resposta.json()["campos"]}


def test_lista_o_seed_por_grupo_e_nome(api):
    resposta = api.get("/categorias")

    assert resposta.status_code == 200
    assert [(c["grupo"], c["nome"]) for c in resposta.json()] == [
        ("essencial", "Mercado"),
        ("essencial", "Moradia"),
        ("essencial", "Saúde"),
        ("essencial", "Transporte"),
        ("variavel", "Alimentação"),
        ("variavel", "Assinaturas"),
        ("variavel", "Compras"),
        ("variavel", "Educação"),
        ("variavel", "Lazer"),
        ("renda", "Outras receitas"),
        ("renda", "Salário"),
        ("investimento", "Investimento"),
    ]


def test_lista_conta_regras_e_transacoes(api, sessao):
    alimentacao = _id(sessao, "Alimentação")
    sessao.add(RegraClassificacao(padrao="padaria", categoria_id=alimentacao, origem="manual"))
    _transacao_com_categoria(sessao, alimentacao)

    categorias = _por_nome(api)

    assert categorias["Alimentação"]["qtd_regras"] == 1
    assert categorias["Alimentação"]["qtd_transacoes"] == 1
    assert categorias["Mercado"]["qtd_regras"] == 0
    assert categorias["Mercado"]["qtd_transacoes"] == 0


def test_cria_categoria(api):
    resposta = api.post("/categorias", json={"nome": "  Pets  ", "grupo": "variavel"})

    assert resposta.status_code == 201
    corpo = resposta.json()
    assert corpo | {"id": None} == {
        "id": None,
        "nome": "Pets",
        "grupo": "variavel",
        "ativa": True,
        "qtd_regras": 0,
        "qtd_transacoes": 0,
    }
    assert "Pets" in _por_nome(api)


def test_nome_repetido_com_outra_caixa_e_recusado(api):
    resposta = api.post("/categorias", json={"nome": "mercado", "grupo": "essencial"})

    assert _campos(resposta) == {"body.nome": "Já existe uma categoria com esse nome."}


def test_nome_e_grupo_sao_validados(api):
    resposta = api.post("/categorias", json={"nome": "", "grupo": "outro"})

    assert set(_campos(resposta)) == {"body.nome", "body.grupo"}


def test_edita_nome_e_grupo(api, sessao):
    lazer = _id(sessao, "Lazer")

    resposta = api.put(
        f"/categorias/{lazer}",
        json={"nome": "Lazer e cultura", "grupo": "essencial", "ativa": True},
    )

    assert resposta.status_code == 200
    assert resposta.json()["nome"] == "Lazer e cultura"
    assert resposta.json()["grupo"] == "essencial"


def test_renomear_para_o_proprio_nome_com_outra_caixa_e_aceito(api, sessao):
    lazer = _id(sessao, "Lazer")

    resposta = api.put(
        f"/categorias/{lazer}", json={"nome": "LAZER", "grupo": "variavel", "ativa": True}
    )

    assert resposta.status_code == 200
    assert resposta.json()["nome"] == "LAZER"


def test_renomear_para_nome_de_outra_e_recusado(api, sessao):
    lazer = _id(sessao, "Lazer")

    resposta = api.put(
        f"/categorias/{lazer}", json={"nome": "Compras", "grupo": "variavel", "ativa": True}
    )

    assert _campos(resposta) == {"body.nome": "Já existe uma categoria com esse nome."}


def test_desativa_e_reativa(api, sessao):
    educacao = _id(sessao, "Educação")
    dados = {"nome": "Educação", "grupo": "variavel"}

    desativada = api.put(f"/categorias/{educacao}", json=dados | {"ativa": False})
    reativada = api.put(f"/categorias/{educacao}", json=dados | {"ativa": True})

    assert desativada.json()["ativa"] is False
    assert reativada.json()["ativa"] is True


def test_grupo_troca_entre_essencial_e_variavel_mesmo_com_transacao(api, sessao):
    alimentacao = _id(sessao, "Alimentação")
    _transacao_com_categoria(sessao, alimentacao)

    resposta = api.put(
        f"/categorias/{alimentacao}",
        json={"nome": "Alimentação", "grupo": "essencial", "ativa": True},
    )

    assert resposta.status_code == 200


@pytest.mark.parametrize("grupo", ["renda", "investimento"])
def test_grupo_nao_muda_de_natureza_com_transacao(api, sessao, grupo):
    alimentacao = _id(sessao, "Alimentação")
    _transacao_com_categoria(sessao, alimentacao)

    resposta = api.put(
        f"/categorias/{alimentacao}", json={"nome": "Alimentação", "grupo": grupo, "ativa": True}
    )

    assert _campos(resposta) == {"body.grupo": GRUPO_COM_TRANSACOES}


def test_grupo_muda_de_natureza_sem_transacao(api, sessao):
    compras = _id(sessao, "Compras")

    resposta = api.put(
        f"/categorias/{compras}", json={"nome": "Compras", "grupo": "renda", "ativa": True}
    )

    assert resposta.status_code == 200
    assert resposta.json()["grupo"] == "renda"


def test_editar_inexistente_e_404(api):
    resposta = api.put(
        f"/categorias/{uuid.uuid4()}", json={"nome": "Pets", "grupo": "variavel", "ativa": True}
    )

    assert resposta.status_code == 404
    assert resposta.json() == {"detail": "Categoria não encontrada."}


def test_id_malformado_e_422(api):
    resposta = api.put("/categorias/abc", json={"nome": "Pets", "grupo": "variavel", "ativa": True})

    assert resposta.status_code == 422


def test_sem_token_e_401(client):
    assert client.get("/categorias").status_code == 401
