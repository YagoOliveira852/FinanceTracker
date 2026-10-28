"""Divisão e data das parcelas de uma compra parcelada (spec 2026-10-24)."""

from datetime import date
from decimal import Decimal

import pytest

from app.modulos.transacoes.parcelas import data_da_compra, data_da_parcela, dividir_em_parcelas


@pytest.mark.parametrize(
    ("total", "quantidade", "parcelas"),
    [
        ("1000.00", 3, ["333.34", "333.33", "333.33"]),
        ("300.00", 3, ["100.00", "100.00", "100.00"]),
        # Resto máximo: N−1 centavos, todos na 1ª.
        ("1.00", 7, ["0.16"] + ["0.14"] * 6),
        # O mínimo: um centavo por parcela.
        ("0.03", 3, ["0.01", "0.01", "0.01"]),
        ("2499.90", 10, ["249.99"] * 10),
        ("100.01", 2, ["50.01", "50.00"]),
    ],
)
def test_dividir_em_parcelas(total, quantidade, parcelas):
    resultado = dividir_em_parcelas(Decimal(total), quantidade)

    assert resultado == [Decimal(p) for p in parcelas]
    assert sum(resultado) == Decimal(total)


def test_dividir_sem_centavo_para_cada_parcela_e_erro():
    with pytest.raises(ValueError):
        dividir_em_parcelas(Decimal("0.02"), 3)


@pytest.mark.parametrize(
    ("data_compra", "numero", "esperada"),
    [
        (date(2026, 10, 20), 1, date(2026, 10, 20)),
        (date(2026, 10, 20), 3, date(2026, 12, 20)),
        (date(2026, 10, 31), 2, date(2026, 11, 30)),
        (date(2026, 10, 31), 4, date(2027, 1, 31)),
        (date(2027, 1, 31), 2, date(2027, 2, 28)),
        (date(2028, 1, 31), 2, date(2028, 2, 29)),
        (date(2026, 6, 15), 24, date(2028, 5, 15)),
    ],
)
def test_data_da_parcela(data_compra, numero, esperada):
    assert data_da_parcela(data_compra, numero) == esperada


@pytest.mark.parametrize(
    ("data_parcela", "numero", "esperada"),
    [
        (date(2026, 10, 15), 1, date(2026, 10, 15)),
        (date(2026, 10, 15), 3, date(2026, 8, 15)),
        (date(2026, 2, 10), 4, date(2025, 11, 10)),  # vira o ano
        (date(2026, 3, 31), 2, date(2026, 2, 28)),  # 31 fev não existe
        (date(2026, 1, 20), 13, date(2025, 1, 20)),
    ],
)
def test_data_da_compra(data_parcela, numero, esperada):
    assert data_da_compra(data_parcela, numero) == esperada
