"""Transferência entre contas próprias pela API: dois lados ligados, que mudam
os saldos sem contar como gasto nem renda."""

import uuid

import pytest
from sqlalchemy import event, func, select

from app.modulos.contas.models import Conta
from app.modulos.transacoes import service
from app.modulos.transacoes.models import Transacao
from app.modulos.transacoes.schemas import TransacaoSaida


def _criar_conta(api, **dados) -> dict:
    resposta = api.post(
        "/contas",
        json={"saldo_inicial": "1000.00", "data_saldo_inicial": "2026-10-01", **dados},
    )
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


@pytest.fixture
def corrente(api) -> dict:
    return _criar_conta(api, nome="Conta principal", tipo="corrente", instituicao="Banco Exemplo")


@pytest.fixture
def carteira(api) -> dict:
    return _criar_conta(api, nome="Carteira", tipo="carteira")


@pytest.fixture
def cartao(api, corrente) -> dict:
    resposta = api.post(
        "/cartoes",
        json={
            "nome": "Cartão Exemplo",
            "instituicao": "Banco Exemplo",
            "conta_pagamento_id": corrente["id"],
            "dia_fechamento": 3,
            "dia_vencimento": 10,
        },
    )
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


def _dados(origem, destino, **mudancas) -> dict:
    return {
        "conta_origem_id": origem["id"],
        "conta_destino_id": destino["id"],
        "valor": "200.00",
        "data": "2026-10-19",
        "descricao": "Saque para a carteira",
        **mudancas,
    }


def _transferir(api, origem, destino, **mudancas) -> dict:
    resposta = api.post("/transacoes/transferencias", json=_dados(origem, destino, **mudancas))
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


def _saldo(api, conta) -> str:
    return api.get(f"/contas/{conta['id']}").json()["saldo_atual"]


def _campos(resposta) -> dict:
    assert resposta.status_code == 422
    return {erro["campo"]: erro["mensagem"] for erro in resposta.json()["campos"]}


def test_transfere_entre_contas(api, corrente, carteira):
    corpo = _transferir(api, corrente, carteira)
    saida, entrada = corpo["saida"], corpo["entrada"]

    assert (saida["tipo"], saida["conta_id"]) == ("transferencia_saida", corrente["id"])
    assert (entrada["tipo"], entrada["conta_id"]) == ("transferencia_entrada", carteira["id"])
    for lado in (saida, entrada):
        assert lado["valor"] == "200.00"
        assert lado["data"] == "2026-10-19"
        assert lado["descricao"] == "Saque para a carteira"
        assert (lado["fonte"], lado["status"]) == ("manual", "confirmada")
    contas = {"conta_origem_id": corrente["id"], "conta_destino_id": carteira["id"]}
    assert saida["transferencia"] == {"par_id": entrada["id"], **contas}
    assert entrada["transferencia"] == {"par_id": saida["id"], **contas}
    assert _saldo(api, corrente) == "800.00"
    assert _saldo(api, carteira) == "1200.00"


@pytest.mark.parametrize("descricao", [None, "   ", "ausente"])
def test_descricao_padrao(api, corrente, carteira, descricao):
    dados = _dados(corrente, carteira, descricao=descricao)
    if descricao == "ausente":
        del dados["descricao"]
    resposta = api.post("/transacoes/transferencias", json=dados)

    assert resposta.status_code == 201, resposta.json()
    assert resposta.json()["saida"]["descricao"] == "Transferência"
    assert resposta.json()["entrada"]["descricao"] == "Transferência"


def test_deposito_da_carteira_na_corrente(api, corrente, carteira):
    _transferir(api, carteira, corrente, descricao="Depósito")

    assert _saldo(api, carteira) == "800.00"
    assert _saldo(api, corrente) == "1200.00"


def _desativar(sessao, conta) -> None:
    sessao.get(Conta, uuid.UUID(conta["id"])).ativa = False
    sessao.flush()


@pytest.mark.parametrize(
    ("caso", "campo", "mensagem"),
    [
        ("mesma conta", "conta_destino_id", "Escolha uma conta diferente da de origem."),
        ("cartão na origem", "conta_origem_id", "Para pagar o cartão, use Pagamento de fatura."),
        ("cartão no destino", "conta_destino_id", "Para pagar o cartão, use Pagamento de fatura."),
        ("origem desativada", "conta_origem_id", "Esta conta está desativada."),
        ("destino inexistente", "conta_destino_id", "Conta não encontrada."),
    ],
)
def test_transferencia_recusada(api, sessao, corrente, carteira, cartao, caso, campo, mensagem):
    origem, destino = corrente, carteira
    if caso == "mesma conta":
        destino = corrente
    elif caso == "cartão na origem":
        origem = cartao
    elif caso == "cartão no destino":
        destino = cartao
    elif caso == "origem desativada":
        _desativar(sessao, corrente)
    elif caso == "destino inexistente":
        destino = {"id": str(uuid.uuid4())}
    antes = sessao.scalar(select(func.count()).select_from(Transacao))

    campos = _campos(api.post("/transacoes/transferencias", json=_dados(origem, destino)))

    assert campos == {f"body.{campo}": mensagem}
    assert sessao.scalar(select(func.count()).select_from(Transacao)) == antes


def test_valor_zero_e_recusado(api, corrente, carteira):
    campos = _campos(
        api.post("/transacoes/transferencias", json=_dados(corrente, carteira, valor="0.00"))
    )

    assert list(campos) == ["body.valor"]


def test_listagem_traz_o_par(api, corrente, carteira):
    corpo = _transferir(api, corrente, carteira)

    todas = api.get("/transacoes").json()
    da_carteira = api.get("/transacoes", params={"conta_id": carteira["id"]}).json()

    assert {t["id"] for t in todas} == {corpo["saida"]["id"], corpo["entrada"]["id"]}
    assert all(t["transferencia"] is not None for t in todas)
    assert [t["id"] for t in da_carteira] == [corpo["entrada"]["id"]]
    assert da_carteira[0]["transferencia"]["conta_origem_id"] == corrente["id"]


def test_listagem_filtrada_carrega_o_par_sem_consulta_por_linha(api, sessao, corrente, carteira):
    for _ in range(3):
        _transferir(api, corrente, carteira)
    sessao.expunge_all()
    consultas = []

    def contar(*_):
        consultas.append(1)

    motor = sessao.get_bind()
    event.listen(motor, "before_cursor_execute", contar)
    try:
        transacoes = service.listar(sessao, conta_id=uuid.UUID(carteira["id"]))
        saidas = [TransacaoSaida.model_validate(t) for t in transacoes]
    finally:
        event.remove(motor, "before_cursor_execute", contar)

    assert len(saidas) == 3
    assert all(s.transferencia.conta_origem_id == uuid.UUID(corrente["id"]) for s in saidas)
    assert len(consultas) == 1


def test_transferencia_exige_token(client):
    resposta = client.post("/transacoes/transferencias", json={})

    assert resposta.status_code == 401
