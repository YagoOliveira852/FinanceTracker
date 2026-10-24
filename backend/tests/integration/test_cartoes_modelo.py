"""Tabelas `cartao` e `fatura`: o banco recusa o que as regras não permitem."""

from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy.exc import IntegrityError

from app.modulos.cartoes.models import Cartao, Fatura
from app.modulos.contas.models import Conta, Instituicao


@pytest.fixture
def contas(sessao) -> tuple[Conta, Conta]:
    """(cartão, conta corrente que paga a fatura), sem a linha de `cartao`."""
    banco = Instituicao(nome="Banco Exemplo")
    corrente = Conta(
        nome="Conta principal",
        tipo="corrente",
        instituicao=banco,
        saldo_inicial=Decimal("0.00"),
        data_saldo_inicial=date(2026, 10, 1),
    )
    cartao = Conta(
        nome="Cartão Exemplo",
        tipo="cartao_credito",
        instituicao=banco,
        saldo_inicial=Decimal("0.00"),
        data_saldo_inicial=date(2026, 10, 1),
    )
    sessao.add_all([corrente, cartao])
    sessao.flush()
    return cartao, corrente


def _cartao(contas, **mudancas) -> Cartao:
    cartao, corrente = contas
    dados = {
        "conta_id": cartao.id,
        "conta_pagamento_id": corrente.id,
        "dia_fechamento": 3,
        "dia_vencimento": 10,
        "limite": Decimal("3000.00"),
        **mudancas,
    }
    return Cartao(**dados)


def _fatura(cartao: Cartao, **mudancas) -> Fatura:
    dados = {
        "cartao_id": cartao.conta_id,
        "competencia": date(2026, 11, 1),
        "data_fechamento": date(2026, 11, 3),
        "data_vencimento": date(2026, 11, 10),
        **mudancas,
    }
    return Fatura(**dados)


def _grava(sessao, objeto) -> None:
    sessao.add(objeto)
    sessao.flush()


def test_cartao_e_fatura_validos_sao_gravados(sessao, contas):
    cartao = _cartao(contas)
    _grava(sessao, cartao)
    _grava(sessao, _fatura(cartao, valor_informado=Decimal("0.00")))


@pytest.mark.parametrize(
    "mudanca",
    [
        {"dia_fechamento": 0},
        {"dia_fechamento": 32},
        {"dia_vencimento": 0},
        {"dia_vencimento": 32},
        {"dia_fechamento": 10, "dia_vencimento": 10},
        {"limite": Decimal("0.00")},
    ],
)
def test_cartao_invalido_e_recusado(sessao, contas, mudanca):
    with pytest.raises(IntegrityError):
        _grava(sessao, _cartao(contas, **mudanca))


@pytest.mark.parametrize(
    "mudanca",
    [
        {"competencia": date(2026, 11, 2)},
        {"data_vencimento": date(2026, 11, 3)},
        {"valor_informado": Decimal("-1.00")},
    ],
)
def test_fatura_invalida_e_recusada(sessao, contas, mudanca):
    cartao = _cartao(contas)
    _grava(sessao, cartao)

    with pytest.raises(IntegrityError):
        _grava(sessao, _fatura(cartao, **mudanca))


def test_uma_fatura_por_competencia(sessao, contas):
    cartao = _cartao(contas)
    _grava(sessao, cartao)
    _grava(sessao, _fatura(cartao))

    with pytest.raises(IntegrityError):
        _grava(sessao, _fatura(cartao))
