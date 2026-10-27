"""Par de transferência na revisão: "Ligar" e "Não é par"."""

import uuid
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.modulos.cartoes import service as cartoes_service
from app.modulos.categorias.models import Categoria
from app.modulos.revisao.models import ParRecusado
from tests.utils import HOJE, criar_conta, criar_transacao

VALOR = Decimal("300.00")


@pytest.fixture
def conta(sessao):
    return criar_conta(sessao)


@pytest.fixture
def dia_a_dia(sessao):
    return criar_conta(sessao, "Conta do dia a dia")


@pytest.fixture
def par(sessao, conta, dia_a_dia):
    mercado = sessao.scalars(select(Categoria).where(Categoria.nome == "Mercado")).one()
    saida = criar_transacao(
        sessao, conta, "PIX ENVIADO CONTA DIA A DIA", valor=VALOR, categoria_id=mercado.id
    )
    entrada = criar_transacao(
        sessao,
        dia_a_dia,
        "PIX RECEBIDO CONTA PRINCIPAL",
        tipo="receita",
        valor=VALOR,
        data=date(2026, 10, 20),
    )
    return saida, entrada


def _ligar(api, saida, entrada, **extra):
    corpo = {"saida_id": str(saida.id), "entrada_id": str(entrada.id)} | extra
    return api.post("/revisao/pares", json=corpo)


def test_ligar_confirma_os_dois_lados(api, sessao, par):
    saida, entrada = par

    resposta = _ligar(api, saida, entrada)

    assert resposta.status_code == 204, resposta.text
    sessao.refresh(saida)
    sessao.refresh(entrada)
    assert (saida.tipo, saida.status, saida.categoria_id) == (
        "transferencia_saida",
        "confirmada",
        None,
    )
    assert (entrada.tipo, entrada.status) == ("transferencia_entrada", "confirmada")
    assert saida.transferencia_par_id == entrada.id
    assert entrada.transferencia_par_id == saida.id
    assert saida.descricao == "PIX ENVIADO CONTA DIA A DIA"
    assert api.get("/revisao").json()["total"] == 0


def test_descricao_vale_para_os_dois(api, sessao, par):
    saida, entrada = par

    _ligar(api, saida, entrada, descricao="Reserva do mês")

    sessao.refresh(saida)
    sessao.refresh(entrada)
    assert saida.descricao == entrada.descricao == "Reserva do mês"
    assert saida.descricao_original == "PIX ENVIADO CONTA DIA A DIA"


@pytest.mark.parametrize(
    "mudanca",
    [{"valor": Decimal("300.01")}, {"data": date(2026, 10, 22)}],
)
def test_par_fora_da_regra(api, sessao, conta, dia_a_dia, mudanca):
    saida = criar_transacao(sessao, conta, valor=VALOR)
    entrada = criar_transacao(sessao, dia_a_dia, tipo="receita", **({"valor": VALOR} | mudanca))

    resposta = _ligar(api, saida, entrada)

    assert resposta.status_code == 422
    assert resposta.json()["campos"][0]["campo"] == "body.entrada_id"


def test_mesma_conta_nao_e_par(api, sessao, conta):
    saida = criar_transacao(sessao, conta, valor=VALOR)
    entrada = criar_transacao(sessao, conta, tipo="receita", valor=VALOR)

    assert _ligar(api, saida, entrada).status_code == 422


def test_entrada_no_lugar_da_saida(api, sessao, par):
    saida, entrada = par

    resposta = _ligar(api, entrada, saida)

    assert resposta.status_code == 422
    assert resposta.json()["campos"][0]["campo"] == "body.saida_id"


def test_cartao_nao_entra_em_par(api, sessao, conta):
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
    saida = criar_transacao(sessao, cartao.conta, valor=VALOR)
    entrada = criar_transacao(sessao, conta, tipo="receita", valor=VALOR)

    assert _ligar(api, saida, entrada).status_code == 422


def test_lado_ja_confirmado_e_conflito(api, sessao, conta, dia_a_dia):
    saida = criar_transacao(sessao, conta, valor=VALOR, status="confirmada")
    entrada = criar_transacao(sessao, dia_a_dia, tipo="receita", valor=VALOR)

    assert _ligar(api, saida, entrada).status_code == 409


def test_ligar_inexistente(api, sessao, par):
    saida, _ = par

    resposta = api.post(
        "/revisao/pares", json={"saida_id": str(saida.id), "entrada_id": str(uuid.uuid4())}
    )

    assert resposta.status_code == 404


def test_recusar_grava_e_o_par_some(api, sessao, par):
    saida, entrada = par
    corpo = {"saida_id": str(saida.id), "entrada_id": str(entrada.id)}

    primeira = api.post("/revisao/pares/recusados", json=corpo)
    segunda = api.post("/revisao/pares/recusados", json=corpo)

    assert (primeira.status_code, segunda.status_code) == (204, 204)
    assert len(sessao.scalars(select(ParRecusado)).all()) == 1
    lista = api.get("/revisao").json()
    assert lista["pares"] == []
    assert lista["total"] == 2


def test_recusar_inexistente(api, sessao, par):
    saida, _ = par

    resposta = api.post(
        "/revisao/pares/recusados",
        json={"saida_id": str(saida.id), "entrada_id": str(uuid.uuid4())},
    )

    assert resposta.status_code == 404
