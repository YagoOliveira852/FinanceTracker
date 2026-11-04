"""Conexões da Pluggy pela API: prévia, cadastro com vínculos, renovação,
desativar/reativar, estado e "Buscar agora". A Pluggy é falsa. Hoje = 20/10;
agora = 20/10 10:00 UTC (07:00 em Fortaleza). Dados fictícios."""

from datetime import UTC, date, datetime, timedelta

import pytest
from sqlalchemy import select

from app.core.deps import get_agora
from app.main import app
from app.modulos.cartoes.models import Cartao
from app.modulos.contas.models import Conta
from app.modulos.pluggy.client import ErroPluggy
from app.modulos.pluggy.models import ConexaoPluggy
from app.modulos.pluggy.router import get_fonte_pluggy
from tests.pluggy_falsa import (
    AGORA,
    CONSENTIMENTO,
    PluggyFalsa,
    cartao_pluggy,
    conta_pluggy,
    item,
    tx,
)
from tests.utils import criar_conta

ITEM = "8f3c2a91-5d4e-4b7a-9c1f-2e6d0a7b4c35"
ITEM_NOVO = "c71e04b8-2f9a-4d63-8b5e-91a3f7d2c608"


@pytest.fixture
def pluggy(api):
    falsa = PluggyFalsa()
    falsa.itens = {ITEM: item(ITEM), ITEM_NOVO: item(ITEM_NOVO)}
    falsa.contas[ITEM] = [conta_pluggy("conta-1"), cartao_pluggy("cartao-1")]
    app.dependency_overrides[get_fonte_pluggy] = lambda: falsa
    app.dependency_overrides[get_agora] = lambda: AGORA
    return falsa


def _campos(resposta) -> dict:
    assert resposta.status_code == 422, resposta.json()
    return {e["campo"]: e["mensagem"] for e in resposta.json()["campos"]}


def _criar(api, vinculos, item_id=ITEM):
    return api.post("/pluggy/conexoes", json={"item_id": item_id, "vinculos": vinculos})


def test_previa_lista_as_contas_e_sugere_pelo_final(api, sessao, pluggy):
    principal = criar_conta(sessao, "Conta principal 3456")

    resposta = api.post("/pluggy/conexoes/previa", json={"item_id": ITEM})

    assert resposta.status_code == 200, resposta.json()
    previa = resposta.json()
    assert previa["instituicao"] == "Banco Exemplo"
    conta, cartao = previa["contas"]
    assert (conta["pluggy_account_id"], conta["tipo"], conta["numero_final"]) == (
        "conta-1",
        "corrente",
        "3456",
    )
    assert conta["sugestao"]["id"] == str(principal.id)
    assert (cartao["tipo"], cartao["sugestao"], cartao["pode_criar"]) == (
        "cartao_credito",
        None,
        True,
    )


@pytest.mark.parametrize(
    ("item_id", "mensagem"),
    [
        ("nao-e-uuid", "O ID tem o formato"),
        ("00000000-0000-4000-8000-000000000000", "Não encontramos uma conexão com esse ID"),
    ],
)
def test_previa_recusa_item_invalido(api, pluggy, item_id, mensagem):
    resposta = api.post("/pluggy/conexoes/previa", json={"item_id": item_id})

    assert _campos(resposta)["body.item_id"].startswith(mensagem)


def test_cria_conexao_com_conta_e_cartao_novos(api, sessao, pluggy):
    resposta = _criar(
        api,
        [
            {"pluggy_account_id": "conta-1", "conta_id": None},
            {"pluggy_account_id": "cartao-1", "conta_id": None},
        ],
    )

    assert resposta.status_code == 201, resposta.json()
    conexao = resposta.json()
    assert (conexao["instituicao"], conexao["ativa"], conexao["problema"]) == (
        "Banco Exemplo",
        True,
        None,
    )
    assert sorted(c["nome"] for c in conexao["contas"]) == ["Cartão Exemplo", "Conta corrente"]
    corrente = sessao.scalar(select(Conta).where(Conta.pluggy_account_id == "conta-1"))
    cartao = sessao.scalar(
        select(Cartao)
        .join(Conta, Cartao.conta_id == Conta.id)
        .where(Conta.pluggy_account_id == "cartao-1")
    )
    assert (corrente.tipo, corrente.pluggy_numero_final, corrente.data_saldo_inicial) == (
        "corrente",
        "3456",
        date(2026, 10, 20),
    )
    assert (cartao.dia_fechamento, cartao.dia_vencimento, cartao.conta_pagamento_id) == (
        3,
        10,
        corrente.id,
    )


def test_vincula_a_conta_existente(api, sessao, pluggy):
    principal = criar_conta(sessao, "Conta principal")

    resposta = _criar(api, [{"pluggy_account_id": "conta-1", "conta_id": str(principal.id)}])

    assert resposta.status_code == 201, resposta.json()
    sessao.refresh(principal)
    assert (principal.pluggy_account_id, principal.pluggy_numero_final) == ("conta-1", "3456")
    assert principal.conexao_pluggy_id is not None


def test_cartao_novo_sem_corrente_no_vinculo(api, pluggy):
    resposta = _criar(api, [{"pluggy_account_id": "cartao-1", "conta_id": None}])

    assert "vincule também a conta corrente" in _campos(resposta)["body.vinculos"]


def test_cartao_sem_dias_na_pluggy_so_vincula(api, sessao, pluggy):
    pluggy.contas[ITEM] = [conta_pluggy("conta-1"), cartao_pluggy("cartao-1", dia_fechamento=None)]

    previa = api.post("/pluggy/conexoes/previa", json={"item_id": ITEM}).json()
    resposta = _criar(
        api,
        [
            {"pluggy_account_id": "conta-1", "conta_id": None},
            {"pluggy_account_id": "cartao-1", "conta_id": None},
        ],
    )

    assert previa["contas"][1]["pode_criar"] is False
    assert "vincule a um cartão já cadastrado" in _campos(resposta)["body.vinculos"]
    # Nada pela metade: a corrente do mesmo pedido não foi criada.
    assert sessao.scalar(select(Conta).where(Conta.pluggy_account_id == "conta-1")) is None


def test_tipo_diferente_nao_vincula(api, sessao, pluggy):
    principal = criar_conta(sessao, "Conta principal")

    resposta = _criar(api, [{"pluggy_account_id": "cartao-1", "conta_id": str(principal.id)}])

    assert "mesmo tipo" in _campos(resposta)["body.vinculos"]


def test_item_ja_cadastrado(api, pluggy):
    _criar(api, [{"pluggy_account_id": "conta-1", "conta_id": None}])

    resposta = api.post("/pluggy/conexoes/previa", json={"item_id": ITEM})

    assert _campos(resposta)["body.item_id"] == "Esta conexão já está cadastrada."


def _conexao(api) -> dict:
    return _criar(api, [{"pluggy_account_id": "conta-1", "conta_id": None}]).json()


def test_desativar_mantem_as_contas_e_reativar_confere_o_item(api, sessao, pluggy):
    conexao = _conexao(api)

    desativada = api.put(f"/pluggy/conexoes/{conexao['id']}", json={"ativa": False}).json()
    pluggy.itens.pop(ITEM)
    recusada = api.put(f"/pluggy/conexoes/{conexao['id']}", json={"ativa": True})
    pluggy.itens[ITEM] = item(ITEM)
    reativada = api.put(f"/pluggy/conexoes/{conexao['id']}", json={"ativa": True}).json()

    assert (desativada["ativa"], desativada["proximo_sync"], len(desativada["contas"])) == (
        False,
        None,
        1,
    )
    assert sessao.scalar(select(Conta).where(Conta.pluggy_account_id == "conta-1")).ativa
    assert "Não encontramos" in _campos(recusada)["body.item_id"]
    assert reativada["ativa"] is True


def test_buscar_agora_roda_o_sync_e_espera_uma_hora(api, sessao, pluggy):
    conexao = _conexao(api)
    pluggy.transacoes["conta-1"] = [tx("tx-1")]

    primeira = api.post(f"/pluggy/conexoes/{conexao['id']}/sync")
    segunda = api.post(f"/pluggy/conexoes/{conexao['id']}/sync")
    estado = api.get("/pluggy/conexoes").json()["conexoes"][0]

    assert primeira.status_code == 200, primeira.json()
    assert (primeira.json()["ok"], primeira.json()["novas"]) == (True, 1)
    assert segunda.status_code == 429
    # 11:00 UTC = 08:00 em Fortaleza.
    assert segunda.json()["detail"].endswith("a partir das 08:00.")
    assert estado["buscar_a_partir_de"] == "2026-10-20T11:00:00Z"
    assert estado["ultimo_sync_em"] == "2026-10-20T10:00:00Z"


def test_buscar_agora_com_erro_da_pluggy(api, pluggy):
    conexao = _conexao(api)
    pluggy.erros[ITEM] = ErroPluggy("A Pluggy respondeu com erro (500).")

    resposta = api.post(f"/pluggy/conexoes/{conexao['id']}/sync").json()

    assert (resposta["ok"], resposta["erro"]) == (False, "A Pluggy respondeu com erro (500).")


def test_lista_traz_o_problema_mais_grave(api, sessao, pluggy):
    conexao = _conexao(api)
    registro = sessao.get(ConexaoPluggy, conexao["id"])
    registro.ultimo_sync_em = AGORA - timedelta(hours=2)
    registro.consentimento_expira_em = AGORA + timedelta(days=12)
    sessao.commit()

    lista = api.get("/pluggy/conexoes").json()

    assert lista["conexoes"][0]["problema"] == "vencendo"
    assert lista["problema"] == {
        "problema": "vencendo",
        "conexao_id": conexao["id"],
        "instituicao": "Banco Exemplo",
    }


def test_renovacao_troca_o_item_e_religa_as_contas(api, sessao, pluggy):
    conexao = _conexao(api)
    pluggy.contas[ITEM_NOVO] = [conta_pluggy("conta-1-nova")]
    corrente = sessao.scalar(select(Conta).where(Conta.pluggy_account_id == "conta-1"))

    previa = api.post(
        f"/pluggy/conexoes/{conexao['id']}/renovacao/previa", json={"item_id": ITEM_NOVO}
    ).json()
    renovada = api.post(
        f"/pluggy/conexoes/{conexao['id']}/renovacao",
        json={
            "item_id": ITEM_NOVO,
            "vinculos": [{"pluggy_account_id": "conta-1-nova", "conta_id": str(corrente.id)}],
        },
    )

    assert previa["contas"][0]["sugestao"]["id"] == str(corrente.id)
    assert renovada.status_code == 200, renovada.json()
    assert renovada.json()["item_id"] == ITEM_NOVO
    sessao.refresh(corrente)
    assert corrente.pluggy_account_id == "conta-1-nova"
    registro = sessao.get(ConexaoPluggy, conexao["id"])
    assert registro.renovada_em == AGORA


def test_conexao_inexistente(api, pluggy):
    resposta = api.put(
        "/pluggy/conexoes/00000000-0000-4000-8000-000000000000", json={"ativa": False}
    )

    assert resposta.status_code == 404


def test_sem_credenciais_o_open_finance_nao_esta_configurado(api):
    resposta = api.post("/pluggy/conexoes/previa", json={"item_id": ITEM})

    assert resposta.status_code == 503
    assert resposta.json()["detail"] == "O Open Finance não está configurado no servidor."


def test_exige_login(client):
    assert client.get("/pluggy/conexoes").status_code == 401


def test_consentimento_e_datas_em_utc(api, pluggy):
    conexao = _conexao(api)

    assert conexao["consentimento_expira_em"] == CONSENTIMENTO.isoformat().replace("+00:00", "Z")
    assert conexao["proximo_sync"] == datetime(2026, 10, 21, 10, tzinfo=UTC).isoformat().replace(
        "+00:00", "Z"
    )
