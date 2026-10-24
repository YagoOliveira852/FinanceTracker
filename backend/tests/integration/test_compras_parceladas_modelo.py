"""Tabela `compra_parcelada` e parcela na `transacao`: o banco recusa o que as
regras não permitem."""

from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy.exc import IntegrityError

from app.modulos.contas.models import Conta, Instituicao
from app.modulos.transacoes.models import CompraParcelada, Transacao


@pytest.fixture
def conta(sessao) -> Conta:
    conta = Conta(
        nome="Conta principal",
        tipo="corrente",
        instituicao=Instituicao(nome="Banco Exemplo"),
        saldo_inicial=Decimal("0.00"),
        data_saldo_inicial=date(2026, 10, 1),
    )
    sessao.add(conta)
    sessao.flush()
    return conta


def _compra(**mudancas) -> CompraParcelada:
    dados = {
        "descricao": "Fone de ouvido",
        "valor_total": Decimal("1000.00"),
        "qtd_parcelas": 3,
        "data_compra": date(2026, 10, 20),
    }
    return CompraParcelada(**(dados | mudancas))


def _transacao(conta, **mudancas) -> Transacao:
    dados = {
        "conta_id": conta.id,
        "tipo": "despesa",
        "valor": Decimal("333.34"),
        "data": date(2026, 10, 20),
        "descricao_original": "Fone de ouvido",
        "descricao": "Fone de ouvido",
        "status": "confirmada",
        "fonte": "manual",
    }
    return Transacao(**(dados | mudancas))


def test_parcela_liga_a_transacao_a_compra(sessao, conta):
    compra = _compra()
    sessao.add(_transacao(conta, compra_parcelada=compra, parcela_numero=1))
    sessao.flush()

    sessao.refresh(compra)
    assert [t.parcela_numero for t in compra.parcelas] == [1]
    assert compra.data_compra_estimada is False


def test_parcela_sem_numero_e_recusada(sessao, conta):
    sessao.add(_transacao(conta, compra_parcelada=_compra(), parcela_numero=None))
    with pytest.raises(IntegrityError, match="parcela_completa"):
        sessao.flush()


def test_numero_sem_compra_e_recusado(sessao, conta):
    sessao.add(_transacao(conta, parcela_numero=1))
    with pytest.raises(IntegrityError, match="parcela_completa"):
        sessao.flush()


def test_parcela_numero_zero_e_recusado(sessao, conta):
    sessao.add(_transacao(conta, compra_parcelada=_compra(), parcela_numero=0))
    with pytest.raises(IntegrityError, match="parcela_numero_valido"):
        sessao.flush()


def test_qtd_parcelas_menor_que_2_e_recusada(sessao):
    sessao.add(_compra(qtd_parcelas=1))
    with pytest.raises(IntegrityError, match="qtd_parcelas_valida"):
        sessao.flush()


def test_valor_total_precisa_ser_positivo(sessao):
    sessao.add(_compra(valor_total=Decimal("0.00")))
    with pytest.raises(IntegrityError, match="valor_total_positivo"):
        sessao.flush()
