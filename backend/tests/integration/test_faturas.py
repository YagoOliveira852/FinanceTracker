"""Faturas pela API: lista, detalhe, "para compra", edição e ajuste.

Exemplo de referência (plano 2026-10-24): cartão fecha dia 3 e vence dia 10;
hoje = 2026-10-20. Outubro fechou em 05/10 (03/10 é sábado) e vence em 13/10
(10/10 é sábado e 12/10 é feriado); novembro é a fatura aberta.
"""

import uuid
from datetime import date
from decimal import Decimal

import pytest

from app.modulos.cartoes import service
from app.modulos.cartoes.models import Fatura
from app.modulos.transacoes.models import Transacao


@pytest.fixture
def corrente(api) -> dict:
    resposta = api.post(
        "/contas",
        json={
            "nome": "Conta principal",
            "tipo": "corrente",
            "instituicao": "Banco Exemplo",
            "saldo_inicial": "1000.00",
            "data_saldo_inicial": "2026-10-01",
        },
    )
    assert resposta.status_code == 201
    return resposta.json()


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
    assert resposta.status_code == 201
    return resposta.json()


def _comprar(api, cartao, data, valor="100.00", descricao="Mercado do bairro") -> dict:
    resposta = api.post(
        "/transacoes",
        json={
            "conta_id": cartao["id"],
            "tipo": "despesa",
            "valor": valor,
            "data": data,
            "descricao": descricao,
        },
    )
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


def _url(cartao, sufixo="") -> str:
    return f"/cartoes/{cartao['id']}/faturas{sufixo}"


def _competencia_da_transacao(sessao, transacao_id) -> date:
    transacao = sessao.get(Transacao, uuid.UUID(transacao_id))
    sessao.refresh(transacao)
    return sessao.get(Fatura, transacao.fatura_id).competencia


def _campos(resposta) -> dict:
    assert resposta.status_code == 422, resposta.json()
    return {campo["campo"]: campo["mensagem"] for campo in resposta.json()["campos"]}


# --- lista ---------------------------------------------------------------------


def test_lista_separa_proximas_atual_e_anteriores(api, sessao, cartao):
    _comprar(api, cartao, "2026-10-04", "80.00")
    _comprar(api, cartao, "2026-10-20", "120.00")
    obj = service.obter_cartao(sessao, uuid.UUID(cartao["id"]))
    service.obter_ou_criar_fatura(sessao, obj, date(2026, 12, 1))

    corpo = api.get(_url(cartao)).json()

    assert corpo["atual"]["competencia"] == "2026-11-01"
    assert corpo["atual"]["status"] == "aberta"
    assert corpo["atual"]["valor"] == "120.00"
    assert [f["competencia"] for f in corpo["proximas"]] == ["2026-12-01"]
    assert [f["competencia"] for f in corpo["anteriores"]] == ["2026-10-01"]
    outubro = corpo["anteriores"][0]
    assert (outubro["status"], outubro["valor"]) == ("fechada", "80.00")
    assert (outubro["data_fechamento"], outubro["data_vencimento"]) == ("2026-10-05", "2026-10-13")


def test_lista_sem_compras_nao_grava_nada(api, sessao, cartao):
    corpo = api.get(_url(cartao)).json()

    assert corpo["atual"]["competencia"] == "2026-11-01"
    assert corpo["proximas"] == []
    assert corpo["anteriores"] == []
    assert sessao.query(Fatura).count() == 0


# --- detalhe -------------------------------------------------------------------


def test_detalhe_explica_o_ajuste_para_dia_util(api, cartao):
    _comprar(api, cartao, "2026-10-02", "150.00", "Posto Fictício")

    corpo = api.get(_url(cartao, "/2026-10")).json()

    assert corpo["competencia"] == "2026-10-01"
    assert corpo["status"] == "fechada"
    assert corpo["fechamento_calculado"] == "2026-10-05"
    assert corpo["vencimento_calculado"] == "2026-10-13"
    assert corpo["ajuste_fechamento"] == {"data_prevista": "2026-10-03", "feriados": []}
    assert corpo["ajuste_vencimento"] == {
        "data_prevista": "2026-10-10",
        "feriados": [{"data": "2026-10-12", "descricao": "Nossa Senhora Aparecida"}],
    }
    assert [t["descricao"] for t in corpo["transacoes"]] == ["Posto Fictício"]


def test_detalhe_sem_ajuste_e_sem_fatura_gravada(api, sessao, cartao):
    corpo = api.get(_url(cartao, "/2026-11")).json()

    assert corpo["ajuste_fechamento"] is None
    assert corpo["ajuste_vencimento"] is None
    assert corpo["transacoes"] == []
    assert corpo["valor"] == "0.00"
    assert sessao.query(Fatura).count() == 0


def test_detalhe_nao_mostra_ignoradas(api, sessao, cartao):
    compra = _comprar(api, cartao, "2026-10-20")
    ignorada = Transacao(
        conta_id=uuid.UUID(cartao["id"]),
        tipo="despesa",
        valor=Decimal("9.90"),
        data=date(2026, 10, 21),
        descricao_original="Ignorada",
        descricao="Ignorada",
        status="ignorada",
        fonte="ofx",
        fatura_id=uuid.UUID(compra["fatura_id"]),
    )
    sessao.add(ignorada)
    sessao.flush()

    corpo = api.get(_url(cartao, "/2026-11")).json()

    assert [t["id"] for t in corpo["transacoes"]] == [compra["id"]]


@pytest.mark.parametrize("competencia", ["2026-13", "11-2026", "abc", "2026-1"])
def test_competencia_malformada_e_422(api, cartao, competencia):
    resposta = api.get(_url(cartao, f"/{competencia}"))

    assert resposta.status_code == 422
    assert resposta.json()["campos"][0]["mensagem"] == "Formato inválido."


# --- para compra -------------------------------------------------------------


@pytest.mark.parametrize(
    ("data", "competencia", "fechamento", "vencimento"),
    [
        ("2026-10-04", "2026-10-01", "2026-10-05", "2026-10-13"),
        ("2026-10-05", "2026-11-01", "2026-11-03", "2026-11-10"),
    ],
)
def test_para_compra(api, cartao, data, competencia, fechamento, vencimento):
    resposta = api.get(_url(cartao, "/para-compra"), params={"data": data})

    assert resposta.status_code == 200
    assert resposta.json() == {
        "competencia": competencia,
        "data_fechamento": fechamento,
        "data_vencimento": vencimento,
    }


# --- 404 -----------------------------------------------------------------------


def test_rotas_de_fatura_de_conta_que_nao_e_cartao(api, corrente):
    for conta_id in [corrente["id"], str(uuid.uuid4())]:
        for caminho in ["", "/2026-11", "/para-compra?data=2026-10-20"]:
            resposta = api.get(f"/cartoes/{conta_id}/faturas{caminho}")

            assert resposta.status_code == 404
            assert resposta.json() == {"detail": "Cartão não encontrado."}


def test_rotas_exigem_token(client):
    assert client.get(f"/cartoes/{uuid.uuid4()}/faturas").status_code == 401
