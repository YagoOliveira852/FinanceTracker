"""Parcelas de uma compra parcelada: funções puras, sem banco e sem I/O.

Spec `2026-10-24-compra-parcelada-design.md`: cada parcela vale o total
dividido por N, truncado no centavo, e o que sobra vai inteiro para a 1ª; a
parcela k tem a data da compra mais k−1 meses.
"""

import calendar
from datetime import date
from decimal import ROUND_DOWN, Decimal

_CENTAVO = Decimal("0.01")


def dividir_em_parcelas(total: Decimal, quantidade: int) -> list[Decimal]:
    """Valores das parcelas, da 1ª à última; a soma é sempre o total.

    Levanta `ValueError` se o total não dá um centavo para cada parcela.
    """
    base = (total / quantidade).quantize(_CENTAVO, rounding=ROUND_DOWN)
    if base < _CENTAVO:
        raise ValueError(f"{total} não dá um centavo para cada uma de {quantidade} parcelas.")
    primeira = total - base * (quantidade - 1)
    return [primeira] + [base] * (quantidade - 1)


def data_da_parcela(data_compra: date, numero: int) -> date:
    """Data da parcela `numero` (a 1ª é a própria compra). Dia que não existe
    no mês vira o último dia dele: 31 jan + 1 mês = 28 ou 29 fev."""
    meses = data_compra.month - 1 + numero - 1
    ano = data_compra.year + meses // 12
    mes = meses % 12 + 1
    ultimo = calendar.monthrange(ano, mes)[1]
    return date(ano, mes, min(data_compra.day, ultimo))


def data_da_compra(data_parcela: date, numero: int) -> date:
    """Data estimada da compra a partir da parcela `numero` (o inverso de
    `data_da_parcela`): recua `numero − 1` meses. Usada quando a fonte só traz
    a data de cobrança (OFX); dia que não existe no mês vira o último."""
    meses = data_parcela.year * 12 + data_parcela.month - 1 - (numero - 1)
    ano, mes = divmod(meses, 12)
    ultimo = calendar.monthrange(ano, mes + 1)[1]
    return date(ano, mes + 1, min(data_parcela.day, ultimo))
