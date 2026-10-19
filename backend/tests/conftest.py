"""Fixtures compartilhadas.

Testes de integração rodam contra um Postgres 16 real, num container criado
pelo testcontainers (precisa do Docker). O schema vem das migrations do Alembic,
como em produção. Cada teste roda dentro de uma transação revertida ao final,
então nenhum teste vê dados de outro.

Nada aqui lê o `backend/.env`: a URL do banco vem do container.
"""

from collections.abc import Iterator

import pytest
from alembic import command
from fastapi.testclient import TestClient
from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session
from testcontainers.community.postgres import PostgresContainer

from app.core.db import get_sessao
from app.main import app
from tests.utils import alembic_config

IMAGEM_POSTGRES = "postgres:16-alpine"


@pytest.fixture(scope="session")
def url_banco() -> Iterator[str]:
    with PostgresContainer(IMAGEM_POSTGRES, driver="psycopg") as postgres:
        yield postgres.get_connection_url()


@pytest.fixture(scope="session")
def engine(url_banco: str) -> Iterator[Engine]:
    command.upgrade(alembic_config(url_banco), "head")
    engine = create_engine(url_banco)
    yield engine
    engine.dispose()


@pytest.fixture
def sessao(engine: Engine) -> Iterator[Session]:
    """Sessão dentro de uma transação revertida ao fim do teste.

    `create_savepoint` faz o `commit()` do código testado virar um SAVEPOINT:
    o service pode commitar normalmente e, mesmo assim, nada sobra no banco.
    """
    with engine.connect() as conexao:
        transacao = conexao.begin()
        sessao = Session(bind=conexao, join_transaction_mode="create_savepoint")
        try:
            yield sessao
        finally:
            sessao.close()
            transacao.rollback()


@pytest.fixture
def client(sessao: Session) -> Iterator[TestClient]:
    """TestClient cujas rotas usam a sessão do teste no lugar da real."""
    app.dependency_overrides[get_sessao] = lambda: sessao
    try:
        with TestClient(app) as client:
            yield client
    finally:
        app.dependency_overrides.clear()
