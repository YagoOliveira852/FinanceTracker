"""Comando de terminal `python -m app.criar_usuario`, com a digitação simulada."""

import getpass

import pytest
from sqlalchemy import select

from app import criar_usuario
from app.modulos.auth.models import Usuario

SENHA = "senha-ficticia-123"


@pytest.fixture
def digitar(monkeypatch):
    """Simula o que a pessoa digita: o e-mail no input, as senhas no getpass."""

    def _digitar(email: str, senha: str, confirmacao: str) -> None:
        senhas = iter([senha, confirmacao])
        monkeypatch.setattr("builtins.input", lambda _prompt: email)
        monkeypatch.setattr(getpass, "getpass", lambda _prompt: next(senhas))

    return _digitar


def test_cria_o_usuario(sessao, digitar, capsys):
    digitar("pessoa@exemplo.com", SENHA, SENHA)

    assert criar_usuario.executar(sessao) == 0

    assert "Usuário pessoa@exemplo.com criado." in capsys.readouterr().out
    assert sessao.scalar(select(Usuario.email)) == "pessoa@exemplo.com"


def test_senhas_diferentes_nao_criam_nada(sessao, digitar, capsys):
    digitar("pessoa@exemplo.com", SENHA, "outra-senha-123")

    assert criar_usuario.executar(sessao) == 1

    assert "As senhas não conferem." in capsys.readouterr().err
    assert sessao.scalar(select(Usuario)) is None


def test_senha_curta_mostra_o_motivo(sessao, digitar, capsys):
    digitar("pessoa@exemplo.com", "curta", "curta")

    assert criar_usuario.executar(sessao) == 1

    assert "pelo menos 8 caracteres" in capsys.readouterr().err


def test_segundo_usuario_e_recusado(sessao, digitar, capsys):
    digitar("pessoa@exemplo.com", SENHA, SENHA)
    criar_usuario.executar(sessao)
    digitar("outra@exemplo.com", SENHA, SENHA)

    assert criar_usuario.executar(sessao) == 1

    assert "Já existe um usuário cadastrado" in capsys.readouterr().err
