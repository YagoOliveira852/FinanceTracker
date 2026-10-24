"""Compra parcelada pela API: lançamento e realocação das parcelas.

Exemplo de referência (plano 2026-10-24): cartão fecha dia 3 e vence dia 10;
hoje = 2026-10-20. Outubro fecha em 05/10, novembro em 03/11, dezembro em
03/12 e janeiro/2027 em 04/01 (03/01 é domingo).
"""

import uuid
from datetime import date

import pytest
from sqlalchemy import func, select

from app.modulos.cartoes.feriados import FeriadosAusentes
from app.modulos.cartoes.models import Fatura
from app.modulos.transacoes.models import CompraParcelada, Transacao


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


def _dados(conta, **mudancas) -> dict:
    dados = {
        "conta_id": conta["id"],
        "valor_total": "1000.00",
        "qtd_parcelas": 3,
        "data_compra": "2026-10-20",
        "descricao": "Fone de ouvido",
    }
    return dados | mudancas


def _parcelar(api, conta, **mudancas) -> dict:
    resposta = api.post("/transacoes/parceladas", json=_dados(conta, **mudancas))
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


def _competencias(sessao, compra) -> list[date]:
    """Competência da fatura de cada parcela, da 1ª à última, lidas do banco."""
    competencias = []
    for parcela in compra["parcelas"]:
        transacao = sessao.get(Transacao, uuid.UUID(parcela["id"]))
        sessao.refresh(transacao)
        competencias.append(sessao.get(Fatura, transacao.fatura_id).competencia)
    return competencias


def _campos(resposta) -> dict:
    assert resposta.status_code == 422, resposta.json()
    return {campo["campo"]: campo["mensagem"] for campo in resposta.json()["campos"]}


def _contagem(sessao) -> tuple[int, int, int]:
    return tuple(
        sessao.scalar(select(func.count()).select_from(tabela))
        for tabela in (CompraParcelada, Transacao, Fatura)
    )


# --- lançamento ------------------------------------------------------------------


def test_lanca_parcelada_no_exemplo_do_design(api, sessao, cartao):
    compra = _parcelar(api, cartao)

    assert compra["valor_total"] == "1000.00"
    assert compra["qtd_parcelas"] == 3
    assert compra["data_compra"] == "2026-10-20"
    assert compra["data_compra_estimada"] is False
    parcelas = compra["parcelas"]
    assert [p["valor"] for p in parcelas] == ["333.34", "333.33", "333.33"]
    assert [p["data"] for p in parcelas] == ["2026-10-20", "2026-11-20", "2026-12-20"]
    assert [p["parcela"] for p in parcelas] == [
        {"compra_parcelada_id": compra["id"], "numero": k, "total": 3} for k in (1, 2, 3)
    ]
    assert {(p["tipo"], p["fonte"], p["status"], p["descricao"]) for p in parcelas} == {
        ("despesa", "manual", "confirmada", "Fone de ouvido")
    }
    assert _competencias(sessao, compra) == [
        date(2026, 11, 1),
        date(2026, 12, 1),
        date(2027, 1, 1),
    ]


def test_fatura_da_parcela_e_por_deslocamento(api, sessao, cartao):
    compra = _parcelar(api, cartao, data_compra="2026-10-31", qtd_parcelas=4)

    assert [p["data"] for p in compra["parcelas"]] == [
        "2026-10-31",
        "2026-11-30",
        "2026-12-31",
        "2027-01-31",
    ]
    assert _competencias(sessao, compra) == [
        date(2026, 11, 1),
        date(2026, 12, 1),
        date(2027, 1, 1),
        date(2027, 2, 1),
    ]


def test_compra_no_dia_do_fechamento_comeca_na_seguinte(api, sessao, cartao):
    compra = _parcelar(api, cartao, data_compra="2026-11-03", qtd_parcelas=2)

    assert _competencias(sessao, compra) == [date(2026, 12, 1), date(2027, 1, 1)]


def test_compra_antiga_gera_todas_as_parcelas(api, sessao, cartao):
    compra = _parcelar(api, cartao, data_compra="2026-06-15", qtd_parcelas=10)

    competencias = _competencias(sessao, compra)
    assert len(compra["parcelas"]) == 10
    assert competencias[0] == date(2026, 7, 1)
    assert competencias[-1] == date(2027, 4, 1)


def test_faturas_mostram_as_parcelas(api, cartao):
    _parcelar(api, cartao)

    detalhe = api.get(f"/cartoes/{cartao['id']}/faturas/2026-12").json()

    [parcela] = detalhe["transacoes"]
    assert parcela["parcela"]["numero"] == 2
    assert parcela["valor"] == "333.33"
    assert detalhe["valor_calculado"] == "333.33"


def test_lista_de_transacoes_mostra_a_parcela(api, cartao):
    compra = _parcelar(api, cartao)

    resposta = api.get("/transacoes", params={"de": "2026-11-01", "ate": "2026-11-30"})

    [parcela] = resposta.json()
    assert parcela["id"] == compra["parcelas"][1]["id"]
    assert parcela["parcela"] == {"compra_parcelada_id": compra["id"], "numero": 2, "total": 3}


@pytest.mark.parametrize(
    ("mudanca", "campo", "mensagem"),
    [
        ({"valor_total": "0.02"}, "valor_total", "Cada parcela precisa ser de pelo menos R$ 0,01."),
        ({"conta_id": str(uuid.uuid4())}, "conta_id", "Conta não encontrada."),
    ],
)
def test_parcelada_recusada_pela_regra(api, sessao, cartao, mudanca, campo, mensagem):
    antes = _contagem(sessao)

    campos = _campos(api.post("/transacoes/parceladas", json=_dados(cartao, **mudanca)))

    assert campos == {f"body.{campo}": mensagem}
    assert _contagem(sessao) == antes


def test_conta_que_nao_e_cartao_e_recusada(api, sessao, corrente):
    antes = _contagem(sessao)

    campos = _campos(api.post("/transacoes/parceladas", json=_dados(corrente)))

    assert campos == {"body.conta_id": "Só compra no cartão de crédito pode ser parcelada."}
    assert _contagem(sessao) == antes


def test_cartao_desativado_e_recusado(api, cartao, corrente):
    corpo = {
        "nome": "Cartão Exemplo",
        "instituicao": "Banco Exemplo",
        "conta_pagamento_id": corrente["id"],
        "dia_fechamento": 3,
        "dia_vencimento": 10,
        "limite": None,
        "ativa": False,
    }
    assert api.put(f"/cartoes/{cartao['id']}", json=corpo).status_code == 200

    campos = _campos(api.post("/transacoes/parceladas", json=_dados(cartao)))

    assert campos == {"body.conta_id": "Esta conta está desativada."}


def test_um_centavo_por_parcela_e_aceito(api, cartao):
    compra = _parcelar(api, cartao, valor_total="0.03")

    assert [p["valor"] for p in compra["parcelas"]] == ["0.01", "0.01", "0.01"]


@pytest.mark.parametrize("qtd", [1, 25])
def test_quantidade_fora_de_2_a_24_e_recusada(api, cartao, qtd):
    resposta = api.post("/transacoes/parceladas", json=_dados(cartao, qtd_parcelas=qtd))

    assert "body.qtd_parcelas" in _campos(resposta)


def test_falha_no_meio_nao_grava_nada(api, sessao, cartao):
    """Parcelas em 2041+, sem feriados na tabela: a compra não entra pela metade."""
    antes = _contagem(sessao)

    with pytest.raises(FeriadosAusentes):
        api.post(
            "/transacoes/parceladas", json=_dados(cartao, data_compra="2040-06-15", qtd_parcelas=24)
        )

    assert _contagem(sessao) == antes


def test_parcelada_exige_token(client):
    resposta = client.post("/transacoes/parceladas", json={})

    assert resposta.status_code == 401
