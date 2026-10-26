"""Regras de categorias: cadastro, edição e a categoria que uma transação aceita."""

import uuid
from dataclasses import dataclass

from sqlalchemy import case, exists, func, select
from sqlalchemy.orm import Session

from app.core.erros import CampoInvalido
from app.modulos.categorias.classificacao import grupos_do_tipo, natureza
from app.modulos.categorias.models import Categoria, GrupoCategoria, RegraClassificacao
from app.modulos.transacoes.models import TipoTransacao, Transacao

# Mensagem de quando a categoria não combina com o tipo da transação.
_GRUPO_ESPERADO = {
    "gasto": "Escolha uma categoria de gasto (essencial ou variável).",
    GrupoCategoria.renda: "Escolha uma categoria de renda.",
    GrupoCategoria.investimento: "Escolha uma categoria de investimento.",
}


class CategoriaNaoEncontrada(Exception):
    pass


@dataclass
class ResumoCategoria:
    categoria: Categoria
    qtd_regras: int
    qtd_transacoes: int


def listar_categorias(sessao: Session) -> list[ResumoCategoria]:
    """Todas, ativas ou não, por grupo (na ordem do enum) e nome."""
    ordem_do_grupo = case({g.value: i for i, g in enumerate(GrupoCategoria)}, value=Categoria.grupo)
    linhas = sessao.execute(_com_contagens().order_by(ordem_do_grupo, Categoria.nome)).all()
    return [ResumoCategoria(*linha) for linha in linhas]


def resumo_categoria(sessao: Session, categoria_id: uuid.UUID) -> ResumoCategoria:
    linha = sessao.execute(_com_contagens().where(Categoria.id == categoria_id)).one_or_none()
    if linha is None:
        raise CategoriaNaoEncontrada
    return ResumoCategoria(*linha)


def criar_categoria(sessao: Session, *, nome: str, grupo: GrupoCategoria) -> Categoria:
    _recusar_nome_repetido(sessao, nome)
    categoria = Categoria(nome=nome, grupo=grupo)
    sessao.add(categoria)
    sessao.commit()
    return categoria


def editar_categoria(
    sessao: Session, categoria_id: uuid.UUID, *, nome: str, grupo: GrupoCategoria, ativa: bool
) -> Categoria:
    """Renomeia, troca o grupo ou desativa/reativa.

    Entre essencial e variável a troca é livre (os dois são gasto). Para outra
    natureza, só sem transações: senão uma despesa ficaria com categoria de renda.
    """
    categoria = sessao.get(Categoria, categoria_id)
    if categoria is None:
        raise CategoriaNaoEncontrada
    _recusar_nome_repetido(sessao, nome, ignorar=categoria_id)
    if natureza(grupo) != natureza(GrupoCategoria(categoria.grupo)) and sessao.scalar(
        select(exists().where(Transacao.categoria_id == categoria_id))
    ):
        raise CampoInvalido(
            "grupo",
            "Esta categoria já tem transações; troque o grupo só entre essencial e variável.",
        )
    categoria.nome = nome
    categoria.grupo = grupo
    categoria.ativa = ativa
    sessao.commit()
    return categoria


def categoria_para_tipo(
    sessao: Session, categoria_id: uuid.UUID, tipo: TipoTransacao, campo: str = "categoria_id"
) -> Categoria:
    """A categoria, se existe, está ativa e combina com o tipo da transação;
    senão, recusa no `campo` do corpo."""
    grupos = grupos_do_tipo(tipo)
    if not grupos:
        raise CampoInvalido(campo, "Este tipo de transação não tem categoria.")
    categoria = sessao.get(Categoria, categoria_id)
    if categoria is None:
        raise CampoInvalido(campo, "Categoria não encontrada.")
    if not categoria.ativa:
        raise CampoInvalido(campo, "Esta categoria está desativada.")
    if categoria.grupo not in grupos:
        raise CampoInvalido(campo, _GRUPO_ESPERADO[natureza(next(iter(grupos)))])
    return categoria


def _recusar_nome_repetido(sessao: Session, nome: str, ignorar: uuid.UUID | None = None) -> None:
    consulta = select(Categoria.id).where(func.lower(Categoria.nome) == nome.lower())
    if ignorar is not None:
        consulta = consulta.where(Categoria.id != ignorar)
    if sessao.scalar(consulta) is not None:
        raise CampoInvalido("nome", "Já existe uma categoria com esse nome.")


def _com_contagens():
    """SELECT de (Categoria, qtd_regras, qtd_transacoes), numa consulta só."""
    regras = (
        select(func.count())
        .where(RegraClassificacao.categoria_id == Categoria.id)
        .scalar_subquery()
    )
    transacoes = (
        select(func.count()).where(Transacao.categoria_id == Categoria.id).scalar_subquery()
    )
    return select(Categoria, regras.label("qtd_regras"), transacoes.label("qtd_transacoes"))
