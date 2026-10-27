"""Regras de classificação: cadastro, a sugestão de um rascunho e o
aprendizado na confirmação da categoria (spec `2026-10-19-revisao-classificacao`)."""

import uuid
from dataclasses import dataclass
from enum import StrEnum

from sqlalchemy import case, select
from sqlalchemy.orm import Session

from app.core.erros import CampoInvalido
from app.modulos.categorias import service as categorias_service
from app.modulos.categorias.classificacao import (
    RegraCandidata,
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


class NaoEhRascunho(Exception):
    """Só rascunho tem a categoria confirmada (e ensina regras)."""


class EfeitoAprendizado(StrEnum):
    """O que a confirmação de uma categoria fez com as regras."""

    criada = "criada"  # nenhuma regra sugeria: nasceu uma aprendida
    reforcada = "reforcada"  # a sugestão foi confirmada como veio
    corrigida = "corrigida"  # aprendida com o mesmo padrão: trocou a categoria
    especializada = "especializada"  # aprendida mais curta: nasceu uma mais longa
    manual_mantida = "manual_mantida"  # regra manual não muda na revisão
    nenhuma = "nenhuma"  # a descrição só tinha termos genéricos


@dataclass
class Aprendizado:
    efeito: EfeitoAprendizado
    regra: RegraClassificacao | None


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


def sugestoes(
    sessao: Session, transacoes: list[Transacao]
) -> dict[uuid.UUID, RegraClassificacao | None]:
    """{transacao_id: regra sugerida}, carregando as regras uma vez só (a
    revisão calcula a sugestão de todos os rascunhos na leitura)."""
    regras = _regras_ativas(sessao)
    return {transacao.id: _sugerida(transacao, regras) for transacao in transacoes}


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


def confirmar_categoria(
    sessao: Session, transacao_id: uuid.UUID, categoria_id: uuid.UUID
) -> Aprendizado:
    """Confirma o rascunho com a categoria escolhida e ensina as regras.

    Usado pela revisão. A categoria precisa estar ativa e combinar com o tipo.
    """
    transacao = transacoes_service.obter(sessao, transacao_id)
    if transacao.status != StatusTransacao.rascunho:
        raise NaoEhRascunho
    categoria = categorias_service.categoria_para_tipo(
        sessao, categoria_id, TipoTransacao(transacao.tipo)
    )
    aprendizado = aprender(sessao, transacao, categoria)
    transacao.categoria = categoria
    transacao.status = StatusTransacao.confirmada
    sessao.commit()
    return aprendizado


def aprender(sessao: Session, transacao: Transacao, categoria: Categoria) -> Aprendizado:
    """Ajusta as regras pela categoria escolhida para a transação, sem commit
    (a revisão pode juntar isto a outras mudanças).

    1. Nenhuma regra sugeria → nasce uma aprendida com o padrão da transação.
    2. A sugestão foi confirmada como veio → `vezes_aplicada` + 1.
    3. Correção de aprendida: com o mesmo padrão, a categoria é trocada e a
       contagem zera; mais curta, ela fica e nasce uma aprendida mais longa,
       que passa a vencer.
    4. Correção de manual → a regra não muda.
    5. Padrão vazio → nada.
    """
    sugerida = regra_sugerida(sessao, transacao)
    padrao = normalizar(transacao.descricao_original)
    mesma_categoria = sugerida is not None and sugerida.categoria_id == categoria.id
    efeito = prever_efeito(sugerida, padrao, mesma_categoria)
    if efeito == EfeitoAprendizado.reforcada:
        sugerida.vezes_aplicada += 1
    if efeito in (EfeitoAprendizado.reforcada, EfeitoAprendizado.manual_mantida):
        return Aprendizado(efeito, sugerida)
    if efeito == EfeitoAprendizado.nenhuma:
        return Aprendizado(efeito, None)

    # Uma aprendida com o mesmo padrão pode existir sem ter sugerido (a
    # categoria dela foi desativada): é reaproveitada, para o padrão não se
    # repetir. Uma manual nessa situação fica como está.
    regra = _repetida(sessao, padrao, None, categoria)
    if regra is None or regra.origem == OrigemRegra.manual:
        regra = RegraClassificacao(padrao=padrao, origem=OrigemRegra.aprendida, vezes_aplicada=0)
        sessao.add(regra)
    regra.categoria = categoria
    regra.vezes_aplicada = 0
    return Aprendizado(efeito, regra)


def prever_efeito(
    sugerida: RegraCandidata | None, padrao: str, mesma_categoria: bool
) -> EfeitoAprendizado:
    """O que `aprender` fará com as regras, sem mudar nada: depende só da regra
    sugerida, do padrão da transação e de a categoria escolhida ser a da
    sugestão. A revisão mostra os dois efeitos possíveis antes de confirmar."""
    if sugerida is not None and mesma_categoria:
        return EfeitoAprendizado.reforcada
    if sugerida is not None and sugerida.origem == OrigemRegra.manual:
        return EfeitoAprendizado.manual_mantida
    if not padrao:
        return EfeitoAprendizado.nenhuma
    if sugerida is None:
        return EfeitoAprendizado.criada
    if sugerida.padrao == padrao:
        return EfeitoAprendizado.corrigida
    return EfeitoAprendizado.especializada


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
