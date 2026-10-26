"""Regras de classificação: cadastro, a sugestão de um rascunho e o
aprendizado na confirmação da categoria (spec `2026-10-19-revisao-classificacao`)."""

import uuid
from dataclasses import dataclass

from sqlalchemy import case, select
from sqlalchemy.orm import Session

from app.core.erros import CampoInvalido
from app.modulos.categorias.classificacao import (
    escolher_regra,
    grupos_do_tipo,
    natureza,
    normalizar,
)
from app.modulos.categorias.models import (
    Categoria,
    GrupoCategoria,
    OrigemRegra,
    RegraClassificacao,
)
from app.modulos.transacoes import service as transacoes_service
from app.modulos.transacoes.models import StatusTransacao, TipoTransacao, Transacao

# Tipos de transação que têm categoria (e, portanto, sugestão).
_TIPOS_COM_CATEGORIA = [tipo.value for tipo in TipoTransacao if grupos_do_tipo(tipo)]


class RegraNaoEncontrada(Exception):
    pass


@dataclass
class RascunhosCasados:
    quantidade: int
    exemplo: Transacao | None


def listar_regras(sessao: Session) -> list[RegraClassificacao]:
    """Manuais primeiro; depois as mais usadas; por fim pelo padrão."""
    manual_antes = case((RegraClassificacao.origem == OrigemRegra.manual.value, 0), else_=1)
    consulta = select(RegraClassificacao).order_by(
        manual_antes, RegraClassificacao.vezes_aplicada.desc(), RegraClassificacao.padrao
    )
    return list(sessao.scalars(consulta))


def obter_regra(sessao: Session, regra_id: uuid.UUID) -> RegraClassificacao:
    regra = sessao.get(RegraClassificacao, regra_id)
    if regra is None:
        raise RegraNaoEncontrada
    return regra


def criar_regra(
    sessao: Session, *, padrao: str, categoria_id: uuid.UUID, conta_id: uuid.UUID | None
) -> RegraClassificacao:
    """Regra manual. O padrão é normalizado como a descrição dos rascunhos."""
    categoria = _categoria_ativa(sessao, categoria_id)
    if conta_id is not None:
        transacoes_service.conta_ativa(sessao, conta_id)
    padrao = _padrao(padrao)
    _recusar_repetida(sessao, padrao, conta_id, categoria)
    regra = RegraClassificacao(
        padrao=padrao, categoria_id=categoria.id, conta_id=conta_id, origem=OrigemRegra.manual
    )
    sessao.add(regra)
    sessao.commit()
    return regra


def editar_regra(
    sessao: Session,
    regra_id: uuid.UUID,
    *,
    padrao: str,
    categoria_id: uuid.UUID,
    conta_id: uuid.UUID | None,
) -> RegraClassificacao:
    """Muda padrão, categoria ou conta. Salvar torna a regra manual: a partir
    daí, a revisão não a muda mais. Categoria e conta só precisam estar ativas
    se mudaram (uma regra antiga continua editável)."""
    regra = obter_regra(sessao, regra_id)
    if categoria_id == regra.categoria_id:
        categoria = regra.categoria
    else:
        categoria = _categoria_ativa(sessao, categoria_id)
    if conta_id is not None and conta_id != regra.conta_id:
        transacoes_service.conta_ativa(sessao, conta_id)
    padrao = _padrao(padrao)
    _recusar_repetida(sessao, padrao, conta_id, categoria, ignorar=regra.id)
    regra.padrao = padrao
    regra.categoria = categoria
    regra.conta_id = conta_id
    regra.origem = OrigemRegra.manual
    sessao.commit()
    sessao.refresh(regra)
    return regra


def excluir_regra(sessao: Session, regra_id: uuid.UUID) -> None:
    """Apaga a regra (não é dado financeiro); as transações já classificadas
    não mudam."""
    sessao.delete(obter_regra(sessao, regra_id))
    sessao.commit()


def regra_sugerida(sessao: Session, transacao: Transacao) -> RegraClassificacao | None:
    """A regra que sugere a categoria da transação, ou `None`."""
    return _sugerida(transacao, _regras_ativas(sessao))


def rascunhos_casados(sessao: Session, regra: RegraClassificacao) -> RascunhosCasados:
    """Rascunhos sem categoria para os quais a regra é a sugestão hoje (ela
    casa e vence as outras), e o mais recente deles."""
    regras = _regras_ativas(sessao)
    rascunhos = sessao.scalars(
        select(Transacao)
        .where(
            Transacao.status == StatusTransacao.rascunho.value,
            Transacao.categoria_id.is_(None),
            Transacao.tipo.in_(_TIPOS_COM_CATEGORIA),
        )
        .order_by(Transacao.data.desc(), Transacao.criado_em.desc(), Transacao.id)
    )
    casados = [t for t in rascunhos if _sugerida(t, regras) is regra]
    return RascunhosCasados(quantidade=len(casados), exemplo=casados[0] if casados else None)


def _sugerida(transacao: Transacao, regras: list[RegraClassificacao]) -> RegraClassificacao | None:
    grupos = grupos_do_tipo(TipoTransacao(transacao.tipo))
    compativeis = [r for r in regras if r.categoria.grupo in grupos]
    return escolher_regra(normalizar(transacao.descricao_original), transacao.conta_id, compativeis)


def _regras_ativas(sessao: Session) -> list[RegraClassificacao]:
    """As regras que podem sugerir: as de categoria ativa."""
    return list(
        sessao.scalars(
            select(RegraClassificacao)
            .join(RegraClassificacao.categoria)
            .where(Categoria.ativa.is_(True))
        )
    )


def _padrao(padrao: str) -> str:
    normalizado = normalizar(padrao)
    if not normalizado:
        raise CampoInvalido(
            "padrao", "O padrão ficou vazio: use o nome do estabelecimento ou da pessoa."
        )
    return normalizado


def _categoria_ativa(sessao: Session, categoria_id: uuid.UUID) -> Categoria:
    categoria = sessao.get(Categoria, categoria_id)
    if categoria is None:
        raise CampoInvalido("categoria_id", "Categoria não encontrada.")
    if not categoria.ativa:
        raise CampoInvalido("categoria_id", "Esta categoria está desativada.")
    return categoria


def _repetida(
    sessao: Session,
    padrao: str,
    conta_id: uuid.UUID | None,
    categoria: Categoria,
    ignorar: uuid.UUID | None = None,
) -> RegraClassificacao | None:
    """Regra com o mesmo padrão, a mesma conta (ou as duas gerais) e categoria
    da mesma natureza. Natureza diferente não conta: "fulano" pode ser renda
    numa regra e gasto em outra."""
    consulta = select(RegraClassificacao).where(
        RegraClassificacao.padrao == padrao,
        RegraClassificacao.conta_id.is_not_distinct_from(conta_id),
    )
    if ignorar is not None:
        consulta = consulta.where(RegraClassificacao.id != ignorar)
    alvo = natureza(GrupoCategoria(categoria.grupo))
    return next(
        (
            r
            for r in sessao.scalars(consulta)
            if natureza(GrupoCategoria(r.categoria.grupo)) == alvo
        ),
        None,
    )


def _recusar_repetida(
    sessao: Session,
    padrao: str,
    conta_id: uuid.UUID | None,
    categoria: Categoria,
    ignorar: uuid.UUID | None = None,
) -> None:
    if _repetida(sessao, padrao, conta_id, categoria, ignorar) is not None:
        raise CampoInvalido("padrao", "Já existe uma regra com esse padrão.")
