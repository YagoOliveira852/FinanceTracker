"""Regra das datas da fatura: dia útil, competência e status (spec 2026-10-23)."""

from datetime import date

import pytest

from app.modulos.cartoes.datas import (
    DatasFatura,
    StatusFatura,
    competencia_da_compra,
    datas_da_fatura,
    mes_anterior,
    mes_seguinte,
    proximo_dia_util,
    status_da_fatura,
)

# Feriados nacionais de verdade (não são dado pessoal), Carnaval incluído.
FERIADOS = {
    date(2026, 2, 16),
    date(2026, 2, 17),
    date(2026, 10, 12),
    date(2026, 11, 2),
    date(2026, 12, 25),
    date(2027, 1, 1),
}


@pytest.mark.parametrize(
    ("dia", "esperado"),
    [
        (date(2026, 10, 20), date(2026, 10, 20)),  # terça: já é dia útil
        (date(2026, 10, 10), date(2026, 10, 13)),  # sábado, e segunda 12/10 é feriado
        (date(2026, 10, 11), date(2026, 10, 13)),  # domingo
        (date(2026, 12, 25), date(2026, 12, 28)),  # Natal numa sexta
        (date(2026, 2, 16), date(2026, 2, 18)),  # Carnaval: a Quarta de Cinzas é útil
    ],
)
def test_proximo_dia_util(dia, esperado):
    assert proximo_dia_util(dia, FERIADOS) == esperado


@pytest.mark.parametrize(
    ("competencia", "dia_fechamento", "dia_vencimento", "esperado"),
    [
        # Exemplo de referência: fecha dia 3, vence dia 10.
        (
            date(2026, 10, 1),
            3,
            10,
            DatasFatura(
                competencia=date(2026, 10, 1),
                fechamento_previsto=date(2026, 10, 3),
                fechamento=date(2026, 10, 5),
                vencimento_previsto=date(2026, 10, 10),
                vencimento=date(2026, 10, 13),
            ),
        ),
        (
            date(2026, 11, 1),
            3,
            10,
            DatasFatura(
                competencia=date(2026, 11, 1),
                fechamento_previsto=date(2026, 11, 3),
                fechamento=date(2026, 11, 3),
                vencimento_previsto=date(2026, 11, 10),
                vencimento=date(2026, 11, 10),
            ),
        ),
        (
            date(2026, 12, 1),
            3,
            10,
            DatasFatura(
                competencia=date(2026, 12, 1),
                fechamento_previsto=date(2026, 12, 3),
                fechamento=date(2026, 12, 3),
                vencimento_previsto=date(2026, 12, 10),
                vencimento=date(2026, 12, 10),
            ),
        ),
        # Fechamento no mês anterior ao da competência.
        (
            date(2026, 11, 1),
            28,
            5,
            DatasFatura(
                competencia=date(2026, 11, 1),
                fechamento_previsto=date(2026, 10, 28),
                fechamento=date(2026, 10, 28),
                vencimento_previsto=date(2026, 11, 5),
                vencimento=date(2026, 11, 5),
            ),
        ),
        # Dia 31 em fevereiro vira o último dia (domingo) e passa para segunda.
        (
            date(2027, 3, 1),
            31,
            10,
            DatasFatura(
                competencia=date(2027, 3, 1),
                fechamento_previsto=date(2027, 2, 28),
                fechamento=date(2027, 3, 1),
                vencimento_previsto=date(2027, 3, 10),
                vencimento=date(2027, 3, 10),
            ),
        ),
        # Dia 31 em abril.
        (
            date(2026, 4, 1),
            3,
            31,
            DatasFatura(
                competencia=date(2026, 4, 1),
                fechamento_previsto=date(2026, 4, 3),
                fechamento=date(2026, 4, 3),
                vencimento_previsto=date(2026, 4, 30),
                vencimento=date(2026, 4, 30),
            ),
        ),
        # Virada de ano: fecha no Natal, vence num sábado depois do Ano-Novo.
        (
            date(2027, 1, 1),
            25,
            2,
            DatasFatura(
                competencia=date(2027, 1, 1),
                fechamento_previsto=date(2026, 12, 25),
                fechamento=date(2026, 12, 28),
                vencimento_previsto=date(2027, 1, 2),
                vencimento=date(2027, 1, 4),
            ),
        ),
    ],
)
def test_datas_da_fatura(competencia, dia_fechamento, dia_vencimento, esperado):
    assert datas_da_fatura(competencia, dia_fechamento, dia_vencimento, FERIADOS) == esperado


def _fechamento_do_exemplo(competencia: date) -> date:
    return datas_da_fatura(competencia, 3, 10, FERIADOS).fechamento


@pytest.mark.parametrize(
    ("dia", "competencia"),
    [
        (date(2026, 9, 30), date(2026, 10, 1)),
        (date(2026, 10, 3), date(2026, 10, 1)),  # fechamento previsto, mas é sábado
        (date(2026, 10, 4), date(2026, 10, 1)),
        (date(2026, 10, 5), date(2026, 11, 1)),  # dia do fechamento: fatura seguinte
        (date(2026, 10, 20), date(2026, 11, 1)),
        (date(2026, 11, 3), date(2026, 12, 1)),
    ],
)
def test_competencia_da_compra(dia, competencia):
    assert competencia_da_compra(dia, _fechamento_do_exemplo) == competencia


def test_competencia_da_compra_respeita_fechamento_editado():
    def fechamento(competencia: date) -> date:
        if competencia == date(2026, 10, 1):
            return date(2026, 10, 8)
        return _fechamento_do_exemplo(competencia)

    assert competencia_da_compra(date(2026, 10, 6), fechamento) == date(2026, 10, 1)


@pytest.mark.parametrize(
    ("hoje", "status"),
    [
        (date(2026, 10, 4), StatusFatura.aberta),
        (date(2026, 10, 5), StatusFatura.fechada),
        (date(2026, 10, 20), StatusFatura.fechada),
    ],
)
def test_status_da_fatura(hoje, status):
    assert status_da_fatura(date(2026, 10, 5), hoje) == status


def test_mes_seguinte_e_anterior_viram_o_ano():
    assert mes_seguinte(date(2026, 12, 1)) == date(2027, 1, 1)
    assert mes_anterior(date(2027, 1, 1)) == date(2026, 12, 1)
