"""Entrada e saída HTTP de transações."""

import uuid
from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.dinheiro import Dinheiro, DinheiroPositivo
from app.modulos.transacoes.models import FonteTransacao, StatusTransacao, TipoTransacao


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
