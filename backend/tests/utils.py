"""Funções de apoio aos testes (as fixtures ficam no conftest.py)."""

from datetime import date
from pathlib import Path

from alembic.config import Config

ALEMBIC_INI = Path(__file__).resolve().parents[1] / "alembic.ini"

# "Hoje" fixo nos testes de API (a fixture `client` sobrescreve `get_hoje`).
HOJE = date(2026, 10, 20)


def alembic_config(url: str) -> Config:
    """Config do Alembic apontando para o banco de teste, sem ler a DATABASE_URL."""
    config = Config(ALEMBIC_INI)
    config.set_main_option("sqlalchemy.url", url.replace("%", "%%"))
    return config
