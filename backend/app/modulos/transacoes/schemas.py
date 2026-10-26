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
    # Transferência e pagamento de fatura ligam duas contas e têm rotas próprias.
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


class TransferenciaEntrada(BaseModel):
    """Transferência entre contas próprias (corrente ou carteira): gera a saída
    na origem e a entrada no destino, ligadas."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    conta_origem_id: uuid.UUID
    conta_destino_id: uuid.UUID
    valor: DinheiroPositivo
    data: date
    descricao: str | None = Field(
        default=None, max_length=200, description='Vazia ou nula: "Transferência".'
    )


class ParcelaSaida(BaseModel):
    compra_parcelada_id: uuid.UUID
    numero: int
    total: int


class TransferenciaParSaida(BaseModel):
    par_id: uuid.UUID = Field(description="O outro lado da transferência.")
    conta_origem_id: uuid.UUID
    conta_destino_id: uuid.UUID


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
    transferencia: TransferenciaParSaida | None = Field(
        description="O par e as duas contas, se é transferência ligada."
    )

    @model_validator(mode="before")
    @classmethod
    def _montar_da_transacao(cls, dados: Any) -> Any:
        """Monta `parcela` e `transferencia` a partir dos relacionamentos."""
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
        par = dados.transferencia_par
        transferencia = None
        if par is not None:
            saida, entrada = (
                (dados, par) if dados.tipo == TipoTransacao.transferencia_saida else (par, dados)
            )
            transferencia = TransferenciaParSaida(
                par_id=par.id, conta_origem_id=saida.conta_id, conta_destino_id=entrada.conta_id
            )
        montados = {"parcela": parcela, "transferencia": transferencia}
        campos = {
            campo: getattr(dados, campo) for campo in cls.model_fields if campo not in montados
        }
        return campos | montados


class CompraParceladaSaida(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    descricao: str
    valor_total: Dinheiro
    qtd_parcelas: int
    data_compra: date
    data_compra_estimada: bool
    parcelas: list[TransacaoSaida] = Field(description="Da 1ª à última parcela.")


class TransferenciaSaida(BaseModel):
    saida: TransacaoSaida = Field(description="O lado da conta de origem.")
    entrada: TransacaoSaida = Field(description="O lado da conta de destino.")
