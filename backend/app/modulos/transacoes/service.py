"""Regras de transações: lançamento manual (à vista ou parcelado) e consulta."""

import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.erros import CampoInvalido
from app.modulos.cartoes import service as cartoes_service
from app.modulos.cartoes.datas import mes_seguinte
from app.modulos.contas.models import Conta, TipoConta
from app.modulos.transacoes.models import (
    CompraParcelada,
    FonteTransacao,
    StatusTransacao,
    TipoTransacao,
    Transacao,
)
from app.modulos.transacoes.parcelas import data_da_parcela, dividir_em_parcelas

_CENTAVO = Decimal("0.01")


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
    """Lançamento manual: entra confirmado e já conta no saldo da conta.

    Em cartão de crédito, só despesa (compra à vista), ligada à fatura da data.
    """
    conta = _conta_ativa(sessao, conta_id)
    fatura_id = None
    if conta.tipo == TipoConta.cartao_credito:
        if tipo != TipoTransacao.despesa:
            raise CampoInvalido("conta_id", "Num cartão de crédito, lance só despesas.")
        cartao = cartoes_service.obter_cartao(sessao, conta_id)
        competencia = cartoes_service.competencia_para_data(sessao, cartao, data)
        fatura_id = cartoes_service.obter_ou_criar_fatura(sessao, cartao, competencia).id

    transacao = Transacao(
        conta_id=conta_id,
        tipo=tipo,
        valor=valor,
        data=data,
        descricao_original=descricao,
        descricao=descricao,
        status=StatusTransacao.confirmada,
        fonte=FonteTransacao.manual,
        fatura_id=fatura_id,
    )
    sessao.add(transacao)
    sessao.commit()
    return transacao


def lancar_parcelada(
    sessao: Session,
    *,
    conta_id: uuid.UUID,
    valor_total: Decimal,
    qtd_parcelas: int,
    data_compra: date,
    descricao: str,
) -> CompraParcelada:
    """Compra parcelada num cartão: uma despesa confirmada por parcela.

    A parcela k tem a data da compra mais k−1 meses e entra na fatura da
    compra mais k−1 competências (não na fatura da própria data: com
    fechamento em dia útil, a data avançada poderia pular uma fatura). Entra
    tudo ou nada.
    """
    conta = _conta_ativa(sessao, conta_id)
    if conta.tipo != TipoConta.cartao_credito:
        raise CampoInvalido("conta_id", "Só compra no cartão de crédito pode ser parcelada.")
    if valor_total < _CENTAVO * qtd_parcelas:
        raise CampoInvalido("valor_total", "Cada parcela precisa ser de pelo menos R$ 0,01.")

    cartao = cartoes_service.obter_cartao(sessao, conta_id)
    compra = CompraParcelada(
        descricao=descricao,
        valor_total=valor_total,
        qtd_parcelas=qtd_parcelas,
        data_compra=data_compra,
    )
    try:
        competencia = cartoes_service.competencia_para_data(sessao, cartao, data_compra)
        valores = dividir_em_parcelas(valor_total, qtd_parcelas)
        for numero, valor in enumerate(valores, start=1):
            fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, competencia)
            compra.parcelas.append(
                Transacao(
                    conta_id=conta_id,
                    tipo=TipoTransacao.despesa,
                    valor=valor,
                    data=data_da_parcela(data_compra, numero),
                    descricao_original=descricao,
                    descricao=descricao,
                    status=StatusTransacao.confirmada,
                    fonte=FonteTransacao.manual,
                    fatura_id=fatura.id,
                    parcela_numero=numero,
                )
            )
            competencia = mes_seguinte(competencia)
        sessao.add(compra)
        sessao.commit()
    except Exception:
        sessao.rollback()
        raise
    return compra


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


def _conta_ativa(sessao: Session, conta_id: uuid.UUID) -> Conta:
    conta = sessao.get(Conta, conta_id)
    if conta is None:
        raise CampoInvalido("conta_id", "Conta não encontrada.")
    if not conta.ativa:
        raise CampoInvalido("conta_id", "Esta conta está desativada.")
    return conta
