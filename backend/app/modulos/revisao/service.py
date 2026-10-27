"""Regras da revisão: a lista do que espera o usuário e as ações sobre os
rascunhos (spec `2026-10-19-revisao-classificacao`, "Decisões do design da
revisão" e "Decisões do código da revisão")."""

from dataclasses import dataclass, field

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.modulos.categorias import regras
from app.modulos.categorias.classificacao import grupos_do_tipo, normalizar
from app.modulos.categorias.models import RegraClassificacao
from app.modulos.categorias.regras import EfeitoAprendizado, prever_efeito
from app.modulos.contas.models import TipoConta
from app.modulos.revisao.models import ParRecusado
from app.modulos.revisao.pareamento import sugerir_pares
from app.modulos.transacoes.models import StatusTransacao, TipoTransacao, Transacao

# Das fontes, um Pix entre contas próprias chega como despesa e receita (ou já
# como transferência, se a fonte souber).
_SAIDAS_DE_PAR = frozenset({TipoTransacao.despesa, TipoTransacao.transferencia_saida})
_ENTRADAS_DE_PAR = frozenset({TipoTransacao.receita, TipoTransacao.transferencia_entrada})
_CONTAS_DE_TRANSFERENCIA = frozenset({TipoConta.corrente, TipoConta.carteira})


@dataclass(frozen=True)
class Rascunho:
    """Rascunho comum, com a sugestão de categoria calculada agora."""

    transacao: Transacao
    padrao: str
    sugerida: RegraClassificacao | None
    # Efeito nas regras se o usuário confirmar a sugestão (ou, sem sugestão,
    # escolher qualquer categoria) e se escolher outra categoria.
    efeito_confirmando: EfeitoAprendizado
    efeito_corrigindo: EfeitoAprendizado


@dataclass(frozen=True)
class ParSugerido:
    saida: Transacao
    entrada: Transacao

    @property
    def dias(self) -> int:
        return abs((self.entrada.data - self.saida.data).days)


@dataclass(frozen=True)
class Duplicata:
    rascunho: Transacao
    outra: Transacao


@dataclass(frozen=True)
class Revisao:
    pares: list[ParSugerido] = field(default_factory=list)
    pagamentos: list[Transacao] = field(default_factory=list)
    duplicatas: list[Duplicata] = field(default_factory=list)
    sumidas: list[Transacao] = field(default_factory=list)
    rascunhos: list[Rascunho] = field(default_factory=list)

    @property
    def total(self) -> int:
        """O contador da aba: cada linha da lista, e um par é uma linha."""
        decisoes = len(self.pares) + len(self.pagamentos) + len(self.duplicatas)
        return decisoes + len(self.sumidas) + len(self.rascunhos)

    @property
    def qtd_sugeridos(self) -> int:
        return sum(rascunho.sugerida is not None for rascunho in self.rascunhos)


def listar(sessao: Session) -> Revisao:
    """O que espera o usuário. Cada rascunho aparece uma vez, na primeira
    situação que vale: duplicata pendente > lado de um par sugerido >
    pagamento de fatura > rascunho comum. A confirmada que sumiu da origem
    também é uma decisão. Tudo da data mais recente para a mais antiga."""
    rascunhos = _transacoes(sessao, Transacao.status == StatusTransacao.rascunho.value)

    duplicatas = _duplicatas(sessao, rascunhos)
    em_duplicata = {d.rascunho.id for d in duplicatas} | {d.outra.id for d in duplicatas}
    restantes = [t for t in rascunhos if t.id not in em_duplicata]

    pares = _pares(sessao, restantes)
    em_par = {p.saida.id for p in pares} | {p.entrada.id for p in pares}
    restantes = [t for t in restantes if t.id not in em_par]

    pagamentos = [t for t in restantes if t.tipo == TipoTransacao.pagamento_fatura]
    comuns = [t for t in restantes if t.tipo != TipoTransacao.pagamento_fatura]

    sumidas = _transacoes(
        sessao,
        Transacao.status == StatusTransacao.confirmada.value,
        Transacao.removida_na_origem_em.is_not(None),
    )
    return Revisao(
        pares=pares,
        pagamentos=pagamentos,
        duplicatas=duplicatas,
        sumidas=sumidas,
        rascunhos=_com_sugestao(sessao, comuns),
    )


def _transacoes(sessao: Session, *condicoes) -> list[Transacao]:
    return list(
        sessao.scalars(
            select(Transacao)
            .where(*condicoes)
            .options(selectinload(Transacao.conta), selectinload(Transacao.fatura))
            .order_by(Transacao.data.desc(), Transacao.criado_em.desc(), Transacao.id)
        )
    )


def _duplicatas(sessao: Session, rascunhos: list[Transacao]) -> list[Duplicata]:
    """Rascunhos marcados como possível duplicata de uma transação que ainda
    conta (a outra ignorada não é mais dúvida)."""
    ids = {t.possivel_duplicata_de for t in rascunhos if t.possivel_duplicata_de is not None}
    if not ids:
        return []
    outras = {
        t.id: t
        for t in _transacoes(
            sessao, Transacao.id.in_(ids), Transacao.status != StatusTransacao.ignorada.value
        )
    }
    return [
        Duplicata(rascunho=t, outra=outras[t.possivel_duplicata_de])
        for t in rascunhos
        if t.possivel_duplicata_de in outras
    ]


def _pares(sessao: Session, rascunhos: list[Transacao]) -> list[ParSugerido]:
    podem = [
        t
        for t in rascunhos
        if t.transferencia_par_id is None and t.conta.tipo in _CONTAS_DE_TRANSFERENCIA
    ]
    recusados = {
        (saida_id, entrada_id)
        for saida_id, entrada_id in sessao.execute(
            select(ParRecusado.saida_id, ParRecusado.entrada_id)
        )
    }
    pares = sugerir_pares(
        [t for t in podem if t.tipo in _SAIDAS_DE_PAR],
        [t for t in podem if t.tipo in _ENTRADAS_DE_PAR],
        recusados,
    )
    return [ParSugerido(saida, entrada) for saida, entrada in reversed(pares)]


def _com_sugestao(sessao: Session, transacoes: list[Transacao]) -> list[Rascunho]:
    sugeridas = regras.sugestoes(sessao, transacoes)
    return [_rascunho(t, sugeridas[t.id]) for t in transacoes]


def _rascunho(transacao: Transacao, sugerida: RegraClassificacao | None) -> Rascunho:
    padrao = normalizar(transacao.descricao_original)
    if not grupos_do_tipo(TipoTransacao(transacao.tipo)):
        # Tipo sem categoria (ex.: transferência sem par): nada a aprender.
        nenhum = EfeitoAprendizado.nenhuma
        return Rascunho(transacao, padrao, None, nenhum, nenhum)
    return Rascunho(
        transacao=transacao,
        padrao=padrao,
        sugerida=sugerida,
        efeito_confirmando=prever_efeito(sugerida, padrao, mesma_categoria=True),
        efeito_corrigindo=prever_efeito(sugerida, padrao, mesma_categoria=False),
    )
