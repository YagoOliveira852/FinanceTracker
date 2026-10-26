"""Rotas de regras de classificação. Só traduzem HTTP; as regras estão em `regras.py`."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.categorias import regras
from app.modulos.categorias.models import RegraClassificacao
from app.modulos.categorias.schemas import (
    ExemploRascunho,
    RascunhosCasadosSaida,
    RegraDetalheSaida,
    RegraEntrada,
    RegraSaida,
)

router = APIRouter(
    prefix="/regras",
    tags=["regras"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)

_NAO_ENCONTRADA = {status.HTTP_404_NOT_FOUND: {"model": RespostaErro}}


@router.get("")
def listar(sessao: SessaoDep) -> list[RegraSaida]:
    """Manuais primeiro, depois as aprendidas mais usadas."""
    return [RegraSaida.model_validate(regra) for regra in regras.listar_regras(sessao)]


@router.get("/{regra_id}", responses=_NAO_ENCONTRADA)
def obter(regra_id: uuid.UUID, sessao: SessaoDep) -> RegraDetalheSaida:
    """A regra e os rascunhos sem categoria que ela sugere agora."""
    return _detalhe(sessao, _obter(sessao, regra_id))


@router.post("", status_code=status.HTTP_201_CREATED)
def criar(dados: RegraEntrada, sessao: SessaoDep) -> RegraDetalheSaida:
    """Regra manual; a resposta diz quantos rascunhos ela sugere agora."""
    regra = regras.criar_regra(
        sessao, padrao=dados.padrao, categoria_id=dados.categoria_id, conta_id=dados.conta_id
    )
    return _detalhe(sessao, regra)


@router.put("/{regra_id}", responses=_NAO_ENCONTRADA)
def editar(regra_id: uuid.UUID, dados: RegraEntrada, sessao: SessaoDep) -> RegraDetalheSaida:
    """Edita a regra e a torna manual; a resposta diz quantos rascunhos ela
    sugere agora."""
    try:
        regra = regras.editar_regra(
            sessao,
            regra_id,
            padrao=dados.padrao,
            categoria_id=dados.categoria_id,
            conta_id=dados.conta_id,
        )
    except regras.RegraNaoEncontrada as exc:
        raise _nao_encontrada() from exc
    return _detalhe(sessao, regra)


@router.delete("/{regra_id}", status_code=status.HTTP_204_NO_CONTENT, responses=_NAO_ENCONTRADA)
def excluir(regra_id: uuid.UUID, sessao: SessaoDep) -> None:
    """Apaga a regra; as transações já classificadas não mudam."""
    try:
        regras.excluir_regra(sessao, regra_id)
    except regras.RegraNaoEncontrada as exc:
        raise _nao_encontrada() from exc


def _obter(sessao: Session, regra_id: uuid.UUID) -> RegraClassificacao:
    try:
        return regras.obter_regra(sessao, regra_id)
    except regras.RegraNaoEncontrada as exc:
        raise _nao_encontrada() from exc


def _nao_encontrada() -> HTTPException:
    return HTTPException(status.HTTP_404_NOT_FOUND, detail="Regra não encontrada.")


def _detalhe(sessao: Session, regra: RegraClassificacao) -> RegraDetalheSaida:
    casados = regras.rascunhos_casados(sessao, regra)
    exemplo = casados.exemplo
    return RegraDetalheSaida(
        **RegraSaida.model_validate(regra).model_dump(),
        rascunhos=RascunhosCasadosSaida(
            quantidade=casados.quantidade,
            exemplo=None
            if exemplo is None
            else ExemploRascunho(descricao=exemplo.descricao, data=exemplo.data),
        ),
    )
