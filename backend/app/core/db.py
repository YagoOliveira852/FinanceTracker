"""Engine, sessão e `Base` dos modelos SQLAlchemy."""

from collections.abc import Iterator
from functools import lru_cache

from sqlalchemy import Engine, MetaData, create_engine
from sqlalchemy.orm import DeclarativeBase, Session

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


@lru_cache
def get_engine() -> Engine:
    """Cria o engine na primeira chamada, não no import (testes não leem o .env)."""
    return create_engine(str(get_settings().database_url), pool_pre_ping=True)


def get_sessao() -> Iterator[Session]:
    """Uma sessão por requisição, fechada ao final mesmo se a rota falhar."""
    with Session(get_engine()) as sessao:
        yield sessao
