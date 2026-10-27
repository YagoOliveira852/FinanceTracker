"""Sugestão de pares de transferência entre contas próprias (função pura)."""

import uuid
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal

import pytest

from app.modulos.revisao.pareamento import sugerir_pares

CONTA_PRINCIPAL = uuid.uuid4()
CONTA_DIA_A_DIA = uuid.uuid4()
CARTEIRA = uuid.uuid4()


@dataclass(frozen=True)
class Mov:
    conta_id: uuid.UUID
    data: date
    valor: Decimal = Decimal("300.00")
    id: uuid.UUID = field(default_factory=uuid.uuid4)


def _saida(dia: int, **mudancas) -> Mov:
    return Mov(
        conta_id=mudancas.pop("conta_id", CONTA_PRINCIPAL), data=date(2026, 10, dia), **mudancas
    )


def _entrada(dia: int, **mudancas) -> Mov:
    return Mov(
        conta_id=mudancas.pop("conta_id", CONTA_DIA_A_DIA), data=date(2026, 10, dia), **mudancas
    )


@pytest.mark.parametrize(
    ("dia_saida", "dia_entrada", "pareia"),
    [
        (24, 24, True),
        (24, 25, True),
        (24, 26, True),  # 2 dias: ainda casa
        (26, 24, True),  # a entrada pode vir antes (fuso, compensação)
        (24, 27, False),  # 3 dias: não
        (27, 24, False),
    ],
)
def test_diferenca_de_dias(dia_saida, dia_entrada, pareia):
    saida, entrada = _saida(dia_saida), _entrada(dia_entrada)

    assert sugerir_pares([saida], [entrada], set()) == ([(saida, entrada)] if pareia else [])


def test_valor_diferente_em_um_centavo_nao_pareia():
    saida, entrada = _saida(24), _entrada(24, valor=Decimal("300.01"))

    assert sugerir_pares([saida], [entrada], set()) == []


def test_mesma_conta_nao_pareia():
    saida, entrada = _saida(24), _entrada(24, conta_id=CONTA_PRINCIPAL)

    assert sugerir_pares([saida], [entrada], set()) == []


def test_par_recusado_nao_volta_mas_a_saida_pareia_com_outra_entrada():
    saida = _saida(24)
    recusada = _entrada(24)
    outra = _entrada(25, conta_id=CARTEIRA)

    pares = sugerir_pares([saida], [recusada, outra], {(saida.id, recusada.id)})

    assert pares == [(saida, outra)]


def test_entre_duas_entradas_vence_a_de_data_mais_proxima():
    saida = _saida(24)
    longe, perto = _entrada(26), _entrada(25, conta_id=CARTEIRA)

    assert sugerir_pares([saida], [longe, perto], set()) == [(saida, perto)]


def test_duas_saidas_para_uma_entrada_so_uma_ganha():
    perto, longe = _saida(25), _saida(23, conta_id=CARTEIRA)
    entrada = _entrada(25)

    assert sugerir_pares([longe, perto], [entrada], set()) == [(perto, entrada)]


def test_cada_transacao_entra_em_um_par_so():
    saidas = [_saida(24), _saida(24, conta_id=CARTEIRA)]
    entradas = [_entrada(24), _entrada(24)]

    pares = sugerir_pares(saidas, entradas, set())

    assert len(pares) == 2
    assert {s.id for s, _ in pares} == {s.id for s in saidas}
    assert {e.id for _, e in pares} == {e.id for e in entradas}


def test_empate_total_decide_pelo_menor_id():
    ids = sorted(uuid.uuid4() for _ in range(2))
    primeira, segunda = _entrada(24, id=ids[0]), _entrada(24, id=ids[1], conta_id=CARTEIRA)
    saida = _saida(24)

    assert sugerir_pares([saida], [segunda, primeira], set()) == [(saida, primeira)]


def test_ordena_pela_data_da_saida():
    antiga, nova = _saida(20, valor=Decimal("10.00")), _saida(24)
    e_antiga, e_nova = _entrada(20, valor=Decimal("10.00")), _entrada(24)

    assert sugerir_pares([nova, antiga], [e_nova, e_antiga], set()) == [
        (antiga, e_antiga),
        (nova, e_nova),
    ]


def test_listas_vazias():
    assert sugerir_pares([], [], set()) == []
    assert sugerir_pares([_saida(24)], [], set()) == []
