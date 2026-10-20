"""Entrada e saída HTTP da autenticação.

A resposta de token segue os nomes do OAuth2 (`access_token`, `token_type`...),
que é a convenção que clientes HTTP e bibliotecas esperam.
"""

import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class LoginEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: str
    senha: str


class RefreshEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    refresh_token: str


class Tokens(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int = Field(description="Segundos até o access token expirar.")


class UsuarioSaida(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
