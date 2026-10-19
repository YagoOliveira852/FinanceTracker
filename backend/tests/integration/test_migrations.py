"""As migrations sobem e descem num banco vazio e batem com os modelos."""

from collections.abc import Iterator

import pytest
from alembic import command
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

from tests.utils import alembic_config

NOME_BANCO = "migrations_teste"


@pytest.fixture(scope="module")
def url_banco_vazio(url_banco: str) -> Iterator[str]:
    """Um banco separado, para não mexer no schema que os outros testes usam."""
    admin = create_engine(url_banco, isolation_level="AUTOCOMMIT")
    with admin.connect() as conexao:
        conexao.execute(text(f"CREATE DATABASE {NOME_BANCO}"))
    try:
        yield make_url(url_banco).set(database=NOME_BANCO).render_as_string(hide_password=False)
    finally:
        with admin.connect() as conexao:
            conexao.execute(text(f"DROP DATABASE {NOME_BANCO} WITH (FORCE)"))
        admin.dispose()


def test_upgrade_downgrade_e_upgrade_de_novo(url_banco_vazio):
    config = alembic_config(url_banco_vazio)

    command.upgrade(config, "head")
    command.downgrade(config, "base")
    command.upgrade(config, "head")


def test_modelos_nao_tem_mudanca_sem_migration(url_banco_vazio):
    """Falha se alguém mudou um model e esqueceu de gerar a migration."""
    config = alembic_config(url_banco_vazio)
    command.upgrade(config, "head")

    command.check(config)
