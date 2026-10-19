from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.core.db import get_sessao
from app.main import app


def test_saude_ok_com_banco_no_ar(client):
    resposta = client.get("/saude")

    assert resposta.status_code == 200
    assert resposta.json() == {"status": "ok"}


class _SessaoSemBanco:
    def execute(self, *_args, **_kwargs):
        raise OperationalError("SELECT 1", {}, Exception("conexão recusada"))


def test_saude_503_quando_o_banco_cai():
    app.dependency_overrides[get_sessao] = lambda: _SessaoSemBanco()
    try:
        resposta = TestClient(app).get("/saude")
    finally:
        app.dependency_overrides.clear()

    assert resposta.status_code == 503
    assert resposta.json() == {"detail": "Banco de dados indisponível."}
