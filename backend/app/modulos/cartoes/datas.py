"""Regra das datas da fatura: funções puras, sem banco e sem I/O.

Recebem os dias do cartão e os feriados e devolvem datas (spec
`2026-10-23-cartoes-faturas-design.md`):

1. Competência = mês do vencimento. Se o dia de fechamento é maior que o de
   vencimento, o fechamento cai no mês anterior ao da competência.
2. Dia que não existe no mês (31 em abril) vira o último dia do mês.
3. Fechamento e vencimento em fim de semana ou feriado passam para o próximo
   dia útil.
4. Uma compra entra na primeira fatura cujo fechamento é depois da data da
   compra: compra no dia do fechamento vai para a fatura seguinte.
"""

import calendar
from collections.abc import Callable, Collection
from dataclasses import dataclass
from datetime import date, timedelta
from enum import StrEnum

_SABADO = 5


class StatusFatura(StrEnum):
    aberta = "aberta"
    fechada = "fechada"


@dataclass(frozen=True)
class DatasFatura:
    """Datas de uma competência pela regra do cartão: a prevista (o dia do
    cartão no mês) e a efetiva (ajustada para dia útil)."""

    competencia: date
    fechamento_previsto: date
    fechamento: date
    vencimento_previsto: date
    vencimento: date


def competencia_de(dia: date) -> date:
    """Primeiro dia do mês de `dia`."""
    return dia.replace(day=1)


def mes_seguinte(competencia: date) -> date:
    if competencia.month == 12:
        return date(competencia.year + 1, 1, 1)
    return date(competencia.year, competencia.month + 1, 1)


def mes_anterior(competencia: date) -> date:
    if competencia.month == 1:
        return date(competencia.year - 1, 12, 1)
    return date(competencia.year, competencia.month - 1, 1)


def proximo_dia_util(dia: date, feriados: Collection[date]) -> date:
    """O próprio `dia`, se for útil; senão, o primeiro dia útil depois dele."""
    while dia.weekday() >= _SABADO or dia in feriados:
        dia += timedelta(days=1)
    return dia


def datas_da_fatura(
    competencia: date, dia_fechamento: int, dia_vencimento: int, feriados: Collection[date]
) -> DatasFatura:
    mes_fechamento = competencia if dia_fechamento < dia_vencimento else mes_anterior(competencia)
    fechamento_previsto = _dia_no_mes(mes_fechamento, dia_fechamento)
    vencimento_previsto = _dia_no_mes(competencia, dia_vencimento)
    return DatasFatura(
        competencia=competencia,
        fechamento_previsto=fechamento_previsto,
        fechamento=proximo_dia_util(fechamento_previsto, feriados),
        vencimento_previsto=vencimento_previsto,
        vencimento=proximo_dia_util(vencimento_previsto, feriados),
    )


def competencia_da_compra(dia: date, fechamento_de: Callable[[date], date]) -> date:
    """Competência da primeira fatura cujo fechamento é depois de `dia`.

    `fechamento_de(competencia)` dá o fechamento efetivo: o gravado, quando a
    fatura foi editada, ou o calculado pela regra. A busca começa dois meses
    antes do mês da compra porque o fechamento de uma competência cai no mês
    dela ou no anterior, e o ajuste para dia útil pode empurrá-lo alguns dias.
    """
    competencia = mes_anterior(mes_anterior(competencia_de(dia)))
    for _ in range(6):
        if fechamento_de(competencia) > dia:
            return competencia
        competencia = mes_seguinte(competencia)
    raise ValueError(f"Nenhuma fatura fecha depois de {dia} nos meses próximos.")


def status_da_fatura(data_fechamento: date, hoje: date) -> StatusFatura:
    """Aberta antes do fechamento; fechada a partir dele."""
    return StatusFatura.aberta if hoje < data_fechamento else StatusFatura.fechada


def _dia_no_mes(competencia: date, dia: int) -> date:
    ultimo = calendar.monthrange(competencia.year, competencia.month)[1]
    return competencia.replace(day=min(dia, ultimo))
