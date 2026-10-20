"""Dependências compartilhadas pelas rotas (`Depends`)."""

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.db import get_sessao
from app.core.seguranca import TokenInvalido
from app.modulos.auth.models import Usuario
from app.modulos.auth.service import usuario_do_access_token

SessaoDep = Annotated[Session, Depends(get_sessao)]
ConfigDep = Annotated[Settings, Depends(get_settings)]

# auto_error=False: sem o cabeçalho, devolvemos o 401 em pt-BR em vez do
# 403 padrão do FastAPI. O HTTPBearer também declara o esquema no OpenAPI.
_bearer = HTTPBearer(auto_error=False)


def get_usuario_atual(
    sessao: SessaoDep,
    config: ConfigDep,
    credenciais: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> Usuario:
    """Usuário do `Authorization: Bearer <access token>`; 401 se faltar ou não valer."""
    if credenciais is None:
        raise _nao_autenticado("Não autenticado.")
    try:
        return usuario_do_access_token(sessao, config, credenciais.credentials)
    except TokenInvalido as exc:
        raise _nao_autenticado("Sessão inválida ou expirada.") from exc


def _nao_autenticado(detail: str) -> HTTPException:
    return HTTPException(
        status.HTTP_401_UNAUTHORIZED, detail=detail, headers={"WWW-Authenticate": "Bearer"}
    )


UsuarioDep = Annotated[Usuario, Depends(get_usuario_atual)]
