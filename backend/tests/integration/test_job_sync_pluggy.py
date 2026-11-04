"""Job do sync: código de saída, resumo e credenciais (cliente falso). Dados
fictícios."""

from datetime import UTC, datetime

import pytest

from app.core.config import Settings
from app.jobs import sync_pluggy
from app.modulos.pluggy.client import ErroPluggy
from tests.integration.test_sync_pluggy import PluggyFalsa, _conexao, _tx
from tests.utils import criar_conta


@pytest.fixture
def agora():
    return datetime(2026, 10, 20, 10, 0, tzinfo=UTC)


def test_sai_com_zero_quando_todas_deram_certo(sessao, config, agora, capsys):
    _conexao(sessao, "item-1")
    pluggy = PluggyFalsa()

    codigo = sync_pluggy.executar(sessao, pluggy, config, agora=agora, repescagem=False)

    assert codigo == 0
    assert "0 novas" in capsys.readouterr().out


def test_sai_com_um_se_alguma_falhou(sessao, config, agora, capsys):
    _conexao(sessao, "item-1")
    pluggy = PluggyFalsa()
    pluggy.erros["item-1"] = ErroPluggy("A Pluggy respondeu com erro (500).")

    codigo = sync_pluggy.executar(sessao, pluggy, config, agora=agora, repescagem=False)

    assert codigo == 1
    assert "A Pluggy respondeu com erro (500)." in capsys.readouterr().err


def test_hoje_e_o_do_fuso_de_negocio(sessao, config, capsys):
    """Às 01:30 UTC de 21/10 ainda é 20/10 em Fortaleza: a janela começa em 10/09."""
    conexao = _conexao(sessao, "item-1")
    conta = criar_conta(sessao)
    conta.conexao_pluggy_id = conexao.id
    conta.pluggy_account_id = "conta-1"
    pluggy = PluggyFalsa()
    pluggy.transacoes["conta-1"] = [_tx("tx-1")]

    sync_pluggy.executar(
        sessao, pluggy, config, agora=datetime(2026, 10, 21, 1, 30, tzinfo=UTC), repescagem=False
    )

    assert pluggy.pedidos[0][1].isoformat() == "2026-09-10"


def test_sem_credenciais_nao_roda(monkeypatch, url_banco, capsys):
    config = Settings(
        _env_file=None,
        database_url=url_banco,
        jwt_secret="x" * 32,
        pluggy_client_id="",
        pluggy_client_secret="",
    )
    monkeypatch.setattr(sync_pluggy, "get_settings", lambda: config)

    assert sync_pluggy.main([]) == 2
    assert "PLUGGY_CLIENT_ID" in capsys.readouterr().err
