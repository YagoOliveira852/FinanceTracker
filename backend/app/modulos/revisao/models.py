"""Tabela da revisão: os pares de transferência que o usuário disse que não são par."""

import uuid

from sqlalchemy import CheckConstraint, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, ComTimestamps


class ParRecusado(ComTimestamps, Base):
    """ "Não é par" na revisão: a sugestão desta saída com esta entrada não
    volta, mas cada lado ainda pode parear com outra transação (um booleano na
    transação bloquearia todos os pares dela)."""

    __tablename__ = "par_recusado"
    __table_args__ = (
        UniqueConstraint("saida_id", "entrada_id", name="uq_par_recusado_saida_id_entrada_id"),
        CheckConstraint("saida_id <> entrada_id", name="lados_diferentes"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    # CASCADE: o sync da Pluggy apaga rascunho que sumiu da origem.
    saida_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("transacao.id", ondelete="CASCADE"), index=True
    )
    entrada_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("transacao.id", ondelete="CASCADE"), index=True
    )
