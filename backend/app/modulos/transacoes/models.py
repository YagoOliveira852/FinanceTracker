"""Tabela de transações: cada entrada ou saída de dinheiro de uma conta."""

import uuid
from datetime import date
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import CheckConstraint, Date, ForeignKey, Numeric, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, ComTimestamps, check_enum


class TipoTransacao(StrEnum):
    despesa = "despesa"
    receita = "receita"
    transferencia_saida = "transferencia_saida"
    transferencia_entrada = "transferencia_entrada"
    pagamento_fatura = "pagamento_fatura"
    aporte = "aporte"
    resgate = "resgate"
    estorno = "estorno"
    # Correção de saldo na conferência com o banco (sobrou ou faltou dinheiro).
    ajuste_entrada = "ajuste_entrada"
    ajuste_saida = "ajuste_saida"


# O valor é sempre positivo; o sentido vem do tipo. Todo tipo está em exatamente
# um dos dois conjuntos (há teste garantindo).
TIPOS_ENTRADA = frozenset(
    {
        TipoTransacao.receita,
        TipoTransacao.transferencia_entrada,
        TipoTransacao.resgate,
        TipoTransacao.estorno,
        TipoTransacao.ajuste_entrada,
    }
)
TIPOS_SAIDA = frozenset(
    {
        TipoTransacao.despesa,
        TipoTransacao.transferencia_saida,
        TipoTransacao.pagamento_fatura,
        TipoTransacao.aporte,
        TipoTransacao.ajuste_saida,
    }
)


class StatusTransacao(StrEnum):
    rascunho = "rascunho"
    confirmada = "confirmada"
    ignorada = "ignorada"


class FonteTransacao(StrEnum):
    manual = "manual"
    ofx = "ofx"
    csv_mercadopago = "csv_mercadopago"
    pluggy = "pluggy"


class Transacao(ComTimestamps, Base):
    __tablename__ = "transacao"
    __table_args__ = (
        check_enum("tipo", TipoTransacao),
        check_enum("status", StatusTransacao),
        check_enum("fonte", FonteTransacao),
        CheckConstraint("valor > 0", name="valor_positivo"),
        # Coração da idempotência: a mesma transação da mesma fonte não entra
        # duas vezes. Lançamento manual tem id_externo nulo e não colide.
        UniqueConstraint(
            "conta_id", "fonte", "id_externo", name="uq_transacao_conta_id_fonte_id_externo"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    conta_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("conta.id"), index=True)
    tipo: Mapped[str] = mapped_column(Text)
    valor: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    # Data da operação (compra, Pix), no fuso do negócio.
    data: Mapped[date] = mapped_column(Date, index=True)
    # Como veio do banco, nunca editada; `descricao` é a que o usuário edita.
    descricao_original: Mapped[str] = mapped_column(Text)
    descricao: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text)
    fonte: Mapped[str] = mapped_column(Text)
    # FITID do OFX, id da Pluggy ou hash do CSV; nulo no lançamento manual.
    id_externo: Mapped[str | None] = mapped_column(Text)
