from typing import Annotated

import pytest
from fastapi import FastAPI, HTTPException, Query
from fastapi.testclient import TestClient
from pydantic import BaseModel

from app.core.dinheiro import Dinheiro
from app.core.erros import registrar_tratadores_de_erro


class Entrada(BaseModel):
    descricao: str
    valor: Dinheiro


@pytest.fixture
def client() -> TestClient:
    api = FastAPI()
    registrar_tratadores_de_erro(api)

    @api.get("/conflito")
    def conflito():
        raise HTTPException(409, detail="Fatura já está paga.")

    @api.get("/teapot")
    def status_fora_do_padrao():
        raise HTTPException(599)

    @api.post("/entrada")
    def criar(entrada: Entrada) -> Entrada:
        return entrada

    @api.get("/limite")
    def limite(limite: Annotated[int, Query(le=100)]) -> int:
        return limite

    @api.get("/quebra")
    def quebra():
        raise RuntimeError("detalhe interno que não pode vazar")

    # Sem relançar no teste: queremos ver a resposta que o cliente receberia.
    return TestClient(api, raise_server_exceptions=False)


def test_http_exception_mantem_mensagem_da_rota(client):
    resposta = client.get("/conflito")

    assert resposta.status_code == 409
    assert resposta.json() == {"detail": "Fatura já está paga."}


def test_rota_inexistente_responde_em_portugues(client):
    resposta = client.get("/nao-existe")

    assert resposta.status_code == 404
    assert resposta.json() == {"detail": "Recurso não encontrado."}


def test_metodo_nao_permitido_responde_em_portugues(client):
    resposta = client.delete("/conflito")

    assert resposta.status_code == 405
    assert resposta.json() == {"detail": "Método não permitido."}


def test_status_fora_do_padrao_nao_quebra_o_tratador(client):
    resposta = client.get("/teapot")

    assert resposta.status_code == 599
    assert "detail" in resposta.json()


def test_validacao_lista_os_campos_invalidos(client):
    resposta = client.post("/entrada", json={"valor": 12.5})

    assert resposta.status_code == 422
    corpo = resposta.json()
    assert corpo["detail"] == "Dados inválidos."
    campos = {erro["campo"]: erro["mensagem"] for erro in corpo["campos"]}
    assert campos["body.descricao"] == "Campo obrigatório."
    assert campos["body.valor"].startswith("Valor monetário deve ser uma string")


def test_erro_de_validacao_sem_traducao_mantem_a_mensagem_original(client):
    resposta = client.get("/limite", params={"limite": 500})

    assert resposta.status_code == 422
    assert resposta.json()["campos"] == [
        {"campo": "query.limite", "mensagem": "Input should be less than or equal to 100"}
    ]


def test_json_malformado_vira_422_no_mesmo_formato(client):
    resposta = client.post(
        "/entrada", content="{nao e json", headers={"Content-Type": "application/json"}
    )

    assert resposta.status_code == 422
    assert resposta.json()["detail"] == "Dados inválidos."
    assert resposta.json()["campos"][0]["mensagem"] == "JSON inválido."


def test_erro_inesperado_vira_500_sem_vazar_detalhes(client):
    resposta = client.get("/quebra")

    assert resposta.status_code == 500
    assert resposta.json() == {"detail": "Erro interno do servidor."}
