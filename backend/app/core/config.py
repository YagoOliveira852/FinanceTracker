"""Configuração da aplicação, lida de variáveis de ambiente e do `backend/.env`."""

from functools import lru_cache
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import Field, PostgresDsn, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

ARQUIVO_ENV = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    # Variável de ambiente tem prioridade sobre o .env. Chaves desconhecidas
    # são ignoradas em vez de derrubar a aplicação.
    model_config = SettingsConfigDict(
        env_file=ARQUIVO_ENV, env_file_encoding="utf-8", extra="ignore"
    )

    database_url: PostgresDsn
    # SecretStr: não aparece em repr nem em log por engano.
    jwt_secret: SecretStr = Field(min_length=32)
    access_token_minutos: int = Field(default=15, gt=0)
    refresh_token_dias: int = Field(default=30, gt=0)
    # Fuso das datas de negócio: "hoje" é calculado nele, não no do servidor
    # (a VPS roda em UTC, 3 h à frente de Fortaleza).
    tz_negocio: str = "America/Fortaleza"
    # Credenciais da Pluggy, só no backend. Opcionais: sem elas a API sobe e
    # o sync recusa rodar.
    pluggy_client_id: str | None = None
    pluggy_client_secret: SecretStr | None = None
    pluggy_url: str = "https://api.pluggy.ai"

    @field_validator("tz_negocio")
    @classmethod
    def _fuso_existe(cls, valor: str) -> str:
        try:
            ZoneInfo(valor)
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise ValueError(f"Fuso horário desconhecido: {valor!r}.") from exc
        return valor


@lru_cache
def get_settings() -> Settings:
    """Lê a configuração uma única vez por processo."""
    return Settings()
