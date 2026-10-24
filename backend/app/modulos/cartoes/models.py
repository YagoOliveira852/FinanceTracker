"""Tabelas de cartões: o cartão, as faturas dele e os feriados que movem
fechamento e vencimento."""

import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Numeric,
    SmallInteger,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, ComTimestamps
from app.modulos.contas.models import Conta


class Cartao(ComTimestamps, Base):
    """Dados de cartão de uma conta `cartao_credito` (1:1 com a conta).

    Os dias de fechamento e vencimento são do cartão; as datas de cada fatura
    saem deles pela regra de `cartoes/datas.py`.
    """

    __tablename__ = "cartao"
    __table_args__ = (
        CheckConstraint("dia_fechamento BETWEEN 1 AND 31", name="dia_fechamento_valido"),
        CheckConstraint("dia_vencimento BETWEEN 1 AND 31", name="dia_vencimento_valido"),
        CheckConstraint("dia_fechamento <> dia_vencimento", name="dias_diferentes"),
        CheckConstraint("limite > 0", name="limite_positivo"),
    )

    conta_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("conta.id"), primary_key=True)
    # Conta corrente de onde sai o pagamento da fatura.
    conta_pagamento_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("conta.id"), index=True)
    dia_fechamento: Mapped[int] = mapped_column(SmallInteger)
    dia_vencimento: Mapped[int] = mapped_column(SmallInteger)
    limite: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))

    conta: Mapped[Conta] = relationship(foreign_keys=[conta_id], lazy="joined")
    conta_pagamento: Mapped[Conta] = relationship(foreign_keys=[conta_pagamento_id])


class Fatura(ComTimestamps, Base):
    """Fatura de uma competência (mês do vencimento) de um cartão.

    Só existe no banco depois que recebe uma transação ou é editada; antes
    disso, a API a calcula pela regra do cartão. O status (aberta/fechada) não
    é guardado: sai da data de fechamento e de hoje.
    """

    __tablename__ = "fatura"
    __table_args__ = (
        UniqueConstraint("cartao_id", "competencia", name="uq_fatura_cartao_id_competencia"),
        CheckConstraint("EXTRACT(DAY FROM competencia) = 1", name="competencia_primeiro_dia"),
        CheckConstraint(
            "data_vencimento > data_fechamento", name="vencimento_depois_do_fechamento"
        ),
        CheckConstraint("valor_informado >= 0", name="valor_informado_nao_negativo"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    cartao_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("cartao.conta_id"), index=True)
    # Primeiro dia do mês da fatura (ex.: 2026-11-01 = fatura de novembro).
    competencia: Mapped[date] = mapped_column(Date)
    data_fechamento: Mapped[date] = mapped_column(Date)
    data_vencimento: Mapped[date] = mapped_column(Date)
    # O total que o banco mostra; nulo enquanto não informado.
    valor_informado: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))


class Feriado(ComTimestamps, Base):
    """Dia em que banco não abre: feriado nacional ou segunda e terça de Carnaval.

    O seed está na migration, com a lista escrita por extenso (ver a migration
    `cria_feriado`). Anos novos entram com uma migration nova.
    """

    __tablename__ = "feriado"

    data: Mapped[date] = mapped_column(Date, primary_key=True)
    descricao: Mapped[str] = mapped_column(Text)
