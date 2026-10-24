"""Entrada e saída HTTP de contas."""

import uuid
from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.dinheiro import Dinheiro
from app.modulos.cartoes.datas import StatusFatura
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
    saldo_inicial: Dinheiro = Field(description="Saldo no começo do dia `data_saldo_inicial`.")
    data_saldo_inicial: date = Field(description="Não pode ser depois de hoje.")


class InstituicaoSaida(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    nome: str


class FaturaResumo(BaseModel):
    """Uma fatura: gravada ou, enquanto não recebeu transação nem foi editada,
    calculada pela regra do cartão."""

    competencia: date = Field(description="Primeiro dia do mês do vencimento.")
    data_fechamento: date
    data_vencimento: date
    status: StatusFatura = Field(description="Aberta antes do fechamento; fechada a partir dele.")
    valor: Dinheiro = Field(description="O maior entre o informado e o calculado.")
    valor_calculado: Dinheiro = Field(
        description="Compras menos estornos da fatura, com rascunhos e sem as ignoradas."
    )
    valor_informado: Dinheiro | None = Field(description="O total que o banco mostra.")


class CartaoSaida(BaseModel):
    conta_pagamento_id: uuid.UUID
    dia_fechamento: int
    dia_vencimento: int
    limite: Dinheiro | None
    fatura_atual: FaturaResumo = Field(description="A fatura de uma compra feita hoje.")


class ContaSaida(BaseModel):
    id: uuid.UUID
    nome: str
    tipo: TipoConta
    instituicao: InstituicaoSaida | None
    saldo_inicial: Dinheiro
    data_saldo_inicial: date
    saldo_atual: Dinheiro = Field(
        description=(
            "`saldo_inicial` mais as transações confirmadas com data a partir de "
            "`data_saldo_inicial`."
        )
    )
    ativa: bool
    cartao: CartaoSaida | None = Field(description="Dados do cartão; nulo se não for cartão.")


class ContasResumo(BaseModel):
    total_disponivel: Dinheiro = Field(
        description="Soma dos saldos das contas correntes e carteiras ativas; cartão não entra."
    )
    contas: list[ContaSaida]
