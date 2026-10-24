"""Regras de faturas: valor, status e resumo de uma competência.

O valor calculado é a soma das compras menos a dos estornos da fatura,
contando rascunhos (como o cálculo do aporte) e sem as ignoradas. O valor da
fatura é o maior entre o informado pelo banco e o calculado: o padrão seguro
enquanto a diferença não é resolvida.
"""

import uuid
from collections.abc import Collection
from dataclasses import dataclass
from datetime import date
from decimal import Decimal

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.modulos.cartoes import service
from app.modulos.cartoes.datas import StatusFatura, status_da_fatura
from app.modulos.cartoes.models import Cartao, Fatura
from app.modulos.transacoes.models import (
    TIPOS_ENTRADA,
    StatusTransacao,
    TipoTransacao,
    Transacao,
)

# Pagamento e transferência movem dinheiro, mas não são compra nem estorno.
_FORA_DO_CALCULADO = frozenset(
    {
        TipoTransacao.pagamento_fatura,
        TipoTransacao.transferencia_entrada,
        TipoTransacao.transferencia_saida,
    }
)
_STATUS_QUE_CONTAM = frozenset({StatusTransacao.confirmada, StatusTransacao.rascunho})
_ZERO = Decimal("0.00")


@dataclass(frozen=True)
class ResumoFatura:
    competencia: date
    data_fechamento: date
    data_vencimento: date
    status: StatusFatura
    valor: Decimal
    valor_calculado: Decimal
    valor_informado: Decimal | None
    # Nula enquanto a fatura não foi gravada (é só calculada).
    fatura: Fatura | None


def valores_calculados(
    sessao: Session, fatura_ids: Collection[uuid.UUID]
) -> dict[uuid.UUID, Decimal]:
    """{fatura_id: compras − estornos}, numa consulta só. Fatura sem transação
    que conte não aparece."""
    if not fatura_ids:
        return {}
    movimento = case(
        (Transacao.tipo.in_([tipo.value for tipo in TIPOS_ENTRADA]), -Transacao.valor),
        else_=Transacao.valor,
    )
    linhas = sessao.execute(
        select(Transacao.fatura_id, func.sum(movimento))
        .where(
            Transacao.fatura_id.in_(fatura_ids),
            Transacao.status.in_([status.value for status in _STATUS_QUE_CONTAM]),
            Transacao.tipo.not_in([tipo.value for tipo in _FORA_DO_CALCULADO]),
        )
        .group_by(Transacao.fatura_id)
    ).all()
    return {fatura_id: total for fatura_id, total in linhas}


def resumo(sessao: Session, cartao: Cartao, competencia: date, hoje: date) -> ResumoFatura:
    """Resumo da competência: o da fatura gravada ou o calculado pela regra."""
    fatura = service.fatura_gravada(sessao, cartao, competencia)
    if fatura is None:
        datas = service.datas_calculadas(sessao, cartao, competencia)
        return _resumo(competencia, datas.fechamento, datas.vencimento, _ZERO, None, hoje, None)
    calculado = valores_calculados(sessao, [fatura.id]).get(fatura.id, _ZERO)
    return _resumo(
        competencia,
        fatura.data_fechamento,
        fatura.data_vencimento,
        calculado,
        fatura.valor_informado,
        hoje,
        fatura,
    )


def resumo_atual(sessao: Session, cartao: Cartao, hoje: date) -> ResumoFatura:
    """A fatura em que entraria uma compra feita hoje."""
    return resumo(sessao, cartao, service.competencia_para_data(sessao, cartao, hoje), hoje)


def _resumo(
    competencia: date,
    fechamento: date,
    vencimento: date,
    calculado: Decimal,
    informado: Decimal | None,
    hoje: date,
    fatura: Fatura | None,
) -> ResumoFatura:
    return ResumoFatura(
        competencia=competencia,
        data_fechamento=fechamento,
        data_vencimento=vencimento,
        status=status_da_fatura(fechamento, hoje),
        valor=calculado if informado is None else max(informado, calculado),
        valor_calculado=calculado,
        valor_informado=informado,
        fatura=fatura,
    )
