"""Par de transferência na `transacao`: o banco recusa o que as regras não
permitem."""

from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy.exc import IntegrityError

from app.modulos.contas.models import Conta, Instituicao
from app.modulos.transacoes.models import Transacao


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


@pytest.fixture
def carteira(sessao) -> Conta:
    carteira = Conta(
        nome="Carteira",
        tipo="carteira",
        saldo_inicial=Decimal("0.00"),
        data_saldo_inicial=date(2026, 10, 1),
    )
    sessao.add(carteira)
    sessao.flush()
    return carteira


def _transacao(conta, **mudancas) -> Transacao:
    dados = {
        "conta_id": conta.id,
        "tipo": "transferencia_saida",
        "valor": Decimal("200.00"),
        "data": date(2026, 10, 19),
        "descricao_original": "Transferência",
        "descricao": "Transferência",
        "status": "confirmada",
        "fonte": "manual",
    }
    return Transacao(**(dados | mudancas))


def test_par_ligado_nos_dois_sentidos(sessao, conta, carteira):
    saida = _transacao(conta)
    entrada = _transacao(carteira, tipo="transferencia_entrada")
    saida.transferencia_par = entrada
    entrada.transferencia_par = saida
    sessao.add_all([saida, entrada])
    sessao.flush()
    sessao.expire_all()

    assert sessao.get(Transacao, saida.id).transferencia_par.id == entrada.id
    assert sessao.get(Transacao, entrada.id).transferencia_par_id == saida.id


def test_par_em_despesa_e_recusado(sessao, conta, carteira):
    entrada = _transacao(carteira, tipo="transferencia_entrada")
    sessao.add_all([entrada, _transacao(conta, tipo="despesa", transferencia_par=entrada)])
    with pytest.raises(IntegrityError, match="par_so_em_transferencia"):
        sessao.flush()


def test_par_igual_a_si_mesma_e_recusado(sessao, conta):
    saida = _transacao(conta)
    sessao.add(saida)
    sessao.flush()
    saida.transferencia_par_id = saida.id
    with pytest.raises(IntegrityError, match="par_nao_e_ela_mesma"):
        sessao.flush()


def test_dois_lados_nao_apontam_para_o_mesmo_par(sessao, conta, carteira):
    entrada = _transacao(carteira, tipo="transferencia_entrada")
    sessao.add_all(
        [
            entrada,
            _transacao(conta, transferencia_par=entrada),
            _transacao(conta, transferencia_par=entrada),
        ]
    )
    with pytest.raises(IntegrityError, match="uq_transacao_transferencia_par_id"):
        sessao.flush()
