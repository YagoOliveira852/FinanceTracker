"""Regras do planejamento: cadastro das rendas previstas e da configuração.

O cálculo (aporte, alerta, meses de reserva) é de `planejamento/calculo.py`;
aqui só se monta a entrada dele a partir do banco.
"""

import calendar
import uuid
from collections.abc import Mapping
from dataclasses import dataclass, replace
from datetime import date
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.erros import CampoInvalido
from app.modulos.cartoes.datas import competencia_de, mes_anterior, mes_seguinte
from app.modulos.cartoes.feriados import feriados_entre
from app.modulos.contas.models import Conta, TipoConta
from app.modulos.planejamento import calculo
from app.modulos.planejamento.calculo import data_do_salario
from app.modulos.planejamento.models import ID_CONFIGURACAO, Configuracao, RendaPrevista
from app.modulos.transacoes.models import StatusTransacao, TipoTransacao, Transacao

# Onde a renda pode cair: as contas do saldo disponível.
_CONTAS_DA_RENDA = frozenset({TipoConta.corrente, TipoConta.carteira})


@dataclass(frozen=True)
class ProximaData:
    """Próxima data esperada de uma renda, a partir de hoje (inclusive)."""

    # A efetiva, já em dia útil.
    data: date
    # O dia da renda no mês (29 a 31 em mês mais curto vira o último dia).
    data_prevista: date
    # Feriados de `data_prevista` até `data` (exclusive): com o fim de semana,
    # são o motivo da mudança.
    feriados: dict[date, str]


@dataclass(frozen=True)
class RendaComProxima:
    renda: RendaPrevista
    proxima: ProximaData


@dataclass(frozen=True)
class LeituraConfiguracao:
    # Nula até o primeiro salvamento.
    configuracao: Configuracao | None
    # A média dos 3 últimos meses fechados, mesmo com valor fixo salvo (a tela
    # mostra os dois); nula sem nenhum mês fechado no histórico.
    gasto_mensal_automatico: calculo.GastoMensal | None
    # Nula com menos de 4 semanas de histórico.
    media_semanal_real: Decimal | None
    # Pelo gasto mensal que vale (o fixo ou o automático); nulo sem ele.
    meses_de_reserva: Decimal | None


class RendaNaoEncontrada(Exception):
    pass


def listar_rendas(sessao: Session, hoje: date) -> list[RendaComProxima]:
    """Ativas primeiro, depois as inativas; em cada grupo, pela próxima data."""
    feriados = _feriados_ao_redor(sessao, hoje)
    itens = [
        RendaComProxima(renda, _proxima_data(renda.dia_previsto, hoje, feriados))
        for renda in sessao.scalars(select(RendaPrevista))
    ]
    return sorted(
        itens, key=lambda item: (not item.renda.ativa, item.proxima.data, item.renda.descricao)
    )


def previa(sessao: Session, dia_previsto: int, hoje: date) -> ProximaData:
    """A próxima data para um dia ainda não salvo (formulário da renda)."""
    return _proxima_data(dia_previsto, hoje, _feriados_ao_redor(sessao, hoje))


def criar_renda(
    sessao: Session,
    *,
    descricao: str,
    valor: Decimal,
    dia_previsto: int,
    conta_id: uuid.UUID,
    hoje: date,
) -> RendaComProxima:
    _validar_renda(sessao, descricao, valor, dia_previsto, conta_id)
    renda = RendaPrevista(
        descricao=descricao, valor=valor, dia_previsto=dia_previsto, conta_id=conta_id
    )
    sessao.add(renda)
    sessao.commit()
    return RendaComProxima(renda, previa(sessao, dia_previsto, hoje))


def editar_renda(
    sessao: Session,
    renda_id: uuid.UUID,
    *,
    descricao: str,
    valor: Decimal,
    dia_previsto: int,
    conta_id: uuid.UUID,
    ativa: bool,
    hoje: date,
) -> RendaComProxima:
    """Edita a renda; `ativa=False` desativa (renda nunca é excluída)."""
    renda = sessao.get(RendaPrevista, renda_id)
    if renda is None:
        raise RendaNaoEncontrada
    _validar_renda(sessao, descricao, valor, dia_previsto, conta_id, ativa=ativa)
    renda.descricao = descricao
    renda.valor = valor
    renda.dia_previsto = dia_previsto
    renda.conta_id = conta_id
    renda.ativa = ativa
    sessao.commit()
    return RendaComProxima(renda, previa(sessao, dia_previsto, hoje))


def _validar_renda(
    sessao: Session,
    descricao: str,
    valor: Decimal,
    dia_previsto: int,
    conta_id: uuid.UUID,
    *,
    ativa: bool = True,
) -> None:
    """Conta desativada só impede a renda ativa: a inativa não entra no cálculo
    e precisa poder ser desativada mesmo depois que a conta saiu de uso."""
    if not descricao:
        raise CampoInvalido("descricao", "Dê um nome à renda, por exemplo: Salário.")
    if valor <= 0:
        raise CampoInvalido("valor", "O valor precisa ser maior que zero.")
    if not 1 <= dia_previsto <= 31:
        raise CampoInvalido("dia_previsto", "Use um dia de 1 a 31.")
    conta = sessao.get(Conta, conta_id)
    if conta is None or conta.tipo not in _CONTAS_DA_RENDA or (ativa and not conta.ativa):
        raise CampoInvalido("conta_id", "Escolha a conta corrente ou a carteira onde a renda cai.")


def _feriados_ao_redor(sessao: Session, hoje: date) -> dict[date, str]:
    """Do mês anterior ao de hoje até o fim do terceiro mês: cobre a data do
    mês anterior empurrada para este e a do mês seguinte empurrada adiante."""
    inicio = mes_anterior(competencia_de(hoje))
    ultimo_mes = mes_seguinte(mes_seguinte(competencia_de(hoje)))
    fim = ultimo_mes.replace(day=calendar.monthrange(ultimo_mes.year, ultimo_mes.month)[1])
    return feriados_entre(sessao, inicio, fim)


def _proxima_data(dia_previsto: int, hoje: date, feriados: Mapping[date, str]) -> ProximaData:
    """A primeira data efetiva a partir de hoje, entre a do mês anterior (que
    pode ter sido empurrada para este), a deste mês e a do seguinte."""
    mes = mes_anterior(competencia_de(hoje))
    datas = []
    for _ in range(3):
        datas.append(data_do_salario(dia_previsto, mes, feriados.keys()))
        mes = mes_seguinte(mes)
    proxima = min((d for d in datas if d.efetiva >= hoje), key=lambda d: d.efetiva)
    return ProximaData(
        data=proxima.efetiva,
        data_prevista=proxima.prevista,
        feriados={
            dia: nome
            for dia, nome in sorted(feriados.items())
            if proxima.prevista <= dia < proxima.efetiva
        },
    )


def ler_configuracao(sessao: Session, hoje: date) -> LeituraConfiguracao:
    """A configuração salva e o que o cálculo tira do histórico de gastos.

    Reusa `calculo.calcular` sem rendas (sem previsão): o automático sai sem
    configuração, e os meses de reserva, com a configuração salva.
    """
    configuracao = sessao.get(Configuracao, ID_CONFIGURACAO)
    entrada = calculo.EntradaPlanejamento(
        referencia=hoje,
        contas=(),
        rendas=(),
        configuracao=None,
        movimentos=movimentos_recentes(sessao, hoje),
        inicio_historico=inicio_do_historico(sessao),
    )
    automatico = calculo.calcular(entrada)
    salvo = automatico
    if configuracao is not None and configuracao.gasto_mensal_referencia is not None:
        salvo = calculo.calcular(
            replace(entrada, configuracao=configuracao_do_calculo(configuracao))
        )
    return LeituraConfiguracao(
        configuracao=configuracao,
        gasto_mensal_automatico=automatico.gasto_mensal,
        media_semanal_real=automatico.media_semanal_real,
        meses_de_reserva=salvo.meses_de_reserva,
    )


def salvar_configuracao(
    sessao: Session,
    *,
    colchao: Decimal,
    meta_reserva_meses: Decimal,
    gasto_semanal_estimado: Decimal,
    gasto_mensal_referencia: Decimal | None,
    hoje: date,
) -> LeituraConfiguracao:
    """Cria a linha única no primeiro salvamento e a atualiza nos seguintes."""
    if colchao < 0:
        raise CampoInvalido("colchao", "O colchão não pode ser negativo.")
    if gasto_semanal_estimado < 0:
        raise CampoInvalido("gasto_semanal_estimado", "O gasto semanal não pode ser negativo.")
    if meta_reserva_meses <= 0:
        raise CampoInvalido("meta_reserva_meses", "A meta precisa ser maior que zero.")
    if gasto_mensal_referencia is not None and gasto_mensal_referencia <= 0:
        raise CampoInvalido("gasto_mensal_referencia", "O gasto mensal precisa ser maior que zero.")
    configuracao = sessao.get(Configuracao, ID_CONFIGURACAO)
    if configuracao is None:
        configuracao = Configuracao(id=ID_CONFIGURACAO)
        sessao.add(configuracao)
    configuracao.colchao = colchao
    configuracao.meta_reserva_meses = meta_reserva_meses
    configuracao.gasto_semanal_estimado = gasto_semanal_estimado
    configuracao.gasto_mensal_referencia = gasto_mensal_referencia
    sessao.commit()
    return ler_configuracao(sessao, hoje)


def configuracao_do_calculo(configuracao: Configuracao) -> calculo.Configuracao:
    return calculo.Configuracao(
        colchao=configuracao.colchao,
        gasto_semanal_estimado=configuracao.gasto_semanal_estimado,
        gasto_mensal_referencia=configuracao.gasto_mensal_referencia,
    )


def movimentos_recentes(sessao: Session, referencia: date) -> list[calculo.Movimento]:
    """Transações de todas as contas desde o 1º dia do terceiro mês antes da
    referência, com status e marca de duplicata: o filtro é do cálculo."""
    inicio = competencia_de(referencia)
    for _ in range(3):
        inicio = mes_anterior(inicio)
    linhas = sessao.execute(
        select(
            Transacao.conta_id,
            Transacao.tipo,
            Transacao.valor,
            Transacao.data,
            Transacao.status,
            Transacao.possivel_duplicata_de.is_not(None),
        ).where(Transacao.data >= inicio)
    )
    return [
        calculo.Movimento(
            conta_id=conta_id,
            tipo=TipoTransacao(tipo),
            valor=valor,
            data=data,
            status=StatusTransacao(status),
            possivel_duplicata=duplicata,
        )
        for conta_id, tipo, valor, data, status, duplicata in linhas
    ]


def inicio_do_historico(sessao: Session) -> date | None:
    """O gasto (despesa ou estorno) mais antigo que conta no cálculo."""
    return sessao.scalar(
        select(func.min(Transacao.data)).where(
            Transacao.tipo.in_([TipoTransacao.despesa, TipoTransacao.estorno]),
            Transacao.status.in_([StatusTransacao.confirmada, StatusTransacao.rascunho]),
            Transacao.possivel_duplicata_de.is_(None),
        )
    )
