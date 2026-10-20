"""Entrada e saída HTTP da autenticação.

A resposta de token segue os nomes do OAuth2 (`access_token`, `token_type`...),
que é a convenção que clientes HTTP e bibliotecas esperam.
"""

import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.modulos.auth.service import TAMANHO_MAXIMO_SENHA


# Limites de tamanho: sem eles, uma "senha" de megabytes iria inteira para o
# argon2 a cada tentativa de login.
class LoginEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: str = Field(max_length=320)
    senha: str = Field(max_length=TAMANHO_MAXIMO_SENHA)


class RefreshEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    refresh_token: str = Field(max_length=256)


class Tokens(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int = Field(description="Segundos até o access token expirar.")


class UsuarioSaida(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
