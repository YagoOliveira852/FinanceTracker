"""Regras de transações: lançamento manual e consulta."""

import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.erros import CampoInvalido
from app.modulos.contas.models import Conta
from app.modulos.transacoes.models import (
    FonteTransacao,
    StatusTransacao,
    TipoTransacao,
    Transacao,
)


class TransacaoNaoEncontrada(Exception):
    pass


def lancar(
    sessao: Session,
    *,
    conta_id: uuid.UUID,
    tipo: TipoTransacao,
    valor: Decimal,
    data: date,
    descricao: str,
) -> Transacao:
    """Lançamento manual: entra confirmado e já conta no saldo da conta."""
    conta = sessao.get(Conta, conta_id)
    if conta is None:
        raise CampoInvalido("conta_id", "Conta não encontrada.")
    if not conta.ativa:
        raise CampoInvalido("conta_id", "Esta conta está desativada.")

    transacao = Transacao(
        conta_id=conta_id,
        tipo=tipo,
        valor=valor,
        data=data,
        descricao_original=descricao,
        descricao=descricao,
        status=StatusTransacao.confirmada,
        fonte=FonteTransacao.manual,
    )
    sessao.add(transacao)
    sessao.commit()
    return transacao


def listar(
    sessao: Session,
    *,
    conta_id: uuid.UUID | None = None,
    de: date | None = None,
    ate: date | None = None,
) -> list[Transacao]:
    """Transações de todos os status, da mais recente para a mais antiga."""
    consulta = select(Transacao).order_by(
        Transacao.data.desc(), Transacao.criado_em.desc(), Transacao.id
    )
    if conta_id is not None:
        consulta = consulta.where(Transacao.conta_id == conta_id)
    if de is not None:
        consulta = consulta.where(Transacao.data >= de)
    if ate is not None:
        consulta = consulta.where(Transacao.data <= ate)
    return list(sessao.scalars(consulta))


def obter(sessao: Session, transacao_id: uuid.UUID) -> Transacao:
    transacao = sessao.get(Transacao, transacao_id)
    if transacao is None:
        raise TransacaoNaoEncontrada
    return transacao
