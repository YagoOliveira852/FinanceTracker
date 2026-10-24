"""Tabelas de cartões: os feriados que movem fechamento e vencimento."""

from datetime import date

from sqlalchemy import Date, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, ComTimestamps


class Feriado(ComTimestamps, Base):
    """Dia em que banco não abre: feriado nacional ou segunda e terça de Carnaval.

    O seed está na migration, com a lista escrita por extenso (ver a migration
    `cria_feriado`). Anos novos entram com uma migration nova.
    """

    __tablename__ = "feriado"

    data: Mapped[date] = mapped_column(Date, primary_key=True)
    descricao: Mapped[str] = mapped_column(Text)
