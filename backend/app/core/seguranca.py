"""Hash de senha (argon2), access token (JWT) e refresh token (aleatório + hash).

- Senha: argon2 é lento de propósito, para encarecer força bruta se o banco vazar.
- Access token: JWT assinado (HS256) e de vida curta; a API confere a assinatura
  e a validade sem consultar o banco.
- Refresh token: texto aleatório de 256 bits, sem significado. O banco guarda só
  o SHA-256 dele. Aqui um hash rápido basta (diferente da senha): com essa
  entropia não há o que adivinhar, e o hash determinístico permite buscar o
  token pelo índice único.
"""

import hashlib
import secrets
import uuid
from datetime import datetime, timedelta

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

ALGORITMO_JWT = "HS256"
TIPO_ACCESS = "access"

_hasher = PasswordHasher()
# Hash de uma senha qualquer, usado no login quando o e-mail não existe: assim
# o tempo de resposta não revela se o e-mail está cadastrado.
_HASH_FICTICIO = _hasher.hash("senha-ficticia-para-tempo-constante")


class TokenInvalido(Exception):
    """Access token ausente, malformado, com assinatura errada ou expirado."""


def hash_senha(senha: str) -> str:
    return _hasher.hash(senha)


def verificar_senha(senha: str, senha_hash: str | None) -> bool:
    """Confere a senha; com `senha_hash=None`, gasta o mesmo tempo e devolve False."""
    if senha_hash is None:
        _confere(senha, _HASH_FICTICIO)
        return False
    return _confere(senha, senha_hash)


def _confere(senha: str, senha_hash: str) -> bool:
    try:
        return _hasher.verify(senha_hash, senha)
    except (VerificationError, InvalidHashError):
        return False


def criar_access_token(
    usuario_id: uuid.UUID, segredo: str, validade: timedelta, agora: datetime
) -> str:
    payload = {
        "sub": str(usuario_id),
        "tipo": TIPO_ACCESS,
        "iat": agora,
        "exp": agora + validade,
    }
    return jwt.encode(payload, segredo, algorithm=ALGORITMO_JWT)


def ler_access_token(token: str, segredo: str) -> uuid.UUID:
    """Devolve o id do usuário do token ou levanta `TokenInvalido`."""
    try:
        payload = jwt.decode(
            token,
            segredo,
            # Fixar o algoritmo impede o ataque de trocar o "alg" do cabeçalho.
            algorithms=[ALGORITMO_JWT],
            options={"require": ["sub", "exp", "iat"]},
        )
        if payload.get("tipo") != TIPO_ACCESS:
            raise TokenInvalido
        return uuid.UUID(payload["sub"])
    except (jwt.InvalidTokenError, ValueError) as exc:
        raise TokenInvalido from exc


def gerar_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
