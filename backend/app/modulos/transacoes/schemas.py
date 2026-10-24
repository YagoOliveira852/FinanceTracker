"""Entrada e saída HTTP de transações."""

import uuid
from datetime import date
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.dinheiro import Dinheiro, DinheiroPositivo
from app.modulos.transacoes.models import (
    FonteTransacao,
    StatusTransacao,
    TipoTransacao,
    Transacao,
)


class TransacaoEntrada(BaseModel):
    """Lançamento manual. Entra já confirmado: só o que vem de importação ou da
    Pluggy passa pela revisão."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    conta_id: uuid.UUID
    # Transferência e pagamento de fatura ligam duas contas: entram com cartões.
    tipo: Literal[TipoTransacao.despesa, TipoTransacao.receita]
    valor: DinheiroPositivo = Field(description="Sempre positivo; o sentido vem do `tipo`.")
    data: date
    descricao: str = Field(min_length=1, max_length=200)


class CompraParceladaEntrada(BaseModel):
    """Compra parcelada no cartão: gera uma despesa por parcela, cada uma na
    sua fatura. À vista é o lançamento comum."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    conta_id: uuid.UUID
    valor_total: DinheiroPositivo = Field(
        description="O total da compra; o centavo que sobra da divisão vai para a 1ª parcela."
    )
    qtd_parcelas: int = Field(ge=2, le=24)
    data_compra: date
    descricao: str = Field(min_length=1, max_length=200)


class ParcelaSaida(BaseModel):
    compra_parcelada_id: uuid.UUID
    numero: int
    total: int


class TransacaoSaida(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    conta_id: uuid.UUID
    tipo: TipoTransacao
    valor: Dinheiro
    data: date
    descricao: str
    descricao_original: str
    status: StatusTransacao
    fonte: FonteTransacao
    fatura_id: uuid.UUID | None = Field(description="Fatura da transação, se a conta é cartão.")
    parcela: ParcelaSaida | None = Field(description="Número da parcela, se é compra parcelada.")

    @model_validator(mode="before")
    @classmethod
    def _parcela_da_transacao(cls, dados: Any) -> Any:
        """Monta `parcela` a partir da compra parcelada da transação."""
        if not isinstance(dados, Transacao):
            return dados
        compra = dados.compra_parcelada
        parcela = None
        if compra is not None:
            parcela = ParcelaSaida(
                compra_parcelada_id=compra.id,
                numero=dados.parcela_numero,
                total=compra.qtd_parcelas,
            )
        campos = {campo: getattr(dados, campo) for campo in cls.model_fields if campo != "parcela"}
        return campos | {"parcela": parcela}


class CompraParceladaSaida(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    descricao: str
    valor_total: Dinheiro
    qtd_parcelas: int
    data_compra: date
    data_compra_estimada: bool
    parcelas: list[TransacaoSaida] = Field(description="Da 1ª à última parcela.")
