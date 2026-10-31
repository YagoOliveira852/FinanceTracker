"""Regras de contas: cadastro e saldo atual.

O saldo não é guardado: é calculado com `saldo_inicial` e as transações
confirmadas a partir de `data_saldo_inicial`, numa consulta só para a lista
inteira (sem uma consulta por conta).
"""

import uuid
from dataclasses import dataclass
from datetime import date
from decimal import Decimal

from sqlalchemy import ColumnElement, Select, and_, case, func, or_, select
from sqlalchemy.orm import Session

from app.core.erros import CampoInvalido
from app.modulos.contas.models import Conta, Instituicao, TipoConta
from app.modulos.transacoes.models import TIPOS_ENTRADA, StatusTransacao, Transacao

# Entram no "total disponível"; a fatura do cartão não é dinheiro disponível.
TIPOS_DISPONIVEIS = frozenset({TipoConta.corrente, TipoConta.carteira})


class ContaNaoEncontrada(Exception):
    pass


@dataclass(frozen=True)
class ContaComSaldo:
    conta: Conta
    saldo_atual: Decimal


@dataclass(frozen=True)
class ResumoContas:
    contas: list[ContaComSaldo]
    total_disponivel: Decimal


def criar_conta(
    sessao: Session,
    *,
    nome: str,
    tipo: TipoConta,
    nome_instituicao: str | None,
    saldo_inicial: Decimal,
    data_saldo_inicial: date,
    hoje: date,
) -> ContaComSaldo:
    if data_saldo_inicial > hoje:
        raise CampoInvalido("data_saldo_inicial", "A data do saldo não pode ser depois de hoje.")
    if tipo == TipoConta.carteira:
        if nome_instituicao is not None:
            raise CampoInvalido("instituicao", "Carteira não tem instituição.")
        instituicao = None
    else:
        if nome_instituicao is None:
            raise CampoInvalido("instituicao", "Informe a instituição da conta.")
        instituicao = obter_ou_criar_instituicao(sessao, nome_instituicao)

    conta = Conta(
        nome=nome,
        tipo=tipo,
        instituicao=instituicao,
        saldo_inicial=saldo_inicial,
        data_saldo_inicial=data_saldo_inicial,
    )
    sessao.add(conta)
    sessao.commit()
    return obter_conta(sessao, conta.id)


def obter_conta(sessao: Session, conta_id: uuid.UUID) -> ContaComSaldo:
    linha = sessao.execute(_contas_com_saldo().where(Conta.id == conta_id)).one_or_none()
    if linha is None:
        raise ContaNaoEncontrada
    return ContaComSaldo(conta=linha.Conta, saldo_atual=linha.saldo_atual)


def listar_contas(sessao: Session) -> ResumoContas:
    linhas = sessao.execute(_contas_com_saldo().order_by(Conta.nome, Conta.id)).all()
    contas = [ContaComSaldo(conta=linha.Conta, saldo_atual=linha.saldo_atual) for linha in linhas]
    total = sum(
        (
            c.saldo_atual
            for c in contas
            if c.conta.ativa and TipoConta(c.conta.tipo) in TIPOS_DISPONIVEIS
        ),
        start=Decimal("0.00"),
    )
    return ResumoContas(contas=contas, total_disponivel=total)


def saldos_com_rascunhos(sessao: Session) -> list[ContaComSaldo]:
    """Contas ativas com o saldo do planejamento: confirmadas e rascunhos, sem
    as possíveis duplicatas. A tela de contas mostra o saldo oficial (só as
    confirmadas)."""
    linhas = sessao.execute(
        _contas_com_saldo(com_rascunhos=True).where(Conta.ativa).order_by(Conta.nome, Conta.id)
    ).all()
    return [ContaComSaldo(conta=linha.Conta, saldo_atual=linha.saldo_atual) for linha in linhas]


def obter_ou_criar_instituicao(sessao: Session, nome: str) -> Instituicao:
    existente = sessao.scalar(
        select(Instituicao).where(func.lower(Instituicao.nome) == nome.lower())
    )
    if existente is not None:
        return existente
    instituicao = Instituicao(nome=nome)
    sessao.add(instituicao)
    return instituicao


def _contas_com_saldo(*, com_rascunhos: bool = False) -> Select:
    """SELECT de (Conta, saldo_atual).

    O saldo inicial é o do começo do dia `data_saldo_inicial`: transação nesse
    mesmo dia entra no saldo (é o caso de quem cria a conta e já lança algo).
    Com `com_rascunhos`, entram também os rascunhos sem marca de duplicata.
    """
    movimento = case(
        (Transacao.tipo.in_([tipo.value for tipo in TIPOS_ENTRADA]), Transacao.valor),
        else_=-Transacao.valor,
    )
    movimentos = (
        select(Transacao.conta_id, func.sum(movimento).label("total"))
        .join(Conta, Conta.id == Transacao.conta_id)
        .where(
            _no_saldo(com_rascunhos),
            Transacao.data >= Conta.data_saldo_inicial,
        )
        .group_by(Transacao.conta_id)
        .subquery()
    )
    saldo_atual = Conta.saldo_inicial + func.coalesce(movimentos.c.total, 0)
    return select(Conta, saldo_atual.label("saldo_atual")).outerjoin(
        movimentos, movimentos.c.conta_id == Conta.id
    )


def _no_saldo(com_rascunhos: bool) -> ColumnElement[bool]:
    confirmada = Transacao.status == StatusTransacao.confirmada.value
    if not com_rascunhos:
        return confirmada
    rascunho = and_(
        Transacao.status == StatusTransacao.rascunho.value,
        Transacao.possivel_duplicata_de.is_(None),
    )
    return or_(confirmada, rascunho)
