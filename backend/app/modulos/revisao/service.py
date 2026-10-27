"""Regras da revisão: a lista do que espera o usuário e as ações sobre os
rascunhos (spec `2026-10-19-revisao-classificacao`, "Decisões do design da
revisão" e "Decisões do código da revisão")."""

import uuid
from dataclasses import dataclass, field
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.erros import CampoInvalido
from app.modulos.cartoes import faturas
from app.modulos.cartoes import service as cartoes_service
from app.modulos.cartoes.datas import StatusFatura, status_da_fatura
from app.modulos.cartoes.faturas import ResumoFatura
from app.modulos.cartoes.models import Cartao
from app.modulos.categorias import regras
from app.modulos.categorias import service as categorias_service
from app.modulos.categorias.classificacao import grupos_do_tipo, normalizar
from app.modulos.categorias.models import RegraClassificacao
from app.modulos.categorias.regras import Aprendizado, EfeitoAprendizado, prever_efeito
from app.modulos.contas.models import Conta, TipoConta
from app.modulos.revisao.models import ParRecusado
from app.modulos.revisao.pareamento import DIAS_MAXIMOS, casam, sugerir_pares
from app.modulos.transacoes import service as transacoes_service
from app.modulos.transacoes.models import (
    TIPOS_SAIDA,
    FonteTransacao,
    StatusTransacao,
    TipoTransacao,
    Transacao,
)

# Das fontes, um Pix entre contas próprias chega como despesa e receita (ou já
# como transferência, se a fonte souber).
_SAIDAS_DE_PAR = frozenset({TipoTransacao.despesa, TipoTransacao.transferencia_saida})
_ENTRADAS_DE_PAR = frozenset({TipoTransacao.receita, TipoTransacao.transferencia_entrada})
_CONTAS_DE_TRANSFERENCIA = frozenset({TipoConta.corrente, TipoConta.carteira})
# Tipos em que um rascunho é confirmado com categoria, por sentido.
# Transferência e pagamento de fatura têm ações próprias; aporte e resgate
# esperam os investimentos.
_CONFIRMAVEIS_SAIDA = frozenset({TipoTransacao.despesa})
_CONFIRMAVEIS_ENTRADA = frozenset({TipoTransacao.receita, TipoTransacao.estorno})
_MENSAGEM_TIPO = {
    _CONFIRMAVEIS_SAIDA: "Uma saída é confirmada como despesa; transferência e pagamento de "
    "fatura têm opção própria.",
    _CONFIRMAVEIS_ENTRADA: "Uma entrada é confirmada como receita ou estorno; transferência "
    "tem opção própria.",
}


# Quantas faturas fechadas antes da atual entram como candidatas a um pagamento.
_FATURAS_ANTERIORES = 2


class NaoEhPagamento(Exception):
    """Só um rascunho de pagamento de fatura escolhe a fatura."""


class JaRevisada(Exception):
    """A transação não está mais no estado que a ação espera (a lista do app
    ficou velha): já foi confirmada, ignorada ou ligada."""


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
class FaturaCandidata:
    """Uma fatura que o pagamento pode ter pago, como fica com ele."""

    cartao: Cartao
    resumo: ResumoFatura
    fica_paga: bool
    sugerida: bool


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


def confirmar(
    sessao: Session,
    transacao_id: uuid.UUID,
    *,
    descricao: str,
    categoria_id: uuid.UUID,
    tipo: TipoTransacao | None = None,
) -> Aprendizado:
    """Confirma o rascunho com a categoria escolhida e ensina as regras
    (`regras.confirmar_categoria`). O tipo pode mudar no mesmo sentido (ex.:
    a receita que era estorno); a descrição original nunca muda."""
    transacao = _rascunho_para_revisar(sessao, transacao_id)
    tipo = TipoTransacao(tipo or transacao.tipo)
    saida = transacao.tipo in TIPOS_SAIDA
    confirmaveis = _CONFIRMAVEIS_SAIDA if saida else _CONFIRMAVEIS_ENTRADA
    if tipo not in confirmaveis:
        raise CampoInvalido("tipo", _MENSAGEM_TIPO[confirmaveis])
    # Valida antes de mudar a transação: um 422 não deixa nada pela metade.
    categorias_service.categoria_para_tipo(sessao, categoria_id, tipo)

    transacao.tipo = tipo
    transacao.descricao = descricao
    if transacao.conta.tipo != TipoConta.cartao_credito:
        # Fora do cartão, só o pagamento de fatura tem fatura ("É outra coisa").
        transacao.fatura_id = None
    return regras.confirmar_categoria(sessao, transacao.id, categoria_id)


def ignorar(sessao: Session, transacao_id: uuid.UUID) -> None:
    """Ignorada, nunca apagada: fica no histórico e a idempotência impede que
    volte na próxima importação."""
    _rascunho_para_revisar(sessao, transacao_id).status = StatusTransacao.ignorada
    sessao.commit()


def confirmar_lote(sessao: Session, ids: list[uuid.UUID]) -> int:
    """Confirma com a categoria sugerida os rascunhos comuns da lista que
    ainda têm sugestão; os demais (decisões, sem sugestão, já revisados) ficam
    de fora. Tudo num commit; devolve quantos confirmou."""
    sugeridos = {
        rascunho.transacao.id: rascunho
        for rascunho in listar(sessao).rascunhos
        if rascunho.sugerida is not None
    }
    confirmados = 0
    for transacao_id in dict.fromkeys(ids):
        rascunho = sugeridos.get(transacao_id)
        if rascunho is None:
            continue
        categoria = rascunho.sugerida.categoria
        regras.aprender(sessao, rascunho.transacao, categoria)
        rascunho.transacao.categoria = categoria
        rascunho.transacao.status = StatusTransacao.confirmada
        confirmados += 1
    sessao.commit()
    return confirmados


def _rascunho_para_revisar(sessao: Session, transacao_id: uuid.UUID) -> Transacao:
    transacao = transacoes_service.obter(sessao, transacao_id)
    if transacao.status != StatusTransacao.rascunho:
        raise JaRevisada
    return transacao


def ligar_par(
    sessao: Session, saida_id: uuid.UUID, entrada_id: uuid.UUID, descricao: str | None
) -> None:
    """ "Ligar": as duas viram transferência entre contas próprias, confirmadas
    e sem categoria (não são gasto nem renda). A descrição, se vier, vale para
    os dois lados."""
    saida = _rascunho_para_revisar(sessao, saida_id)
    entrada = _rascunho_para_revisar(sessao, entrada_id)
    if saida.transferencia_par_id is not None or entrada.transferencia_par_id is not None:
        raise JaRevisada
    if saida.tipo not in _SAIDAS_DE_PAR or saida.conta.tipo not in _CONTAS_DE_TRANSFERENCIA:
        raise CampoInvalido("saida_id", "Escolha a saída de uma conta corrente ou carteira.")
    if entrada.tipo not in _ENTRADAS_DE_PAR or entrada.conta.tipo not in _CONTAS_DE_TRANSFERENCIA:
        raise CampoInvalido("entrada_id", "Escolha a entrada de uma conta corrente ou carteira.")
    if not casam(saida, entrada):
        raise CampoInvalido(
            "entrada_id",
            "O par precisa ter o mesmo valor, contas diferentes e até 2 dias de diferença.",
        )
    _ligar(saida, entrada, descricao)
    sessao.commit()


def recusar_par(sessao: Session, saida_id: uuid.UUID, entrada_id: uuid.UUID) -> None:
    """ "Não é par": a sugestão desta saída com esta entrada não volta; cada uma
    ainda pode parear com outra. Recusar de novo não muda nada."""
    transacoes_service.obter(sessao, saida_id)
    transacoes_service.obter(sessao, entrada_id)
    if saida_id == entrada_id:
        raise CampoInvalido("entrada_id", "Escolha uma transação diferente da saída.")
    ja_recusado = sessao.scalar(
        select(ParRecusado.id).where(
            ParRecusado.saida_id == saida_id, ParRecusado.entrada_id == entrada_id
        )
    )
    if ja_recusado is None:
        sessao.add(ParRecusado(saida_id=saida_id, entrada_id=entrada_id))
    sessao.commit()


def transferir(
    sessao: Session, transacao_id: uuid.UUID, *, conta_id: uuid.UUID, descricao: str
) -> None:
    """O rascunho é uma transferência com a outra conta (campo "Para", ou "De"
    numa entrada). Se a outra conta é alimentada por fonte, o outro lado chega
    de lá: liga com o rascunho compatível, ou recusa até ele chegar (criar
    agora o duplicaria). Sem fonte (ex.: carteira), o app cria o outro lado,
    confirmado."""
    transacao = _rascunho_para_revisar(sessao, transacao_id)
    if transacao.transferencia_par_id is not None:
        raise JaRevisada
    if transacao.conta.tipo not in _CONTAS_DE_TRANSFERENCIA:
        raise CampoInvalido("conta_id", "Do cartão não sai transferência: use Pagamento de fatura.")
    outra_conta = transacoes_service.conta_de_transferencia(sessao, conta_id, "conta_id")
    if outra_conta.id == transacao.conta_id:
        raise CampoInvalido("conta_id", "Escolha uma conta diferente da do rascunho.")

    e_saida = transacao.tipo in TIPOS_SAIDA
    if transacoes_service.conta_tem_fonte(sessao, outra_conta.id):
        outro_lado = _outro_lado_que_chegou(sessao, transacao, outra_conta.id, e_saida)
        if outro_lado is None:
            lado = "entrada" if e_saida else "saída"
            raise CampoInvalido(
                "conta_id",
                f"A {outra_conta.nome} recebe extrato ou Open Finance: confirme quando a "
                f"{lado} chegar de lá.",
            )
    else:
        outro_lado = Transacao(
            conta_id=outra_conta.id,
            # Provisório: `_ligar` dá o tipo de transferência aos dois lados.
            tipo=TipoTransacao.receita if e_saida else TipoTransacao.despesa,
            valor=transacao.valor,
            data=transacao.data,
            descricao_original=descricao,
            descricao=descricao,
            status=StatusTransacao.confirmada,
            fonte=FonteTransacao.manual,
        )
        sessao.add(outro_lado)
    saida, entrada = (transacao, outro_lado) if e_saida else (outro_lado, transacao)
    _ligar(saida, entrada, descricao)
    sessao.commit()


def _outro_lado_que_chegou(
    sessao: Session, transacao: Transacao, conta_id: uuid.UUID, e_saida: bool
) -> Transacao | None:
    """O rascunho da outra conta que pode ser o outro lado: sentido oposto,
    mesmo valor, até `DIAS_MAXIMOS` dias, sem par e sem par recusado com este;
    o de data mais próxima."""
    tipos = _ENTRADAS_DE_PAR if e_saida else _SAIDAS_DE_PAR
    recusado = select(ParRecusado.id).where(
        ParRecusado.saida_id == (transacao.id if e_saida else Transacao.id),
        ParRecusado.entrada_id == (Transacao.id if e_saida else transacao.id),
    )
    distancia = func.abs(Transacao.data - transacao.data)
    return sessao.scalars(
        select(Transacao)
        .where(
            Transacao.conta_id == conta_id,
            Transacao.status == StatusTransacao.rascunho.value,
            Transacao.tipo.in_([tipo.value for tipo in tipos]),
            Transacao.valor == transacao.valor,
            Transacao.transferencia_par_id.is_(None),
            distancia <= DIAS_MAXIMOS,
            ~recusado.exists(),
        )
        .order_by(distancia, Transacao.data, Transacao.id)
        .limit(1)
    ).first()


def faturas_do_pagamento(
    sessao: Session, transacao_id: uuid.UUID, hoje: date
) -> list[FaturaCandidata]:
    """As faturas que o pagamento pode ter pago: de cada cartão ativo, a atual
    e as duas anteriores. Sugerida: a que a fonte já ligou ou, senão, a
    fechada do cartão pago por esta conta com o vencimento mais perto da data
    do pagamento."""
    pagamento = _pagamento_para_revisar(sessao, transacao_id)
    cartoes = sessao.scalars(
        select(Cartao).join(Cartao.conta).where(Conta.ativa.is_(True)).order_by(Conta.nome)
    )
    candidatas: list[tuple[Cartao, ResumoFatura]] = []
    for cartao in cartoes:
        lista = faturas.listar(sessao, cartao, hoje)
        candidatas += [(cartao, r) for r in [lista.atual, *lista.anteriores[:_FATURAS_ANTERIORES]]]

    sugerida = next(
        (r for _, r in candidatas if r.fatura is not None and r.fatura.id == pagamento.fatura_id),
        None,
    )
    if sugerida is None:
        sugerida = min(
            (
                r
                for c, r in candidatas
                if c.conta_pagamento_id == pagamento.conta_id and r.status == StatusFatura.fechada
            ),
            key=lambda r: abs((r.data_vencimento - pagamento.data).days),
            default=None,
        )
    return [
        FaturaCandidata(
            cartao=cartao,
            resumo=resumo,
            fica_paga=_fica_paga(resumo, pagamento, hoje),
            sugerida=resumo is sugerida,
        )
        for cartao, resumo in candidatas
    ]


def pagar(
    sessao: Session, transacao_id: uuid.UUID, *, cartao_id: uuid.UUID, competencia: date
) -> None:
    """Confirma o pagamento ligado à fatura escolhida, gravando-a se ainda é só
    calculada. Não é gasto: as compras já contaram no cartão."""
    pagamento = _pagamento_para_revisar(sessao, transacao_id)
    try:
        cartao = cartoes_service.obter_cartao(sessao, cartao_id)
    except cartoes_service.CartaoNaoEncontrado as exc:
        raise CampoInvalido("cartao_id", "Cartão não encontrado.") from exc
    fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, competencia)
    pagamento.fatura_id = fatura.id
    pagamento.status = StatusTransacao.confirmada
    sessao.commit()


def _fica_paga(resumo: ResumoFatura, pagamento: Transacao, hoje: date) -> bool:
    ja_ligado = resumo.fatura is not None and resumo.fatura.id == pagamento.fatura_id
    pago = resumo.valor_pago + (0 if ja_ligado else pagamento.valor)
    return status_da_fatura(resumo.data_fechamento, hoje, resumo.valor, pago) == StatusFatura.paga


def _pagamento_para_revisar(sessao: Session, transacao_id: uuid.UUID) -> Transacao:
    pagamento = _rascunho_para_revisar(sessao, transacao_id)
    if pagamento.tipo != TipoTransacao.pagamento_fatura:
        raise NaoEhPagamento
    return pagamento


def _ligar(saida: Transacao, entrada: Transacao, descricao: str | None) -> None:
    for lado, tipo in (
        (saida, TipoTransacao.transferencia_saida),
        (entrada, TipoTransacao.transferencia_entrada),
    ):
        lado.tipo = tipo
        lado.categoria = None
        # Fora do cartão, só pagamento de fatura tem fatura.
        lado.fatura_id = None
        lado.status = StatusTransacao.confirmada
        if descricao:
            lado.descricao = descricao
    saida.transferencia_par = entrada
    entrada.transferencia_par = saida
