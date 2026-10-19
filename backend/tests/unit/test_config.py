import pytest
from pydantic import ValidationError

from app.core.config import Settings

URL = "postgresql+psycopg://financas:senha-ficticia@localhost:5432/financas"


def test_le_database_url_do_ambiente(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", URL)

    settings = Settings(_env_file=None)

    assert str(settings.database_url) == URL


def test_falha_sem_database_url(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)

    with pytest.raises(ValidationError):
        Settings(_env_file=None)


def test_recusa_url_que_nao_e_postgres(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "sqlite:///financas.db")

    with pytest.raises(ValidationError):
        Settings(_env_file=None)


def test_ignora_variaveis_que_a_app_ainda_nao_usa(monkeypatch, tmp_path):
    arquivo_env = tmp_path / ".env"
    arquivo_env.write_text(f"DATABASE_URL={URL}\nOUTRA_CHAVE=qualquer\n", encoding="utf-8")
    monkeypatch.delenv("DATABASE_URL", raising=False)

    settings = Settings(_env_file=arquivo_env)

    assert str(settings.database_url) == URL
