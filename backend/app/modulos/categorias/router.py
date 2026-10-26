"""Rotas de categorias. Só traduzem HTTP; as regras estão no service."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.categorias import service
from app.modulos.categorias.schemas import CategoriaEdicao, CategoriaEntrada, CategoriaSaida

router = APIRouter(
    prefix="/categorias",
    tags=["categorias"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)


@router.get("")
def listar(sessao: SessaoDep) -> list[CategoriaSaida]:
    """Todas as categorias, ativas ou não, por grupo e nome."""
    return [_saida(resumo) for resumo in service.listar_categorias(sessao)]


@router.post("", status_code=status.HTTP_201_CREATED)
def criar(dados: CategoriaEntrada, sessao: SessaoDep) -> CategoriaSaida:
    categoria = service.criar_categoria(sessao, nome=dados.nome, grupo=dados.grupo)
    return _saida_por_id(sessao, categoria.id)


@router.put("/{categoria_id}", responses={status.HTTP_404_NOT_FOUND: {"model": RespostaErro}})
def editar(categoria_id: uuid.UUID, dados: CategoriaEdicao, sessao: SessaoDep) -> CategoriaSaida:
    """Renomeia, troca o grupo ou desativa/reativa. Desativada, sai das opções
    e as regras dela param de sugerir; as transações antigas continuam com ela."""
    try:
        service.editar_categoria(
            sessao, categoria_id, nome=dados.nome, grupo=dados.grupo, ativa=dados.ativa
        )
    except service.CategoriaNaoEncontrada as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Categoria não encontrada.") from exc
    return _saida_por_id(sessao, categoria_id)


def _saida_por_id(sessao: Session, categoria_id: uuid.UUID) -> CategoriaSaida:
    return _saida(service.resumo_categoria(sessao, categoria_id))


def _saida(resumo: service.ResumoCategoria) -> CategoriaSaida:
    return CategoriaSaida(
        id=resumo.categoria.id,
        nome=resumo.categoria.nome,
        grupo=resumo.categoria.grupo,
        ativa=resumo.categoria.ativa,
        qtd_regras=resumo.qtd_regras,
        qtd_transacoes=resumo.qtd_transacoes,
    )
