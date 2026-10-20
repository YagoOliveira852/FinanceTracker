"""Regras da autenticação: criar o usuário único, login e refresh com rotação.

Nada aqui sabe de HTTP: erros são exceções próprias, que o router traduz em 401.
"""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from pydantic import EmailStr, TypeAdapter, ValidationError
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.seguranca import (
    TokenInvalido,
    criar_access_token,
    gerar_refresh_token,
    hash_refresh_token,
    hash_senha,
    ler_access_token,
    verificar_senha,
)
from app.modulos.auth.models import RefreshToken, Usuario

TAMANHO_MINIMO_SENHA = 12

_validador_email = TypeAdapter(EmailStr)


class DadosInvalidos(Exception):
    """E-mail ou senha que não servem para criar o usuário (mensagem em pt-BR)."""


class UsuarioJaExiste(Exception):
    """O app tem um usuário só; não dá para criar um segundo."""


class CredenciaisInvalidas(Exception):
    """E-mail não cadastrado ou senha errada (de propósito, sem dizer qual)."""


class RefreshInvalido(Exception):
    """Refresh token desconhecido, expirado ou já usado."""


@dataclass(frozen=True)
class ParDeTokens:
    access_token: str
    refresh_token: str
    access_expira_em_segundos: int


def normalizar_email(email: str) -> str:
    return email.strip().lower()


def criar_usuario(sessao: Session, email: str, senha: str) -> Usuario:
    """Cria o usuário único. Usado pelo comando `criar_usuario` e pelo seed."""
    email = normalizar_email(email)
    try:
        _validador_email.validate_python(email)
    except ValidationError as exc:
        raise DadosInvalidos("E-mail inválido.") from exc
    if len(senha) < TAMANHO_MINIMO_SENHA:
        raise DadosInvalidos(f"A senha precisa ter pelo menos {TAMANHO_MINIMO_SENHA} caracteres.")
    if sessao.scalar(select(func.count()).select_from(Usuario)):
        raise UsuarioJaExiste

    usuario = Usuario(email=email, senha_hash=hash_senha(senha))
    sessao.add(usuario)
    sessao.commit()
    return usuario


def login(
    sessao: Session, config: Settings, email: str, senha: str, agora: datetime | None = None
) -> ParDeTokens:
    usuario = sessao.scalar(select(Usuario).where(Usuario.email == normalizar_email(email)))
    # Sem usuário, a verificação roda mesmo assim contra um hash fictício:
    # o tempo de resposta não denuncia quais e-mails existem.
    if not verificar_senha(senha, usuario.senha_hash if usuario else None):
        raise CredenciaisInvalidas
    return _emitir_tokens(sessao, config, usuario.id, agora or _agora())


def renovar(
    sessao: Session, config: Settings, refresh_token: str, agora: datetime | None = None
) -> ParDeTokens:
    """Troca um refresh token válido por um par novo e revoga o usado.

    Se o token já tinha sido revogado, alguém está reutilizando um token antigo
    (o app sempre usa o mais recente): todas as sessões do usuário caem.
    """
    agora = agora or _agora()
    # FOR UPDATE: duas renovações simultâneas com o mesmo token não passam as
    # duas; a segunda espera e enxerga o token já revogado.
    registro = sessao.scalar(
        select(RefreshToken)
        .where(RefreshToken.token_hash == hash_refresh_token(refresh_token))
        .with_for_update()
    )
    if registro is None:
        raise RefreshInvalido
    if registro.revogado_em is not None:
        _revogar_todos(sessao, registro.usuario_id, agora)
        sessao.commit()
        raise RefreshInvalido
    if registro.expira_em <= agora:
        raise RefreshInvalido

    registro.revogado_em = agora
    return _emitir_tokens(sessao, config, registro.usuario_id, agora)


def usuario_do_access_token(sessao: Session, config: Settings, token: str) -> Usuario:
    """Usuário dono do access token, ou `TokenInvalido`."""
    usuario_id = ler_access_token(token, config.jwt_secret.get_secret_value())
    usuario = sessao.get(Usuario, usuario_id)
    if usuario is None:
        raise TokenInvalido
    return usuario


def _emitir_tokens(
    sessao: Session, config: Settings, usuario_id: uuid.UUID, agora: datetime
) -> ParDeTokens:
    validade_access = timedelta(minutes=config.access_token_minutos)
    refresh_token = gerar_refresh_token()
    sessao.add(
        RefreshToken(
            usuario_id=usuario_id,
            token_hash=hash_refresh_token(refresh_token),
            expira_em=agora + timedelta(days=config.refresh_token_dias),
        )
    )
    sessao.commit()
    return ParDeTokens(
        access_token=criar_access_token(
            usuario_id, config.jwt_secret.get_secret_value(), validade_access, agora
        ),
        refresh_token=refresh_token,
        access_expira_em_segundos=int(validade_access.total_seconds()),
    )


def _revogar_todos(sessao: Session, usuario_id: uuid.UUID, agora: datetime) -> None:
    sessao.execute(
        update(RefreshToken)
        .where(RefreshToken.usuario_id == usuario_id, RefreshToken.revogado_em.is_(None))
        .values(revogado_em=agora)
    )


def _agora() -> datetime:
    return datetime.now(UTC)
