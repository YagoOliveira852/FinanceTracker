"""Regras de faturas: valor, status, lista e detalhe.

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

from app.core.erros import CampoInvalido
from app.modulos.cartoes import service
from app.modulos.cartoes.datas import (
    DatasFatura,
    StatusFatura,
    mes_anterior,
    mes_seguinte,
    status_da_fatura,
)
from app.modulos.cartoes.feriados import feriados_entre
from app.modulos.cartoes.models import Cartao, Fatura
from app.modulos.transacoes.models import (
    TIPOS_ENTRADA,
    FonteTransacao,
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
DESCRICAO_AJUSTE = "Ajuste da fatura"


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


@dataclass(frozen=True)
class ListaFaturas:
    atual: ResumoFatura
    # Gravadas depois da atual, da mais próxima para a mais distante.
    proximas: list[ResumoFatura]
    # Gravadas antes da atual, da mais recente para a mais antiga.
    anteriores: list[ResumoFatura]


@dataclass(frozen=True)
class AjusteData:
    """Por que a data efetiva não é a prevista: fim de semana e/ou feriados."""

    data_prevista: date
    # Feriados entre a data prevista e a efetiva (exclusive).
    feriados: dict[date, str]


@dataclass(frozen=True)
class DetalheFatura:
    resumo: ResumoFatura
    datas_calculadas: DatasFatura
    ajuste_fechamento: AjusteData | None
    ajuste_vencimento: AjusteData | None
    # Sem as ignoradas, da mais recente para a mais antiga.
    transacoes: list[Transacao]


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
    return _resumo_da_gravada(fatura, calculado, hoje)


def resumo_atual(sessao: Session, cartao: Cartao, hoje: date) -> ResumoFatura:
    """A fatura em que entraria uma compra feita hoje."""
    return resumo(sessao, cartao, service.competencia_para_data(sessao, cartao, hoje), hoje)


def listar(sessao: Session, cartao: Cartao, hoje: date) -> ListaFaturas:
    atual = resumo_atual(sessao, cartao, hoje)
    gravadas = list(
        sessao.scalars(
            select(Fatura).where(Fatura.cartao_id == cartao.conta_id).order_by(Fatura.competencia)
        )
    )
    valores = valores_calculados(sessao, [fatura.id for fatura in gravadas])
    resumos = [_resumo_da_gravada(f, valores.get(f.id, _ZERO), hoje) for f in gravadas]
    return ListaFaturas(
        atual=atual,
        proximas=[r for r in resumos if r.competencia > atual.competencia],
        anteriores=[r for r in reversed(resumos) if r.competencia < atual.competencia],
    )


def detalhe(sessao: Session, cartao: Cartao, competencia: date, hoje: date) -> DetalheFatura:
    resumo_ = resumo(sessao, cartao, competencia, hoje)
    datas = service.datas_calculadas(sessao, cartao, competencia)
    transacoes = []
    if resumo_.fatura is not None:
        transacoes = list(
            sessao.scalars(
                select(Transacao)
                .where(
                    Transacao.fatura_id == resumo_.fatura.id,
                    Transacao.status != StatusTransacao.ignorada.value,
                )
                .order_by(Transacao.data.desc(), Transacao.criado_em.desc(), Transacao.id)
            )
        )
    return DetalheFatura(
        resumo=resumo_,
        datas_calculadas=datas,
        ajuste_fechamento=_ajuste(sessao, datas.fechamento_previsto, datas.fechamento),
        ajuste_vencimento=_ajuste(sessao, datas.vencimento_previsto, datas.vencimento),
        transacoes=transacoes,
    )


def editar(
    sessao: Session,
    cartao: Cartao,
    competencia: date,
    *,
    data_fechamento: date,
    data_vencimento: date,
    valor_informado: Decimal | None,
    hoje: date,
) -> DetalheFatura:
    """Edita datas e valor informado, gravando a fatura se ainda não existe.

    Mudar o fechamento realoca as compras com data entre o antigo e o novo:
    antecipar manda para a fatura seguinte as feitas a partir da nova data;
    adiar traz de volta as feitas antes dela.
    """
    anterior = service.fechamento_efetivo(sessao, cartao, mes_anterior(competencia))
    seguinte = service.fechamento_efetivo(sessao, cartao, mes_seguinte(competencia))
    if not anterior < data_fechamento < seguinte:
        raise CampoInvalido(
            "data_fechamento",
            "O fechamento precisa ficar depois do da fatura anterior e antes do da seguinte.",
        )
    if data_vencimento <= data_fechamento:
        raise CampoInvalido("data_vencimento", "O vencimento precisa ser depois do fechamento.")
    if valor_informado is not None and valor_informado < 0:
        raise CampoInvalido("valor_informado", "O valor informado não pode ser negativo.")

    fatura = service.obter_ou_criar_fatura(sessao, cartao, competencia)
    antigo = fatura.data_fechamento
    fatura.data_fechamento = data_fechamento
    fatura.data_vencimento = data_vencimento
    fatura.valor_informado = valor_informado
    sessao.flush()
    if antigo != data_fechamento:
        service.realocar_compras(
            sessao, cartao, min(antigo, data_fechamento), max(antigo, data_fechamento)
        )
    sessao.commit()
    return detalhe(sessao, cartao, competencia, hoje)


def ajustar(
    sessao: Session,
    cartao: Cartao,
    competencia: date,
    *,
    valor_real: Decimal,
    descricao: str | None,
    hoje: date,
) -> DetalheFatura:
    """Ajusta a fatura para o valor real que o banco cobra.

    Grava o valor real como informado e deixa na fatura uma transação de ajuste
    com a diferença para o calculado (sem o ajuste anterior): `ajuste_saida` se
    faltava lançamento, `ajuste_entrada` se sobrava. A fatura tem no máximo um
    ajuste: ajustar de novo o substitui, e sem diferença ele é removido. Assim
    a diferença não some sem rastro, e a descrição registra a causa.
    """
    if valor_real < 0:
        raise CampoInvalido("valor_real", "O valor real não pode ser negativo.")
    fatura = service.obter_ou_criar_fatura(sessao, cartao, competencia)
    ajuste = sessao.scalar(
        select(Transacao).where(
            Transacao.fatura_id == fatura.id,
            Transacao.tipo.in_([tipo.value for tipo in service.TIPOS_AJUSTE]),
        )
    )
    calculado = valores_calculados(sessao, [fatura.id]).get(fatura.id, _ZERO)
    if ajuste is not None:
        efeito = -ajuste.valor if ajuste.tipo == TipoTransacao.ajuste_entrada else ajuste.valor
        calculado -= efeito
    diferenca = valor_real - calculado

    fatura.valor_informado = valor_real
    if diferenca == 0:
        if ajuste is not None:
            sessao.delete(ajuste)
    else:
        if ajuste is None:
            ajuste = Transacao(
                conta_id=cartao.conta_id,
                fatura_id=fatura.id,
                status=StatusTransacao.confirmada,
                fonte=FonteTransacao.manual,
            )
            sessao.add(ajuste)
        ajuste.tipo = TipoTransacao.ajuste_saida if diferenca > 0 else TipoTransacao.ajuste_entrada
        ajuste.valor = abs(diferenca)
        ajuste.data = hoje
        ajuste.descricao = ajuste.descricao_original = descricao or DESCRICAO_AJUSTE
    sessao.commit()
    return detalhe(sessao, cartao, competencia, hoje)


def _ajuste(sessao: Session, prevista: date, efetiva: date) -> AjusteData | None:
    if prevista == efetiva:
        return None
    feriados = feriados_entre(sessao, prevista, efetiva)
    return AjusteData(
        data_prevista=prevista,
        feriados={dia: nome for dia, nome in sorted(feriados.items()) if dia < efetiva},
    )


def _resumo_da_gravada(fatura: Fatura, calculado: Decimal, hoje: date) -> ResumoFatura:
    return _resumo(
        fatura.competencia,
        fatura.data_fechamento,
        fatura.data_vencimento,
        calculado,
        fatura.valor_informado,
        hoje,
        fatura,
    )


def _resumo(
    competencia: date,
    fechamento: date,
    vencimento: date,
    calculado: Decimal,
    informado: Decimal | None,
    hoje: date,
    fatura: Fatura | None,
) -> ResumoFatura:
    valor = calculado if informado is None else max(informado, calculado)
    return ResumoFatura(
        competencia=competencia,
        data_fechamento=fechamento,
        data_vencimento=vencimento,
        status=status_da_fatura(fechamento, hoje, valor, _ZERO),
        valor=valor,
        valor_calculado=calculado,
        valor_informado=informado,
        fatura=fatura,
    )
