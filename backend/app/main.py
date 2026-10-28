"""Ponto de entrada da API: cria a app e registra rotas e tratadores de erro."""

import logging

from fastapi import FastAPI, HTTPException, status
from fastapi.routing import APIRoute
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.core.deps import SessaoDep
from app.core.erros import RespostaErro, registrar_tratadores_de_erro
from app.modulos.auth.router import router as auth_router
from app.modulos.cartoes.faturas_router import router as faturas_router
from app.modulos.cartoes.router import router as cartoes_router
from app.modulos.categorias.regras_router import router as regras_router
from app.modulos.categorias.router import router as categorias_router
from app.modulos.contas.router import router as contas_router
from app.modulos.importacao.router import router as importacao_router
from app.modulos.revisao.router import router as revisao_router
from app.modulos.transacoes.router import router as transacoes_router

logger = logging.getLogger(__name__)


def operation_id(rota: APIRoute) -> str:
    """operationId `<tag>_<função>` (ex.: `contas_listar`), único no documento.

    O gerador do cliente Dart agrupa os métodos por tag e corta o prefixo até o
    primeiro `_` (`removeOperationIdPrefix`): `contas_listar` vira
    `ContasApi.listar()`. Por isso cada rota tem uma tag só, sem `_`.
    """
    if len(rota.tags) != 1:
        raise ValueError(f"Rota {rota.name!r} precisa de exatamente uma tag.")
    tag = str(rota.tags[0])
    if "_" in tag:
        raise ValueError(f"Tag {tag!r} não pode ter sublinhado.")
    return f"{tag}_{rota.name}"


app = FastAPI(title="Finanças pessoais", version="0.1.0", generate_unique_id_function=operation_id)
registrar_tratadores_de_erro(app)
app.include_router(auth_router)
app.include_router(contas_router)
app.include_router(transacoes_router)
app.include_router(cartoes_router)
app.include_router(faturas_router)
app.include_router(categorias_router)
app.include_router(regras_router)
app.include_router(revisao_router)
app.include_router(importacao_router)


class Saude(BaseModel):
    status: str


@app.get(
    "/saude",
    tags=["saude"],
    responses={status.HTTP_503_SERVICE_UNAVAILABLE: {"model": RespostaErro}},
)
def saude(sessao: SessaoDep) -> Saude:
    """Responde se a API está no ar e consegue falar com o banco."""
    try:
        sessao.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        logger.exception("Saúde: falha ao consultar o banco.")
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, detail="Banco de dados indisponível."
        ) from exc
    return Saude(status="ok")
