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
from app.modulos.transacoes.models import TipoTransacao, Transacao

# O ajuste da fatura pertence a ela por definição, não pela data: nunca muda de
# fatura quando um fechamento muda.
TIPOS_AJUSTE = frozenset({TipoTransacao.ajuste_entrada, TipoTransacao.ajuste_saida})


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


def editar_cartao(
    sessao: Session,
    conta_id: uuid.UUID,
    *,
    nome: str,
    nome_instituicao: str,
    conta_pagamento_id: uuid.UUID,
    dia_fechamento: int,
    dia_vencimento: int,
    limite: Decimal | None,
    ativa: bool,
    hoje: date,
) -> Cartao:
    """Edita o cartão; `ativa=False` desativa (nada é excluído).

    Dias novos valem a partir da fatura seguinte à atual, como nos bancos: a
    atual é gravada (para manter as datas que tinha), as seguintes gravadas são
    recalculadas, e as compras a partir do fechamento da atual são realocadas.
    """
    cartao = obter_cartao(sessao, conta_id)
    _validar_dias(dia_fechamento, dia_vencimento)
    _validar_conta_pagamento(sessao, conta_pagamento_id)
    dias_mudaram = (dia_fechamento, dia_vencimento) != (
        cartao.dia_fechamento,
        cartao.dia_vencimento,
    )
    if dias_mudaram:
        atual = competencia_para_data(sessao, cartao, hoje)
        fechamento_atual = fechamento_efetivo(sessao, cartao, atual)
        seguinte = _datas(sessao, mes_seguinte(atual), dia_fechamento, dia_vencimento)
        if seguinte.fechamento <= fechamento_atual:
            raise CampoInvalido(
                "dia_fechamento", "Com esses dias, a próxima fatura fecharia antes da atual."
            )
        obter_ou_criar_fatura(sessao, cartao, atual)

    cartao.conta.nome = nome
    cartao.conta.instituicao = obter_ou_criar_instituicao(sessao, nome_instituicao)
    cartao.conta.ativa = ativa
    cartao.conta_pagamento_id = conta_pagamento_id
    cartao.limite = limite
    if dias_mudaram:
        cartao.dia_fechamento = dia_fechamento
        cartao.dia_vencimento = dia_vencimento
        futuras = sessao.scalars(
            select(Fatura).where(Fatura.cartao_id == cartao.conta_id, Fatura.competencia > atual)
        )
        for fatura in futuras:
            datas = datas_calculadas(sessao, cartao, fatura.competencia)
            fatura.data_fechamento = datas.fechamento
            fatura.data_vencimento = datas.vencimento
        sessao.flush()
        realocar_compras(sessao, cartao, fechamento_atual, None)
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


def realocar_compras(sessao: Session, cartao: Cartao, de: date, ate: date | None) -> None:
    """Põe cada transação do cartão com data em [`de`, `ate`) (ou a partir de
    `de`, se `ate` é nulo) na fatura que a regra manda, gravando a fatura se
    preciso. Usada quando um fechamento muda. Sem commit."""
    consulta = select(Transacao).where(
        Transacao.conta_id == cartao.conta_id,
        Transacao.data >= de,
        Transacao.tipo.not_in([tipo.value for tipo in TIPOS_AJUSTE]),
    )
    if ate is not None:
        consulta = consulta.where(Transacao.data < ate)
    faturas: dict[date, Fatura] = {}
    for transacao in sessao.scalars(consulta):
        competencia = competencia_para_data(sessao, cartao, transacao.data)
        if competencia not in faturas:
            faturas[competencia] = obter_ou_criar_fatura(sessao, cartao, competencia)
        transacao.fatura_id = faturas[competencia].id
    sessao.flush()


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
