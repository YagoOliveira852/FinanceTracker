"""operationIds do OpenAPI: viram os nomes dos métodos do cliente Dart gerado."""

import pytest
from fastapi import FastAPI
from fastapi.routing import APIRoute

from app.main import app, operation_id

METODOS_HTTP = {"get", "post", "put", "patch", "delete"}


def _operation_ids() -> dict[str, str]:
    """`"GET /contas"` → operationId, para toda rota do documento."""
    return {
        f"{metodo.upper()} {caminho}": operacao["operationId"]
        for caminho, metodos in app.openapi()["paths"].items()
        for metodo, operacao in metodos.items()
        if metodo in METODOS_HTTP
    }


def test_operation_id_e_tag_mais_nome_da_funcao():
    # O gerador corta o prefixo até o primeiro "_": contas_listar vira ContasApi.listar().
    ids = _operation_ids()

    assert ids["GET /contas"] == "contas_listar"
    assert ids["POST /auth/login"] == "auth_login"
    assert ids["GET /transacoes/{transacao_id}"] == "transacoes_obter"


def test_toda_rota_publica_tag_mais_nome_da_funcao():
    rotas = [rota for rota in app.routes if isinstance(rota, APIRoute) and rota.include_in_schema]
    publicados = set(_operation_ids().values())

    assert rotas
    for rota in rotas:
        assert rota.unique_id == f"{rota.tags[0]}_{rota.name}"
        assert rota.unique_id in publicados


def test_operation_ids_sao_unicos_no_documento():
    ids = list(_operation_ids().values())

    assert len(ids) == len(set(ids))


def _api_com_rota(tags: list[str]) -> None:
    api = FastAPI(generate_unique_id_function=operation_id)

    @api.get("/exemplo", tags=tags)
    def exemplo() -> None: ...


@pytest.mark.parametrize("tags", [[], ["contas", "transacoes"]])
def test_recusa_rota_sem_exatamente_uma_tag(tags):
    with pytest.raises(ValueError, match="uma tag"):
        _api_com_rota(tags)


def test_recusa_tag_com_sublinhado():
    # O "_" da tag seria confundido com o separador que o gerador corta.
    with pytest.raises(ValueError, match="sublinhado"):
        _api_com_rota(["open_finance"])
