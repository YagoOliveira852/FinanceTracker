"""Fixtures compartilhadas.

Testes de integração rodam contra um Postgres 16 real, num container criado
pelo testcontainers (precisa do Docker). O schema vem das migrations do Alembic,
como em produção. Cada teste roda dentro de uma transação revertida ao final,
então nenhum teste vê dados de outro.

Nada aqui lê o `backend/.env`: a URL do banco vem do container.
"""

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta

import pytest
from alembic import command
from fastapi.testclient import TestClient
from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session
from testcontainers.community.postgres import PostgresContainer

from app.core.config import Settings, get_settings
from app.core.db import get_sessao
from app.core.deps import get_hoje
from app.core.seguranca import criar_access_token
from app.main import app
from app.modulos.auth import service as auth_service
from tests.utils import HOJE, alembic_config

IMAGEM_POSTGRES = "postgres:16-alpine"
SEGREDO_JWT_TESTE = "segredo-ficticio-de-teste-com-32-caracteres-ou-mais"


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
def config(url_banco: str) -> Settings:
    """Configuração fictícia montada aqui, sem ler o .env nem o ambiente."""
    return Settings(
        _env_file=None,
        database_url=url_banco,
        jwt_secret=SEGREDO_JWT_TESTE,
        access_token_minutos=15,
        refresh_token_dias=30,
    )


@pytest.fixture
def client(sessao: Session, config: Settings) -> Iterator[TestClient]:
    """TestClient cujas rotas usam a sessão, a configuração e o "hoje" do teste."""
    app.dependency_overrides[get_sessao] = lambda: sessao
    app.dependency_overrides[get_settings] = lambda: config
    app.dependency_overrides[get_hoje] = lambda: HOJE
    try:
        with TestClient(app) as client:
            yield client
    finally:
        app.dependency_overrides.clear()


@pytest.fixture
def api(client: TestClient, sessao: Session, config: Settings) -> TestClient:
    """O `client` já autenticado: um usuário fictício e o Bearer dele no cabeçalho."""
    usuario = auth_service.criar_usuario(sessao, "pessoa@exemplo.com", "senha-ficticia-123")
    token = criar_access_token(
        usuario.id, config.jwt_secret.get_secret_value(), timedelta(minutes=15), datetime.now(UTC)
    )
    client.headers["Authorization"] = f"Bearer {token}"
    return client
