"""Cartões pela API: cadastro, prévia da próxima fatura e alocação de fatura.

Exemplo de referência (plano 2026-10-24): cartão fecha dia 3 e vence dia 10;
hoje = 2026-10-20, fatura atual = novembro.
"""

import uuid
from datetime import date
from decimal import Decimal

import pytest

from app.modulos.cartoes import service
from app.modulos.cartoes.models import Cartao, Fatura
from app.modulos.contas.models import Conta
from app.modulos.transacoes.models import Transacao


def _criar_conta(api, **mudancas) -> dict:
    dados = {
        "nome": "Conta principal",
        "tipo": "corrente",
        "instituicao": "Banco Exemplo",
        "saldo_inicial": "1000.00",
        "data_saldo_inicial": "2026-10-01",
        **mudancas,
    }
    resposta = api.post("/contas", json=dados)
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


@pytest.fixture
def corrente(api) -> dict:
    return _criar_conta(api)


def _dados_cartao(conta_pagamento_id, **mudancas) -> dict:
    return {
        "nome": "Cartão Exemplo",
        "instituicao": "Banco Exemplo",
        "conta_pagamento_id": conta_pagamento_id,
        "dia_fechamento": 3,
        "dia_vencimento": 10,
        "limite": "3000.00",
        **mudancas,
    }


def _campos(resposta) -> dict:
    assert resposta.status_code == 422, resposta.json()
    return {campo["campo"]: campo["mensagem"] for campo in resposta.json()["campos"]}


# --- cadastro ----------------------------------------------------------------


def test_cria_cartao(api, sessao, corrente):
    resposta = api.post("/cartoes", json=_dados_cartao(corrente["id"]))

    assert resposta.status_code == 201, resposta.json()
    corpo = resposta.json()
    assert corpo["tipo"] == "cartao_credito"
    assert corpo["nome"] == "Cartão Exemplo"
    assert corpo["instituicao"]["nome"] == "Banco Exemplo"
    assert corpo["saldo_inicial"] == "0.00"
    assert corpo["data_saldo_inicial"] == "2026-10-20"
    cartao = sessao.get(Cartao, uuid.UUID(corpo["id"]))
    assert (cartao.dia_fechamento, cartao.dia_vencimento) == (3, 10)
    assert str(cartao.conta_pagamento_id) == corrente["id"]


def test_limite_e_opcional(api, sessao, corrente):
    dados = _dados_cartao(corrente["id"])
    del dados["limite"]

    resposta = api.post("/cartoes", json=dados)

    assert resposta.status_code == 201
    assert sessao.get(Cartao, uuid.UUID(resposta.json()["id"])).limite is None


def test_conta_de_pagamento_precisa_ser_corrente_ativa(api, sessao, corrente):
    carteira = _criar_conta(api, nome="Carteira", tipo="carteira", instituicao=None)
    desativada = _criar_conta(api, nome="Conta antiga")
    sessao.get(Conta, uuid.UUID(desativada["id"])).ativa = False
    cartao = api.post("/cartoes", json=_dados_cartao(corrente["id"])).json()

    for conta_id in [carteira["id"], desativada["id"], cartao["id"], str(uuid.uuid4())]:
        resposta = api.post("/cartoes", json=_dados_cartao(conta_id, nome="Outro cartão"))

        assert _campos(resposta) == {
            "body.conta_pagamento_id": "Escolha uma conta corrente ativa para pagar a fatura."
        }


def test_dias_iguais_sao_recusados(api, corrente):
    resposta = api.post("/cartoes", json=_dados_cartao(corrente["id"], dia_vencimento=3))

    assert _campos(resposta) == {
        "body.dia_vencimento": "O vencimento precisa ser num dia diferente do fechamento."
    }


@pytest.mark.parametrize("dia", [0, 32])
def test_dia_fora_do_mes_e_recusado(api, corrente, dia):
    resposta = api.post("/cartoes", json=_dados_cartao(corrente["id"], dia_fechamento=dia))

    assert "body.dia_fechamento" in _campos(resposta)


def test_post_contas_continua_recusando_cartao(api):
    resposta = api.post(
        "/contas",
        json={
            "nome": "Cartão Exemplo",
            "tipo": "cartao_credito",
            "instituicao": "Banco Exemplo",
            "saldo_inicial": "0.00",
            "data_saldo_inicial": "2026-10-01",
        },
    )

    assert "body.tipo" in _campos(resposta)


def test_cria_cartao_devolve_fatura_atual(api, corrente):
    corpo = api.post("/cartoes", json=_dados_cartao(corrente["id"])).json()

    assert corpo["cartao"] == {
        "conta_pagamento_id": corrente["id"],
        "dia_fechamento": 3,
        "dia_vencimento": 10,
        "limite": "3000.00",
        "fatura_atual": {
            "competencia": "2026-11-01",
            "data_fechamento": "2026-11-03",
            "data_vencimento": "2026-11-10",
            "status": "aberta",
            "valor": "0.00",
            "valor_calculado": "0.00",
            "valor_informado": None,
        },
    }


def test_contas_mostra_fatura_atual_do_cartao(api, sessao, corrente):
    cartao = api.post("/cartoes", json=_dados_cartao(corrente["id"])).json()
    compra = api.post(
        "/transacoes",
        json={
            "conta_id": cartao["id"],
            "tipo": "despesa",
            "valor": "120.00",
            "data": "2026-10-20",
            "descricao": "Mercado do bairro",
        },
    ).json()
    for valor, status_ in [("30.00", "rascunho"), ("50.00", "ignorada")]:
        sessao.add(
            Transacao(
                conta_id=uuid.UUID(cartao["id"]),
                tipo="despesa",
                valor=Decimal(valor),
                data=date(2026, 10, 21),
                descricao_original="Exemplo",
                descricao="Exemplo",
                status=status_,
                fonte="ofx",
                fatura_id=uuid.UUID(compra["fatura_id"]),
            )
        )
    sessao.flush()

    contas = {c["nome"]: c for c in api.get("/contas").json()["contas"]}

    fatura = contas["Cartão Exemplo"]["cartao"]["fatura_atual"]
    assert fatura["valor"] == "150.00"
    assert fatura["status"] == "aberta"
    assert fatura["data_vencimento"] == "2026-11-10"
    assert contas["Conta principal"]["cartao"] is None
    assert api.get(f"/contas/{cartao['id']}").json()["cartao"]["fatura_atual"] == fatura


# --- prévia ------------------------------------------------------------------


def test_previa_da_proxima_fatura(api):
    resposta = api.get("/cartoes/previa", params={"dia_fechamento": 3, "dia_vencimento": 10})

    assert resposta.status_code == 200
    assert resposta.json() == {
        "competencia": "2026-11-01",
        "data_fechamento": "2026-11-03",
        "data_vencimento": "2026-11-10",
    }


def test_previa_com_dias_iguais_e_recusada(api):
    resposta = api.get("/cartoes/previa", params={"dia_fechamento": 3, "dia_vencimento": 3})

    assert "query.dia_vencimento" in _campos(resposta)


# --- alocação de fatura (service) ---------------------------------------------


@pytest.fixture
def cartao(api, sessao, corrente) -> Cartao:
    corpo = api.post("/cartoes", json=_dados_cartao(corrente["id"])).json()
    return service.obter_cartao(sessao, uuid.UUID(corpo["id"]))


@pytest.mark.parametrize(
    ("dia", "competencia"),
    [
        (date(2026, 10, 4), date(2026, 10, 1)),
        (date(2026, 10, 5), date(2026, 11, 1)),
        (date(2026, 10, 20), date(2026, 11, 1)),
    ],
)
def test_competencia_para_data_pela_regra(sessao, cartao, dia, competencia):
    assert service.competencia_para_data(sessao, cartao, dia) == competencia


def test_competencia_para_data_respeita_fatura_editada(sessao, cartao):
    fatura = service.obter_ou_criar_fatura(sessao, cartao, date(2026, 10, 1))
    fatura.data_fechamento = date(2026, 10, 8)
    sessao.flush()

    assert service.competencia_para_data(sessao, cartao, date(2026, 10, 6)) == date(2026, 10, 1)


def test_obter_ou_criar_fatura_grava_uma_vez_com_as_datas_calculadas(sessao, cartao):
    primeira = service.obter_ou_criar_fatura(sessao, cartao, date(2026, 10, 1))
    segunda = service.obter_ou_criar_fatura(sessao, cartao, date(2026, 10, 1))

    assert primeira.id == segunda.id
    assert (primeira.data_fechamento, primeira.data_vencimento) == (
        date(2026, 10, 5),
        date(2026, 10, 13),
    )
    assert sessao.query(Fatura).count() == 1


def test_obter_cartao_de_conta_que_nao_e_cartao(sessao, corrente):
    with pytest.raises(service.CartaoNaoEncontrado):
        service.obter_cartao(sessao, uuid.UUID(corrente["id"]))


def test_rotas_exigem_token(client):
    assert client.post("/cartoes", json={}).status_code == 401
    assert client.get("/cartoes/previa").status_code == 401
