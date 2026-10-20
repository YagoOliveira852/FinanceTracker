"""Ponto de entrada da API: cria a app e registra rotas e tratadores de erro."""

import logging

from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.core.deps import SessaoDep
from app.core.erros import RespostaErro, registrar_tratadores_de_erro
from app.modulos.auth.router import router as auth_router

logger = logging.getLogger(__name__)

app = FastAPI(title="Finanças pessoais", version="0.1.0")
registrar_tratadores_de_erro(app)
app.include_router(auth_router)


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
