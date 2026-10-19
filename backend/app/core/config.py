"""Configuração da aplicação, lida de variáveis de ambiente e do `backend/.env`."""

from functools import lru_cache
from pathlib import Path

from pydantic import PostgresDsn
from pydantic_settings import BaseSettings, SettingsConfigDict

ARQUIVO_ENV = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    # Variável de ambiente tem prioridade sobre o .env. Chaves que ainda não
    # usamos (ex.: PLUGGY_*) são ignoradas em vez de derrubar a aplicação.
    model_config = SettingsConfigDict(
        env_file=ARQUIVO_ENV, env_file_encoding="utf-8", extra="ignore"
    )

    database_url: PostgresDsn


@lru_cache
def get_settings() -> Settings:
    """Lê a configuração uma única vez por processo."""
    return Settings()
