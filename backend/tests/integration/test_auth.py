"""Fluxo de autenticação pela API: login, refresh com rotação e rota protegida."""

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select

from app.core.seguranca import criar_access_token, hash_refresh_token
from app.modulos.auth import service
from app.modulos.auth.models import RefreshToken, Usuario

EMAIL = "pessoa@exemplo.com"
SENHA = "senha-ficticia-123"


@pytest.fixture
def usuario(sessao) -> Usuario:
    return service.criar_usuario(sessao, EMAIL, SENHA)


def _login(client, email=EMAIL, senha=SENHA):
    return client.post("/auth/login", json={"email": email, "senha": senha})


def _refresh(client, refresh_token):
    return client.post("/auth/refresh", json={"refresh_token": refresh_token})


def _eu(client, access_token):
    return client.get("/auth/eu", headers={"Authorization": f"Bearer {access_token}"})


def _registro(sessao, refresh_token) -> RefreshToken:
    return sessao.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(refresh_token))
    )


# --- login -------------------------------------------------------------------


def test_login_devolve_tokens_que_abrem_a_rota_protegida(client, usuario):
    resposta = _login(client)

    assert resposta.status_code == 200
    corpo = resposta.json()
    assert corpo["token_type"] == "bearer"
    assert corpo["expires_in"] == 15 * 60
    eu = _eu(client, corpo["access_token"])
    assert eu.status_code == 200
    assert eu.json() == {"id": str(usuario.id), "email": EMAIL}


def test_login_ignora_maiusculas_e_espacos_no_email(client, usuario):
    assert _login(client, email="  Pessoa@Exemplo.COM ").status_code == 200


@pytest.mark.parametrize(
    ("email", "senha"),
    [(EMAIL, "senha-errada-123"), ("outra@exemplo.com", SENHA)],
    ids=["senha-errada", "email-desconhecido"],
)
def test_login_com_credencial_errada_nao_diz_qual_errou(client, usuario, email, senha):
    resposta = _login(client, email=email, senha=senha)

    assert resposta.status_code == 401
    assert resposta.json() == {"detail": "E-mail ou senha incorretos."}
    assert resposta.headers["WWW-Authenticate"] == "Bearer"


def test_login_sem_senha_e_422(client, usuario):
    resposta = client.post("/auth/login", json={"email": EMAIL})

    assert resposta.status_code == 422
    assert resposta.json()["campos"] == [{"campo": "body.senha", "mensagem": "Campo obrigatório."}]


def test_login_com_senha_enorme_e_422_sem_chegar_no_argon2(client, usuario):
    resposta = client.post("/auth/login", json={"email": EMAIL, "senha": "x" * 1_000_000})

    assert resposta.status_code == 422
    assert resposta.json()["campos"] == [{"campo": "body.senha", "mensagem": "Texto longo demais."}]


def test_banco_guarda_so_o_hash_do_refresh_token_com_validade_de_30_dias(client, sessao, usuario):
    antes = datetime.now(UTC)
    refresh_token = _login(client).json()["refresh_token"]

    registro = _registro(sessao, refresh_token)
    assert registro.usuario_id == usuario.id
    assert registro.token_hash != refresh_token
    assert registro.revogado_em is None
    assert (
        antes + timedelta(days=30) <= registro.expira_em <= datetime.now(UTC) + timedelta(days=30)
    )


# --- refresh -----------------------------------------------------------------


def test_refresh_devolve_par_novo_e_revoga_o_usado(client, sessao, usuario):
    antigo = _login(client).json()["refresh_token"]

    resposta = _refresh(client, antigo)

    assert resposta.status_code == 200
    novo = resposta.json()
    assert novo["refresh_token"] != antigo
    assert _eu(client, novo["access_token"]).status_code == 200
    assert _registro(sessao, antigo).revogado_em is not None
    assert _registro(sessao, novo["refresh_token"]).revogado_em is None


def test_refresh_novo_pode_ser_usado_em_seguida(client, usuario):
    primeiro = _login(client).json()["refresh_token"]
    segundo = _refresh(client, primeiro).json()["refresh_token"]

    assert _refresh(client, segundo).status_code == 200


def test_reuso_de_refresh_revogado_derruba_todas_as_sessoes(client, sessao, usuario):
    roubado = _login(client).json()["refresh_token"]
    outra_sessao = _login(client).json()["refresh_token"]
    rotacionado = _refresh(client, roubado).json()["refresh_token"]

    resposta = _refresh(client, roubado)

    assert resposta.status_code == 401
    assert resposta.json() == {"detail": "Sessão expirada. Faça login de novo."}
    assert _refresh(client, rotacionado).status_code == 401
    assert _refresh(client, outra_sessao).status_code == 401
    # Depois de derrubar tudo, o login volta a funcionar.
    assert _login(client).status_code == 200


def test_refresh_expirado_e_recusado(client, sessao, usuario):
    refresh_token = _login(client).json()["refresh_token"]
    _registro(sessao, refresh_token).expira_em = datetime.now(UTC) - timedelta(seconds=1)
    sessao.flush()

    assert _refresh(client, refresh_token).status_code == 401


def test_refresh_desconhecido_e_recusado(client, usuario):
    resposta = _refresh(client, "token-que-nunca-foi-emitido")

    assert resposta.status_code == 401
    assert resposta.headers["WWW-Authenticate"] == "Bearer"


# --- rota protegida ----------------------------------------------------------


def test_rota_protegida_sem_cabecalho_e_401(client):
    resposta = client.get("/auth/eu")

    assert resposta.status_code == 401
    assert resposta.json() == {"detail": "Não autenticado."}
    assert resposta.headers["WWW-Authenticate"] == "Bearer"


def test_rota_protegida_recusa_refresh_token_no_lugar_do_access(client, usuario):
    refresh_token = _login(client).json()["refresh_token"]

    resposta = _eu(client, refresh_token)

    assert resposta.status_code == 401
    assert resposta.json() == {"detail": "Sessão inválida ou expirada."}


def test_rota_protegida_recusa_access_expirado(client, config, usuario):
    ha_uma_hora = datetime.now(UTC) - timedelta(hours=1)
    token = criar_access_token(
        usuario.id, config.jwt_secret.get_secret_value(), timedelta(minutes=15), ha_uma_hora
    )

    assert _eu(client, token).status_code == 401


def test_rota_protegida_recusa_token_de_usuario_que_nao_existe_mais(client, sessao, usuario):
    access_token = _login(client).json()["access_token"]
    sessao.delete(usuario)
    sessao.flush()

    assert _eu(client, access_token).status_code == 401


def test_openapi_declara_o_esquema_bearer(client):
    esquemas = client.get("/openapi.json").json()["components"]["securitySchemes"]

    assert esquemas == {"HTTPBearer": {"type": "http", "scheme": "bearer"}}
