"""As migrations sobem e descem num banco vazio e batem com os modelos."""

import re
from collections.abc import Iterator

import pytest
from alembic import command
from sqlalchemy import CheckConstraint, create_engine, text
from sqlalchemy.engine import make_url

import app.modulos.cartoes.models  # noqa: F401
import app.modulos.contas.models  # noqa: F401
import app.modulos.transacoes.models  # noqa: F401
from app.core.db import Base
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


def _checks_de_enum_dos_modelos() -> dict[str, set[str]]:
    """{nome do CHECK: valores} de cada `check_enum` declarado nos modelos."""
    checks = {}
    for tabela in Base.metadata.tables.values():
        for constraint in tabela.constraints:
            if isinstance(constraint, CheckConstraint):
                enum = re.fullmatch(r"\w+ IN \((.*)\)", str(constraint.sqltext))
                if enum:
                    checks[str(constraint.name)] = set(re.findall(r"'([^']*)'", enum.group(1)))
    return checks


def test_check_dos_enums_no_banco_bate_com_os_modelos(url_banco_vazio):
    """O autogenerate (e o `alembic check`) não enxerga mudança em CHECK: este
    teste pega a migration escrita à mão que esqueceu ou errou um valor."""
    command.upgrade(alembic_config(url_banco_vazio), "head")
    engine = create_engine(url_banco_vazio)
    with engine.connect() as conexao:
        linhas = conexao.execute(
            text("SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint WHERE contype = 'c'")
        ).all()
    engine.dispose()
    no_banco = {nome: set(re.findall(r"'([^']*)'::text", definicao)) for nome, definicao in linhas}

    esperados = _checks_de_enum_dos_modelos()

    assert esperados  # o teste não pode passar por não achar nada
    for nome, valores in esperados.items():
        assert no_banco.get(nome) == valores, nome
