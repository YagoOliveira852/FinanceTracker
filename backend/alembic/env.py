"""Ambiente do Alembic: liga as migrations aos modelos e ao banco da aplicação."""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, pool

import app.modulos.auth.models  # noqa: F401
from app.core.config import get_settings
from app.core.db import Base

config = context.config

if config.config_file_name is not None:
    # Sem desligar os loggers que já existem (ex.: os da app, quando os testes
    # rodam as migrations no mesmo processo).
    fileConfig(config.config_file_name, disable_existing_loggers=False)

# Cada models.py novo precisa ser importado aqui para o autogenerate enxergar
# as tabelas dele.
target_metadata = Base.metadata


def _url_do_banco() -> str:
    """URL passada pelo chamador (ex.: testes) ou, por padrão, a DATABASE_URL."""
    return config.get_main_option("sqlalchemy.url") or str(get_settings().database_url)


def run_migrations_offline() -> None:
    """Gera o SQL sem conectar no banco (`alembic upgrade head --sql`)."""
    context.configure(
        url=_url_do_banco(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Conecta no banco e aplica as migrations."""
    engine = create_engine(_url_do_banco(), poolclass=pool.NullPool)
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
