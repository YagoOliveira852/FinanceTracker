import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.seguranca import (
    ALGORITMO_JWT,
    TokenInvalido,
    criar_access_token,
    gerar_refresh_token,
    hash_refresh_token,
    hash_senha,
    ler_access_token,
    verificar_senha,
)

SEGREDO = "segredo-ficticio-de-teste-com-32-caracteres-ou-mais"
VALIDADE = timedelta(minutes=15)


def test_hash_de_senha_confere_so_com_a_senha_certa():
    senha_hash = hash_senha("senha-ficticia-123")

    assert senha_hash.startswith("$argon2")
    assert "senha-ficticia-123" not in senha_hash
    assert verificar_senha("senha-ficticia-123", senha_hash)
    assert not verificar_senha("outra-senha", senha_hash)


def test_mesma_senha_gera_hashes_diferentes():
    # O sal aleatório impede comparar hashes para descobrir senhas iguais.
    assert hash_senha("senha-ficticia-123") != hash_senha("senha-ficticia-123")


def test_verificar_sem_hash_devolve_falso():
    assert not verificar_senha("qualquer", None)


def test_verificar_com_hash_corrompido_devolve_falso():
    assert not verificar_senha("qualquer", "nao-e-um-hash-argon2")


def test_access_token_devolve_o_id_do_usuario():
    usuario_id = uuid.uuid4()
    token = criar_access_token(usuario_id, SEGREDO, VALIDADE, datetime.now(UTC))

    assert ler_access_token(token, SEGREDO) == usuario_id


def test_access_token_expirado_e_recusado():
    ha_uma_hora = datetime.now(UTC) - timedelta(hours=1)
    token = criar_access_token(uuid.uuid4(), SEGREDO, VALIDADE, ha_uma_hora)

    with pytest.raises(TokenInvalido):
        ler_access_token(token, SEGREDO)


def test_access_token_com_outro_segredo_e_recusado():
    token = criar_access_token(uuid.uuid4(), SEGREDO, VALIDADE, datetime.now(UTC))

    with pytest.raises(TokenInvalido):
        ler_access_token(token, "outro-segredo-ficticio-com-32-caracteres-ou-mais")


@pytest.mark.parametrize(
    "payload",
    [
        {"sub": str(uuid.uuid4()), "tipo": "refresh"},
        {"sub": "nao-e-uuid", "tipo": "access"},
        {"tipo": "access"},
    ],
    ids=["tipo-errado", "sub-malformado", "sem-sub"],
)
def test_access_token_com_payload_invalido_e_recusado(payload):
    agora = datetime.now(UTC)
    token = jwt.encode(
        {**payload, "iat": agora, "exp": agora + VALIDADE}, SEGREDO, algorithm=ALGORITMO_JWT
    )

    with pytest.raises(TokenInvalido):
        ler_access_token(token, SEGREDO)


def test_access_token_sem_assinatura_e_recusado():
    agora = datetime.now(UTC)
    token = jwt.encode(
        {"sub": str(uuid.uuid4()), "tipo": "access", "iat": agora, "exp": agora + VALIDADE},
        key=None,
        algorithm="none",
    )

    with pytest.raises(TokenInvalido):
        ler_access_token(token, SEGREDO)


def test_texto_qualquer_nao_e_access_token():
    with pytest.raises(TokenInvalido):
        ler_access_token("isto-nao-e-um-jwt", SEGREDO)


def test_refresh_token_e_aleatorio_e_o_hash_e_deterministico():
    token = gerar_refresh_token()

    assert len(token) >= 43  # 32 bytes em base64url
    assert token != gerar_refresh_token()
    assert hash_refresh_token(token) == hash_refresh_token(token)
    assert token not in hash_refresh_token(token)
