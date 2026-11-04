"""Problema de uma conexão para o card do Início (spec das conexões, decisões
do código): vencido > erro > sem dados > vencendo. Datas fictícias."""

from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from app.modulos.pluggy.problema import EstadoSync, Problema, mais_grave, problema_da_conexao

FORTALEZA = ZoneInfo("America/Fortaleza")
# 04/11, 15:00 em Fortaleza (18:00 UTC): a repescagem das 13:00 já passou.
AGORA = datetime(2026, 11, 4, 18, 0, tzinfo=UTC)


def _estado(**mudancas) -> EstadoSync:
    dados = {
        "criada_em": AGORA - timedelta(days=60),
        "consentimento_expira_em": AGORA + timedelta(days=200),
        "ultimo_sync_em": datetime(2026, 11, 4, 10, 2, tzinfo=UTC),
        "ultima_tentativa_em": datetime(2026, 11, 4, 10, 2, tzinfo=UTC),
        "ultimo_erro": None,
    }
    return EstadoSync(**(dados | mudancas))


def _problema(agora=AGORA, **mudancas):
    return problema_da_conexao(_estado(**mudancas), agora=agora, fuso=FORTALEZA)


def test_sem_problema():
    assert _problema() is None


def test_consentimento_vencido_vence_tudo():
    assert (
        _problema(
            consentimento_expira_em=AGORA - timedelta(minutes=1),
            ultimo_erro="A Pluggy respondeu com erro (500).",
        )
        == Problema.vencido
    )


def test_erro_so_depois_das_duas_tentativas():
    falhou = {
        "ultimo_sync_em": datetime(2026, 11, 3, 10, 2, tzinfo=UTC),
        "ultima_tentativa_em": datetime(2026, 11, 4, 16, 1, tzinfo=UTC),
        "ultimo_erro": "A Pluggy respondeu com erro (500).",
    }
    # 11:00 em Fortaleza: a repescagem das 13:00 ainda vai rodar.
    antes = datetime(2026, 11, 4, 14, 0, tzinfo=UTC)

    assert _problema(**falhou) == Problema.erro
    assert _problema(agora=antes, **falhou) is None


def test_sem_dados_ha_mais_de_30_horas():
    assert _problema(ultimo_sync_em=AGORA - timedelta(hours=31)) == Problema.sem_dados
    assert _problema(ultimo_sync_em=AGORA - timedelta(hours=29)) is None


def test_nunca_sincronizou_conta_desde_a_criacao():
    assert (
        _problema(
            ultimo_sync_em=None, ultima_tentativa_em=None, criada_em=AGORA - timedelta(hours=31)
        )
        == Problema.sem_dados
    )
    assert (
        _problema(
            ultimo_sync_em=None, ultima_tentativa_em=None, criada_em=AGORA - timedelta(hours=2)
        )
        is None
    )


@pytest.mark.parametrize(("dias", "esperado"), [(30, Problema.vencendo), (31, None)])
def test_consentimento_vencendo_em_30_dias(dias, esperado):
    assert _problema(consentimento_expira_em=AGORA + timedelta(days=dias)) == esperado


def test_mais_grave_entre_varias():
    assert mais_grave([None, Problema.vencendo, Problema.erro]) == Problema.erro
    assert mais_grave([None, None]) is None
