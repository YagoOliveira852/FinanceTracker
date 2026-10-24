"""Entrada e saída HTTP de cartões e faturas."""

import uuid
from datetime import date

from pydantic import BaseModel, ConfigDict, Field

from app.core.dinheiro import DinheiroPositivo


class CartaoEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nome: str = Field(min_length=1, max_length=100)
    instituicao: str = Field(
        min_length=1,
        max_length=100,
        description=(
            "Nome da instituição. Se nenhuma tiver esse nome (sem diferenciar "
            "maiúsculas), uma nova é criada."
        ),
    )
    conta_pagamento_id: uuid.UUID = Field(description="Conta corrente ativa que paga a fatura.")
    dia_fechamento: int = Field(ge=1, le=31, description="31 vira o último dia do mês.")
    dia_vencimento: int = Field(
        ge=1, le=31, description="Diferente do fechamento; 31 vira o último dia do mês."
    )
    limite: DinheiroPositivo | None = None


class DatasFaturaSaida(BaseModel):
    """Competência e datas efetivas de uma fatura (ajustadas para dia útil)."""

    competencia: date = Field(description="Primeiro dia do mês do vencimento.")
    data_fechamento: date
    data_vencimento: date
