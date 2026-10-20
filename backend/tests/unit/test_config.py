import pytest
from pydantic import ValidationError

from app.core.config import Settings

URL = "postgresql+psycopg://financas:senha-ficticia@localhost:5432/financas"
SEGREDO = "segredo-ficticio-de-teste-com-32-caracteres-ou-mais"


@pytest.fixture(autouse=True)
def ambiente_valido(monkeypatch):
    """Ambiente mínimo válido; cada teste tira ou troca o que quer testar."""
    monkeypatch.setenv("DATABASE_URL", URL)
    monkeypatch.setenv("JWT_SECRET", SEGREDO)
    monkeypatch.delenv("ACCESS_TOKEN_MINUTOS", raising=False)
    monkeypatch.delenv("REFRESH_TOKEN_DIAS", raising=False)


def test_le_database_url_do_ambiente():
    settings = Settings(_env_file=None)

    assert str(settings.database_url) == URL


def test_falha_sem_database_url(monkeypatch):
    monkeypatch.delenv("DATABASE_URL")

    with pytest.raises(ValidationError):
        Settings(_env_file=None)


def test_recusa_url_que_nao_e_postgres(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "sqlite:///financas.db")

    with pytest.raises(ValidationError):
        Settings(_env_file=None)


def test_ignora_variaveis_que_a_app_ainda_nao_usa(monkeypatch, tmp_path):
    arquivo_env = tmp_path / ".env"
    arquivo_env.write_text(
        f"DATABASE_URL={URL}\nJWT_SECRET={SEGREDO}\nOUTRA_CHAVE=qualquer\n", encoding="utf-8"
    )
    monkeypatch.delenv("DATABASE_URL")
    monkeypatch.delenv("JWT_SECRET")

    settings = Settings(_env_file=arquivo_env)

    assert str(settings.database_url) == URL


def test_falha_sem_jwt_secret(monkeypatch):
    monkeypatch.delenv("JWT_SECRET")

    with pytest.raises(ValidationError):
        Settings(_env_file=None)


def test_recusa_jwt_secret_curto(monkeypatch):
    monkeypatch.setenv("JWT_SECRET", "curto")

    with pytest.raises(ValidationError):
        Settings(_env_file=None)


def test_jwt_secret_nao_aparece_no_repr():
    settings = Settings(_env_file=None)

    assert SEGREDO not in repr(settings)
    assert settings.jwt_secret.get_secret_value() == SEGREDO


def test_validade_dos_tokens_tem_padrao_e_pode_mudar(monkeypatch):
    padrao = Settings(_env_file=None)
    monkeypatch.setenv("ACCESS_TOKEN_MINUTOS", "5")
    monkeypatch.setenv("REFRESH_TOKEN_DIAS", "7")
    alterado = Settings(_env_file=None)

    assert (padrao.access_token_minutos, padrao.refresh_token_dias) == (15, 30)
    assert (alterado.access_token_minutos, alterado.refresh_token_dias) == (5, 7)
