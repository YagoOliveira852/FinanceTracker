"""Formato único de erro da API.

Toda resposta de erro tem `detail` (texto em pt-BR). Erro de validação (422)
acrescenta `campos`, com o caminho e a mensagem de cada campo inválido:

    {"detail": "Dados inválidos.", "campos": [{"campo": "body.valor", "mensagem": "..."}]}

Nas rotas, use `HTTPException(status_code, detail="mensagem em pt-BR")`.
"""

from collections.abc import Mapping
from http import HTTPStatus

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException


class ErroCampo(BaseModel):
    campo: str
    mensagem: str


class RespostaErro(BaseModel):
    detail: str
    campos: list[ErroCampo] | None = None


# Mensagens padrão do Starlette (ex.: "Not Found" de rota inexistente) em pt-BR.
MENSAGENS_PADRAO = {
    HTTPStatus.BAD_REQUEST: "Requisição inválida.",
    HTTPStatus.UNAUTHORIZED: "Não autenticado.",
    HTTPStatus.FORBIDDEN: "Acesso negado.",
    HTTPStatus.NOT_FOUND: "Recurso não encontrado.",
    HTTPStatus.METHOD_NOT_ALLOWED: "Método não permitido.",
}

# Erros de validação mais comuns do Pydantic em pt-BR; os demais mantêm a
# mensagem original. Tipos próprios (ex.: Dinheiro) já validam em pt-BR.
MENSAGENS_VALIDACAO = {
    "missing": "Campo obrigatório.",
    "extra_forbidden": "Campo não permitido.",
    "json_invalid": "JSON inválido.",
    "string_type": "Deve ser um texto.",
    "int_type": "Deve ser um número inteiro.",
    "int_parsing": "Deve ser um número inteiro.",
    "bool_type": "Deve ser verdadeiro ou falso.",
    "bool_parsing": "Deve ser verdadeiro ou falso.",
    "date_type": "Deve ser uma data no formato AAAA-MM-DD.",
    "date_from_datetime_parsing": "Deve ser uma data no formato AAAA-MM-DD.",
    "uuid_type": "Deve ser um UUID.",
    "uuid_parsing": "Deve ser um UUID.",
}

MENSAGEM_ERRO_INTERNO = "Erro interno do servidor."
MENSAGEM_DADOS_INVALIDOS = "Dados inválidos."


def _resposta(
    status_code: int, corpo: RespostaErro, headers: Mapping[str, str] | None = None
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=corpo.model_dump(exclude_none=True),
        headers=headers,
    )


def _traduzir_detail(status_code: int, detail: str) -> str:
    """Troca a frase padrão em inglês do status pela versão em pt-BR, se houver."""
    try:
        status = HTTPStatus(status_code)
    except ValueError:
        return detail
    if detail == status.phrase:
        return MENSAGENS_PADRAO.get(status, detail)
    return detail


def _tratar_http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
    detail = _traduzir_detail(exc.status_code, str(exc.detail))
    return _resposta(exc.status_code, RespostaErro(detail=detail), exc.headers)


def _tratar_validacao(_: Request, exc: RequestValidationError) -> JSONResponse:
    campos = [
        ErroCampo(
            campo=".".join(str(parte) for parte in erro["loc"]),
            mensagem=MENSAGENS_VALIDACAO.get(erro["type"], erro["msg"]),
        )
        for erro in exc.errors()
    ]
    return _resposta(
        HTTPStatus.UNPROCESSABLE_ENTITY,
        RespostaErro(detail=MENSAGEM_DADOS_INVALIDOS, campos=campos),
    )


def _tratar_erro_interno(_: Request, __: Exception) -> JSONResponse:
    # O Starlette registra o traceback e relança a exceção depois desta resposta.
    return _resposta(HTTPStatus.INTERNAL_SERVER_ERROR, RespostaErro(detail=MENSAGEM_ERRO_INTERNO))


def registrar_tratadores_de_erro(app: FastAPI) -> None:
    app.add_exception_handler(StarletteHTTPException, _tratar_http)
    app.add_exception_handler(RequestValidationError, _tratar_validacao)
    app.add_exception_handler(Exception, _tratar_erro_interno)
