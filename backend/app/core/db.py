"""Engine, sessão e `Base` dos modelos SQLAlchemy."""

from collections.abc import Iterator
from datetime import datetime
from enum import StrEnum
from functools import lru_cache

from sqlalchemy import CheckConstraint, DateTime, Engine, MetaData, create_engine, func
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column

from app.core.config import get_settings

# Nomes previsíveis para constraints: o Alembic consegue apagá-las e
# recriá-las nas migrations (o CHECK dos enums depende disso).
CONVENCAO_DE_NOMES = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=CONVENCAO_DE_NOMES)


class ComTimestamps:
    """`criado_em`/`atualizado_em` (timestamptz) preenchidos pelo banco."""

    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    atualizado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


def check_enum(coluna: str, enum: type[StrEnum]) -> CheckConstraint:
    """CHECK que limita uma coluna `text` aos valores do enum (`ck_<tabela>_<coluna>`).

    Enums do domínio são `text` + CHECK, não enum nativo do Postgres. Ao mudar os
    valores de um enum, a migration precisa ser escrita à mão: o autogenerate não
    enxerga mudança em CHECK.
    """
    valores = ", ".join(f"'{membro.value}'" for membro in enum)
    return CheckConstraint(f"{coluna} IN ({valores})", name=coluna)


@lru_cache
def get_engine() -> Engine:
    """Cria o engine na primeira chamada, não no import (testes não leem o .env)."""
    return create_engine(str(get_settings().database_url), pool_pre_ping=True)


def get_sessao() -> Iterator[Session]:
    """Uma sessão por requisição, fechada ao final mesmo se a rota falhar."""
    with Session(get_engine()) as sessao:
        yield sessao
