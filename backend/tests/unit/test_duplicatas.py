"""Possível duplicata entre uma linha nova e o que já estava na conta (função
pura; spec `2026-10-28-importacao-design`, "Possível duplicata")."""

import uuid
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal

import pytest

from app.modulos.importacao.duplicatas import marcar_duplicatas


@dataclass(frozen=True)
class Nova:
    data: date
    valor: Decimal = Decimal("64.90")
    entrada: bool = False


@dataclass(frozen=True)
class Existente:
    data: date
    valor: Decimal = Decimal("64.90")
    entrada: bool = False
    id: uuid.UUID = field(default_factory=uuid.uuid4)


def _dia(dia: int) -> date:
    return date(2026, 10, dia)


@pytest.mark.parametrize(
    ("dia_nova", "dia_existente", "casa"),
    [
        (12, 12, True),
        (12, 13, True),
        (12, 14, True),  # 2 dias: ainda casa
        (14, 12, True),  # o lançamento manual pode vir antes ou depois
        (12, 15, False),  # 3 dias: não
        (15, 12, False),
    ],
)
def test_diferenca_de_dias(dia_nova, dia_existente, casa):
    existente = Existente(_dia(dia_existente))

    assert marcar_duplicatas([Nova(_dia(dia_nova))], [existente]) == (
        {0: existente} if casa else {}
    )


def test_valor_diferente_nao_casa():
    assert marcar_duplicatas([Nova(_dia(12))], [Existente(_dia(12), Decimal("64.91"))]) == {}


def test_sentido_oposto_nao_casa():
    assert marcar_duplicatas([Nova(_dia(12))], [Existente(_dia(12), entrada=True)]) == {}


def test_entradas_iguais_casam():
    existente = Existente(_dia(12), entrada=True)

    assert marcar_duplicatas([Nova(_dia(12), entrada=True)], [existente]) == {0: existente}


def test_uma_existente_casa_com_uma_nova_so_a_de_data_mais_perto():
    existente = Existente(_dia(12))
    novas = [Nova(_dia(14)), Nova(_dia(13))]

    assert marcar_duplicatas(novas, [existente]) == {1: existente}


def test_uma_nova_casa_com_uma_existente_so_a_de_data_mais_perto():
    longe, perto = Existente(_dia(10)), Existente(_dia(11))

    assert marcar_duplicatas([Nova(_dia(12))], [longe, perto]) == {0: perto}


def test_duas_novas_e_duas_existentes_iguais_casam_uma_a_uma():
    primeira, segunda = Existente(_dia(12)), Existente(_dia(12))
    novas = [Nova(_dia(12)), Nova(_dia(12))]

    resultado = marcar_duplicatas(novas, [primeira, segunda])

    assert set(resultado) == {0, 1}
    assert {resultado[0].id, resultado[1].id} == {primeira.id, segunda.id}


def test_empate_resolvido_igual_em_qualquer_ordem():
    a, b = Existente(_dia(11)), Existente(_dia(13))
    nova = Nova(_dia(12))

    esperado = min(a, b, key=lambda existente: existente.id)
    assert marcar_duplicatas([nova], [a, b]) == {0: esperado}
    assert marcar_duplicatas([nova], [b, a]) == {0: esperado}


def test_sem_existentes():
    assert marcar_duplicatas([Nova(_dia(12))], []) == {}
