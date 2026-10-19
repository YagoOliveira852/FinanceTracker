"""Funções de apoio aos testes (as fixtures ficam no conftest.py)."""

from pathlib import Path

from alembic.config import Config

ALEMBIC_INI = Path(__file__).resolve().parents[1] / "alembic.ini"


def alembic_config(url: str) -> Config:
    """Config do Alembic apontando para o banco de teste, sem ler a DATABASE_URL."""
    config = Config(ALEMBIC_INI)
    config.set_main_option("sqlalchemy.url", url.replace("%", "%%"))
    return config
