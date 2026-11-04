"""Normalização das transações da Pluggy: data local, valor e tipo (funções
puras, plano `2026-11-04-sync-pluggy`). Valores fictícios."""

from datetime import UTC, date, datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

import pytest

from app.modulos.pluggy.normalizacao import (
    data_local,
    descricao_original,
    tipo_da_transacao,
    valor_da_transacao,
)
from app.modulos.pluggy.tipos import TransacaoPluggy
from app.modulos.transacoes.models import TipoTransacao

FORTALEZA = ZoneInfo("America/Fortaleza")


def _transacao(**mudancas) -> TransacaoPluggy:
    dados = {
        "id": "tx-1",
        "descricao": "Padaria Exemplo",
        "descricao_bruta": "PADARIA EXEMPLO LTDA",
        "valor": Decimal("-18.50"),
        "momento": datetime(2026, 10, 19, 15, 0, tzinfo=UTC),
        "sentido": "DEBIT",
        "status": "POSTED",
        "tipo_operacao": None,
        "categoria": None,
    }
    return TransacaoPluggy(**(dados | mudancas))


@pytest.mark.parametrize(
    ("momento", "esperada"),
    [
        # 01:30 UTC ainda é o dia anterior em Fortaleza (UTC−3).
        (datetime(2026, 10, 20, 1, 30, tzinfo=UTC), date(2026, 10, 19)),
        (datetime(2026, 10, 20, 3, 0, tzinfo=UTC), date(2026, 10, 20)),
        # A Pluggy manda meia-noite UTC quando a instituição só informa o dia.
        (datetime(2026, 10, 14, 0, 0, tzinfo=UTC), date(2026, 10, 13)),
    ],
)
def test_data_local_converte_de_utc_antes_de_truncar(momento, esperada):
    assert data_local(momento, FORTALEZA) == esperada


@pytest.mark.parametrize(
    ("valor", "esperado"),
    [(Decimal("-18.5"), Decimal("18.50")), (Decimal("1500"), Decimal("1500.00"))],
)
def test_valor_sempre_positivo_com_duas_casas(valor, esperado):
    assert valor_da_transacao(_transacao(valor=valor)) == esperado


def test_descricao_original_prefere_a_bruta_da_instituicao():
    assert descricao_original(_transacao()) == "PADARIA EXEMPLO LTDA"
    assert descricao_original(_transacao(descricao_bruta=None)) == "Padaria Exemplo"
    assert descricao_original(_transacao(descricao_bruta="  ", descricao="")) == "Sem descrição"


@pytest.mark.parametrize(
    ("sentido", "cartao", "tipo"),
    [
        ("CREDIT", False, TipoTransacao.receita),
        ("DEBIT", False, TipoTransacao.despesa),
        # No cartão a Pluggy já normaliza: compra é DEBIT, crédito é estorno.
        ("DEBIT", True, TipoTransacao.despesa),
        ("CREDIT", True, TipoTransacao.estorno),
    ],
)
def test_tipo_pelo_sentido_e_pela_conta(sentido, cartao, tipo):
    assert tipo_da_transacao(_transacao(sentido=sentido), cartao=cartao) == tipo


def test_pagamento_da_fatura_do_lado_do_cartao_nao_entra():
    pagamento = _transacao(sentido="CREDIT", tipo_operacao="PAGAMENTO_FATURA")

    assert tipo_da_transacao(pagamento, cartao=True) is None


def test_pagamento_de_fatura_na_conta_continua_saida():
    """Na conta, o pagamento é uma despesa até a revisão confirmá-lo como
    pagamento de fatura (a sugestão vem da revisão)."""
    pagamento = _transacao(sentido="DEBIT", tipo_operacao="PAGAMENTO_FATURA")

    assert tipo_da_transacao(pagamento, cartao=False) == TipoTransacao.despesa


@pytest.mark.parametrize(
    ("mudancas", "tipo"),
    [
        ({"sentido": "DEBIT", "tipo_operacao": "TRANSFERENCIA_SALDO_RESERVADO"}, "aporte"),
        ({"sentido": "CREDIT", "tipo_operacao": "TRANSFERENCIA_SALDO_RESERVADO"}, "resgate"),
        # A documentação não diz em qual campo a marca vem: a descrição também vale.
        ({"sentido": "DEBIT", "descricao_bruta": "TRANSFERENCIA_SALDO_RESERVADO"}, "aporte"),
    ],
)
def test_cofrinho_vira_aporte_ou_resgate(mudancas, tipo):
    assert tipo_da_transacao(_transacao(**mudancas), cartao=False) == TipoTransacao(tipo)
