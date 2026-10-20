"""Rotas de autenticação. Só traduzem HTTP; as regras estão no service."""

from fastapi import APIRouter, HTTPException, status

from app.core.deps import ConfigDep, SessaoDep, UsuarioDep
from app.core.erros import RespostaErro
from app.modulos.auth import service
from app.modulos.auth.schemas import LoginEntrada, RefreshEntrada, Tokens, UsuarioSaida

router = APIRouter(prefix="/auth", tags=["auth"])

_NAO_AUTENTICADO = {status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}}
_CABECALHO_BEARER = {"WWW-Authenticate": "Bearer"}


@router.post("/login", responses=_NAO_AUTENTICADO)
def login(dados: LoginEntrada, sessao: SessaoDep, config: ConfigDep) -> Tokens:
    """Troca e-mail e senha por um access token (curto) e um refresh token (longo)."""
    try:
        par = service.login(sessao, config, dados.email, dados.senha)
    except service.CredenciaisInvalidas as exc:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            detail="E-mail ou senha incorretos.",
            headers=_CABECALHO_BEARER,
        ) from exc
    return _tokens(par)


@router.post("/refresh", responses=_NAO_AUTENTICADO)
def refresh(dados: RefreshEntrada, sessao: SessaoDep, config: ConfigDep) -> Tokens:
    """Troca o refresh token por um par novo; o token enviado deixa de valer."""
    try:
        par = service.renovar(sessao, config, dados.refresh_token)
    except service.RefreshInvalido as exc:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            detail="Sessão expirada. Faça login de novo.",
            headers=_CABECALHO_BEARER,
        ) from exc
    return _tokens(par)


@router.get("/eu", responses=_NAO_AUTENTICADO)
def eu(usuario: UsuarioDep) -> UsuarioSaida:
    """Usuário dono do access token enviado."""
    return UsuarioSaida.model_validate(usuario)


def _tokens(par: service.ParDeTokens) -> Tokens:
    return Tokens(
        access_token=par.access_token,
        refresh_token=par.refresh_token,
        expires_in=par.access_expira_em_segundos,
    )
