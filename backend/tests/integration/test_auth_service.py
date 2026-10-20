"""Criação do usuário único (usada pelo comando `criar_usuario` e pelo seed)."""

import pytest
from sqlalchemy import func, select

from app.core.seguranca import verificar_senha
from app.modulos.auth import service
from app.modulos.auth.models import Usuario

SENHA = "senha-ficticia-123"


def test_cria_usuario_com_email_normalizado_e_senha_em_hash(sessao):
    usuario = service.criar_usuario(sessao, "  Pessoa@Exemplo.COM ", SENHA)

    assert usuario.email == "pessoa@exemplo.com"
    assert usuario.senha_hash != SENHA
    assert verificar_senha(SENHA, usuario.senha_hash)
    assert usuario.criado_em is not None


def test_nao_cria_segundo_usuario(sessao):
    service.criar_usuario(sessao, "pessoa@exemplo.com", SENHA)

    with pytest.raises(service.UsuarioJaExiste):
        service.criar_usuario(sessao, "outra@exemplo.com", SENHA)
    assert sessao.scalar(select(func.count()).select_from(Usuario)) == 1


@pytest.mark.parametrize("email", ["sem-arroba", "pessoa@", ""])
def test_recusa_email_invalido(sessao, email):
    with pytest.raises(service.DadosInvalidos, match="E-mail inválido."):
        service.criar_usuario(sessao, email, SENHA)


def test_recusa_senha_curta(sessao):
    with pytest.raises(service.DadosInvalidos, match="pelo menos 12 caracteres"):
        service.criar_usuario(sessao, "pessoa@exemplo.com", "curta-11ch")
