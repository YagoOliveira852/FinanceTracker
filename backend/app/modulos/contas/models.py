"""Tabelas de contas: a instituição (banco) e a conta que guarda dinheiro."""

import uuid
from datetime import date
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import CheckConstraint, Date, ForeignKey, Numeric, Text, UniqueConstraint, true
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, ComTimestamps, check_enum


class TipoConta(StrEnum):
    corrente = "corrente"
    cartao_credito = "cartao_credito"
    carteira = "carteira"


class Instituicao(ComTimestamps, Base):
    """Banco ou instituição de pagamento (ex.: Banco Exemplo)."""

    __tablename__ = "instituicao"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    nome: Mapped[str] = mapped_column(Text, unique=True)


class Conta(ComTimestamps, Base):
    """Conta corrente, cartão de crédito ou carteira (dinheiro em espécie).

    O saldo atual não é guardado: é `saldo_inicial` mais as transações
    confirmadas a partir de `data_saldo_inicial` (ver `contas/service.py`).
    """

    __tablename__ = "conta"
    __table_args__ = (
        check_enum("tipo", TipoConta),
        # A carteira é a única conta sem banco por trás.
        CheckConstraint(
            "tipo = 'carteira' OR instituicao_id IS NOT NULL", name="instituicao_obrigatoria"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    instituicao_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("instituicao.id"), index=True
    )
    nome: Mapped[str] = mapped_column(Text)
    tipo: Mapped[str] = mapped_column(Text)
    saldo_inicial: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    data_saldo_inicial: Mapped[date] = mapped_column(Date)
    ativa: Mapped[bool] = mapped_column(default=True, server_default=true())

    # lazy="joined": a lista de contas traz a instituição no mesmo SELECT (sem N+1).
    instituicao: Mapped[Instituicao | None] = relationship(lazy="joined")


class FonteSnapshot(StrEnum):
    manual = "manual"
    ofx = "ofx"
    csv_mercadopago = "csv_mercadopago"
    pluggy = "pluggy"


class SnapshotSaldo(ComTimestamps, Base):
    """Saldo real de uma conta numa data, como o banco informou: serve para
    conferir o saldo calculado e para o 31/12 do IR.

    Vem do saldo de um extrato importado (`LEDGERBAL` do OFX ou a última linha
    do CSV do Mercado Pago, com a importação que o gravou, para o desfazer
    apagá-lo) ou da Pluggy. Investimentos entram aqui quando existirem
    (`investimento_id`, e `conta_id` passa a ser opcional).
    """

    __tablename__ = "snapshot_saldo"
    __table_args__ = (
        check_enum("fonte", FonteSnapshot),
        UniqueConstraint("conta_id", "data", name="uq_snapshot_saldo_conta_id_data"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    conta_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("conta.id"))
    data: Mapped[date] = mapped_column(Date)
    saldo: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    fonte: Mapped[str] = mapped_column(Text)
    importacao_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("importacao.id"), index=True)
