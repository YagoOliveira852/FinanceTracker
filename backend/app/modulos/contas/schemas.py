"""Entrada e saída HTTP de contas."""

import uuid
from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.dinheiro import Dinheiro
from app.modulos.contas.models import TipoConta


class ContaEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nome: str = Field(min_length=1, max_length=100)
    # Cartão de crédito tem fechamento, vencimento e faturas: entra com o módulo
    # de cartões.
    tipo: Literal[TipoConta.corrente, TipoConta.carteira]
    instituicao: str | None = Field(
        default=None,
        min_length=1,
        max_length=100,
        description=(
            "Nome da instituição. Obrigatório na conta corrente e ausente na carteira. "
            "Se nenhuma instituição tiver esse nome (sem diferenciar maiúsculas), "
            "uma nova é criada."
        ),
    )
    saldo_inicial: Dinheiro = Field(description="Saldo ao fim do dia `data_saldo_inicial`.")
    data_saldo_inicial: date = Field(description="Não pode ser depois de hoje.")


class InstituicaoSaida(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    nome: str


class ContaSaida(BaseModel):
    id: uuid.UUID
    nome: str
    tipo: TipoConta
    instituicao: InstituicaoSaida | None
    saldo_inicial: Dinheiro
    data_saldo_inicial: date
    saldo_atual: Dinheiro = Field(
        description=(
            "`saldo_inicial` mais as transações confirmadas com data depois de "
            "`data_saldo_inicial`."
        )
    )
    ativa: bool


class ContasResumo(BaseModel):
    total_disponivel: Dinheiro = Field(
        description="Soma dos saldos das contas correntes e carteiras ativas; cartão não entra."
    )
    contas: list[ContaSaida]
