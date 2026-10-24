"""Regras de cartões: cadastro e em que fatura cai cada data.

A fatura só é gravada quando precisa (recebe transação ou é editada); antes
disso, as datas dela saem da regra do cartão (`cartoes/datas.py`). Quando a
fatura está gravada, valem as datas gravadas, que podem ter sido editadas.
"""

import calendar
import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.erros import CampoInvalido
from app.modulos.cartoes.datas import (
    DatasFatura,
    competencia_da_compra,
    competencia_de,
    datas_da_fatura,
    mes_anterior,
    mes_seguinte,
)
from app.modulos.cartoes.feriados import feriados_entre
from app.modulos.cartoes.models import Cartao, Fatura
from app.modulos.contas.models import Conta, TipoConta
from app.modulos.contas.service import obter_ou_criar_instituicao


class CartaoNaoEncontrado(Exception):
    pass


def obter_cartao(sessao: Session, conta_id: uuid.UUID) -> Cartao:
    cartao = sessao.get(Cartao, conta_id)
    if cartao is None:
        raise CartaoNaoEncontrado
    return cartao


def criar_cartao(
    sessao: Session,
    *,
    nome: str,
    nome_instituicao: str,
    conta_pagamento_id: uuid.UUID,
    dia_fechamento: int,
    dia_vencimento: int,
    limite: Decimal | None,
    hoje: date,
) -> Cartao:
    """Cadastra a conta `cartao_credito` e o cartão dela.

    Cartão não tem saldo inicial: a conta entra com zero a partir de hoje, e o
    que o app mostra é a fatura.
    """
    _validar_dias(dia_fechamento, dia_vencimento)
    _validar_conta_pagamento(sessao, conta_pagamento_id)
    conta = Conta(
        nome=nome,
        tipo=TipoConta.cartao_credito,
        instituicao=obter_ou_criar_instituicao(sessao, nome_instituicao),
        saldo_inicial=Decimal("0.00"),
        data_saldo_inicial=hoje,
    )
    cartao = Cartao(
        conta=conta,
        conta_pagamento_id=conta_pagamento_id,
        dia_fechamento=dia_fechamento,
        dia_vencimento=dia_vencimento,
        limite=limite,
    )
    sessao.add(cartao)
    sessao.commit()
    return cartao


def previa(sessao: Session, *, dia_fechamento: int, dia_vencimento: int, hoje: date) -> DatasFatura:
    """A fatura em que entraria uma compra feita hoje, para dias ainda não salvos."""

    def fechamento(competencia: date) -> date:
        return _datas(sessao, competencia, dia_fechamento, dia_vencimento).fechamento

    competencia = competencia_da_compra(hoje, fechamento)
    return _datas(sessao, competencia, dia_fechamento, dia_vencimento)


def datas_calculadas(sessao: Session, cartao: Cartao, competencia: date) -> DatasFatura:
    """Datas da competência pela regra do cartão, ignorando o que está gravado."""
    return _datas(sessao, competencia, cartao.dia_fechamento, cartao.dia_vencimento)


def fatura_gravada(sessao: Session, cartao: Cartao, competencia: date) -> Fatura | None:
    return sessao.scalar(
        select(Fatura).where(Fatura.cartao_id == cartao.conta_id, Fatura.competencia == competencia)
    )


def fechamento_efetivo(sessao: Session, cartao: Cartao, competencia: date) -> date:
    """O fechamento gravado, se a fatura existe; senão, o calculado."""
    fatura = fatura_gravada(sessao, cartao, competencia)
    if fatura is not None:
        return fatura.data_fechamento
    return datas_calculadas(sessao, cartao, competencia).fechamento


def competencia_para_data(sessao: Session, cartao: Cartao, dia: date) -> date:
    """Competência da fatura em que entra uma compra feita em `dia`."""
    return competencia_da_compra(dia, lambda c: fechamento_efetivo(sessao, cartao, c))


def obter_ou_criar_fatura(sessao: Session, cartao: Cartao, competencia: date) -> Fatura:
    """A fatura gravada da competência; se não existe, grava com as datas
    calculadas (sem commit: quem chama decide)."""
    fatura = fatura_gravada(sessao, cartao, competencia)
    if fatura is not None:
        return fatura
    datas = datas_calculadas(sessao, cartao, competencia)
    fatura = Fatura(
        cartao_id=cartao.conta_id,
        competencia=competencia,
        data_fechamento=datas.fechamento,
        data_vencimento=datas.vencimento,
    )
    sessao.add(fatura)
    sessao.flush()
    return fatura


def _datas(
    sessao: Session, competencia: date, dia_fechamento: int, dia_vencimento: int
) -> DatasFatura:
    # O fechamento pode cair no mês anterior, e o ajuste para dia útil empurra
    # as datas alguns dias: os feriados de dois meses antes ao fim do mês
    # seguinte cobrem tudo.
    de = mes_anterior(mes_anterior(competencia_de(competencia)))
    fim = mes_seguinte(competencia)
    ate = fim.replace(day=calendar.monthrange(fim.year, fim.month)[1])
    feriados = feriados_entre(sessao, de, ate)
    return datas_da_fatura(competencia, dia_fechamento, dia_vencimento, feriados)


def _validar_dias(dia_fechamento: int, dia_vencimento: int) -> None:
    if dia_fechamento == dia_vencimento:
        raise CampoInvalido(
            "dia_vencimento", "O vencimento precisa ser num dia diferente do fechamento."
        )


def _validar_conta_pagamento(sessao: Session, conta_id: uuid.UUID) -> None:
    conta = sessao.get(Conta, conta_id)
    if conta is None or conta.tipo != TipoConta.corrente or not conta.ativa:
        raise CampoInvalido(
            "conta_pagamento_id", "Escolha uma conta corrente ativa para pagar a fatura."
        )
