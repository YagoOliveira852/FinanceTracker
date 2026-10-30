"""Cálculo do planejamento: funções puras, sem banco, sem I/O e sem relógio (a
data de referência é parâmetro). Spec `2026-10-19-calculo-aporte-alerta-design.md`.
"""

import calendar
import uuid
from collections.abc import Collection, Sequence
from dataclasses import dataclass, field
from datetime import date, timedelta
from decimal import ROUND_DOWN, ROUND_HALF_UP, ROUND_UP, Decimal
from enum import StrEnum

from app.modulos.cartoes.datas import mes_anterior, mes_seguinte, proximo_dia_util
from app.modulos.contas.models import TipoConta
from app.modulos.transacoes.models import StatusTransacao, TipoTransacao

_CONTAS_DISPONIVEIS = frozenset({TipoConta.corrente, TipoConta.carteira})
_STATUS_QUE_CONTAM = frozenset({StatusTransacao.confirmada, StatusTransacao.rascunho})
_CENTAVO = Decimal("0.01")
_DECIMO = Decimal("0.1")
_MESES_DA_MEDIA = 3
# Gastos previstos: com 4 semanas de histórico, a média real das últimas 8
# semanas pode passar do gasto semanal estimado.
_DIAS_MINIMOS_DE_HISTORICO = 28
_DIAS_DA_MEDIA = 56
# O salário chegou quando cai na conta da renda uma receita de 80% a 120% do
# valor previsto, de 3 dias antes a 5 dias depois da data esperada.
_DIAS_ANTES_DO_SALARIO = 3
_DIAS_DEPOIS_DO_SALARIO = 5
_TOLERANCIA_DO_SALARIO = Decimal("0.20")


class NivelRitmo(StrEnum):
    verde = "verde"  # a sobra cobre o colchão
    amarelo = "amarelo"  # vai consumir o colchão
    vermelho = "vermelho"  # exigiria resgatar a reserva


@dataclass(frozen=True)
class SaldoConta:
    """Saldo de uma conta ativa para o planejamento: confirmadas e rascunhos,
    sem as possíveis duplicatas (o saldo oficial usa só as confirmadas)."""

    tipo: TipoConta
    saldo: Decimal


@dataclass(frozen=True)
class RendaPrevista:
    id: uuid.UUID
    valor: Decimal
    dia_previsto: int
    # Onde o crédito aparece primeiro.
    conta_id: uuid.UUID
    ativa: bool


@dataclass(frozen=True)
class Movimento:
    """Transação de qualquer conta, para o histórico de gastos e a detecção do
    salário. Quem chama passa as do 1º dia do terceiro mês antes da referência em
    diante; o filtro de status é daqui."""

    conta_id: uuid.UUID
    tipo: TipoTransacao
    valor: Decimal
    data: date
    status: StatusTransacao
    # `possivel_duplicata_de` preenchido (só rascunho tem: a revisão limpa).
    possivel_duplicata: bool


@dataclass(frozen=True)
class FaturaEmAberto:
    """Fatura de cartão ativo, gravada ou calculada. Valores como os da tela da
    fatura: calculado com rascunhos e sem ignoradas; pago = os pagamentos ligados."""

    cartao_id: uuid.UUID
    competencia: date
    vencimento: date
    valor_informado: Decimal | None
    valor_calculado: Decimal
    valor_pago: Decimal


@dataclass(frozen=True)
class Configuracao:
    colchao: Decimal
    # Piso dos gastos previstos.
    gasto_semanal_estimado: Decimal
    # Nulo = automático: média dos 3 últimos meses fechados.
    gasto_mensal_referencia: Decimal | None


@dataclass(frozen=True)
class EntradaPlanejamento:
    referencia: date
    contas: Sequence[SaldoConta]
    rendas: Sequence[RendaPrevista]
    configuracao: Configuracao | None
    faturas: Sequence[FaturaEmAberto] = ()
    movimentos: Sequence[Movimento] = ()
    # Primeiro dia com dados de gasto (o gasto mais antigo); nulo = nenhum.
    inicio_historico: date | None = None
    # Saldo dos investimentos marcados como reserva.
    reserva: Decimal = Decimal(0)
    feriados: Collection[date] = field(default_factory=frozenset)


@dataclass(frozen=True)
class DataSalario:
    """Data esperada de uma renda num mês: a prevista (o dia da renda no mês) e
    a efetiva (ajustada para dia útil)."""

    prevista: date
    efetiva: date


@dataclass(frozen=True)
class FaturaReservada:
    """Quanto de uma fatura fica na conta até o próximo salário."""

    cartao_id: uuid.UUID
    competencia: date
    vencimento: date
    valor: Decimal


@dataclass(frozen=True)
class SalarioRecebido:
    """Receita reconhecida como o salário de uma renda: dispara o aporte."""

    renda_id: uuid.UUID
    data_esperada: DataSalario
    data: date
    valor: Decimal


@dataclass(frozen=True)
class Previsao:
    proximo_salario: DataSalario
    # Hoje entra, o dia do salário não.
    dias_ate_salario: int
    # Em ordem de vencimento.
    faturas: list[FaturaReservada]
    gastos_previstos: Decimal
    # Verdadeiro quando a média real das últimas semanas passou do gasto
    # semanal estimado.
    gastos_pela_media: bool
    sobra: Decimal
    nivel: NivelRitmo
    # Salário detectado cuja janela ainda está aberta; o aporte só existe com ele.
    salario_recebido: SalarioRecebido | None
    # Sobra − colchão, nunca negativo: quando não sobra, o alerta assume.
    aporte: Decimal | None
    meses_de_reserva_apos_aporte: Decimal | None


@dataclass(frozen=True)
class GastoMensal:
    """Gasto mensal de referência, que divide a reserva para dar os meses."""

    valor: Decimal
    # Meses fechados da média automática, do mais antigo ao mais recente; vazio
    # quando o valor é o fixo da configuração.
    meses: list[date]


@dataclass(frozen=True)
class Planejamento:
    saldo_disponivel: Decimal
    # Média real das últimas 8 semanas; nula com menos de 4 semanas de histórico.
    media_semanal_real: Decimal | None
    # Nulo sem nenhum mês fechado no histórico.
    gasto_mensal: GastoMensal | None
    # Uma casa, para baixo; nulo sem gasto mensal.
    meses_de_reserva: Decimal | None
    # Nula enquanto não houver renda prevista ativa e configuração.
    previsao: Previsao | None


def data_do_salario(dia_previsto: int, mes: date, feriados: Collection[date]) -> DataSalario:
    """Dia 29 a 31 em mês mais curto vira o último dia do mês; depois, fim de
    semana ou feriado passa para o próximo dia útil."""
    ultimo = calendar.monthrange(mes.year, mes.month)[1]
    prevista = mes.replace(day=min(dia_previsto, ultimo))
    return DataSalario(prevista=prevista, efetiva=proximo_dia_util(prevista, feriados))


def calcular(entrada: EntradaPlanejamento) -> Planejamento:
    saldo_disponivel = sum(
        (conta.saldo for conta in entrada.contas if conta.tipo in _CONTAS_DISPONIVEIS),
        Decimal(0),
    )
    referencia = entrada.referencia
    movimentos = [m for m in entrada.movimentos if _conta_no_calculo(m)]
    media = _media_recente(referencia, entrada.inicio_historico, movimentos)
    media_semanal = None if media is None else _centavos(media.total * 7 / media.dias)

    configuracao = entrada.configuracao
    gasto_mensal = _gasto_mensal(referencia, entrada.inicio_historico, movimentos, configuracao)
    meses_de_reserva = _meses_de_reserva(entrada.reserva, gasto_mensal)

    rendas = [renda for renda in entrada.rendas if renda.ativa]
    if configuracao is None or not rendas:
        return Planejamento(
            saldo_disponivel, media_semanal, gasto_mensal, meses_de_reserva, previsao=None
        )

    ciclos = _ciclos(rendas, referencia, entrada.feriados, movimentos)
    proximo = _proximo_salario(ciclos, referencia)
    recebido = _salario_recebido(ciclos, referencia)
    # Salário atrasado, ainda dentro da janela: chega a qualquer momento.
    dias = max((proximo.efetiva - referencia).days, 0)
    faturas = _faturas_ate(proximo.efetiva, entrada.faturas)
    pelo_piso = configuracao.gasto_semanal_estimado * dias / 7
    pela_media = Decimal(0) if media is None else media.total * dias / media.dias
    gastos_previstos = _centavos_para_cima(max(pelo_piso, pela_media))
    sobra = saldo_disponivel - sum((f.valor for f in faturas), Decimal(0)) - gastos_previstos
    aporte = None if recebido is None else max(sobra - configuracao.colchao, Decimal(0))
    return Planejamento(
        saldo_disponivel=saldo_disponivel,
        media_semanal_real=media_semanal,
        gasto_mensal=gasto_mensal,
        meses_de_reserva=meses_de_reserva,
        previsao=Previsao(
            proximo_salario=proximo,
            dias_ate_salario=dias,
            faturas=faturas,
            gastos_previstos=gastos_previstos,
            gastos_pela_media=pela_media > pelo_piso,
            sobra=sobra,
            nivel=_nivel(sobra, configuracao.colchao),
            salario_recebido=recebido,
            aporte=aporte,
            meses_de_reserva_apos_aporte=(
                None
                if aporte is None
                else _meses_de_reserva(entrada.reserva + aporte, gasto_mensal)
            ),
        ),
    )


@dataclass(frozen=True)
class _Media:
    total: Decimal
    dias: int


def _conta_no_calculo(movimento: Movimento) -> bool:
    """Confirmadas e rascunhos entram; ignoradas e possíveis duplicatas, não."""
    return movimento.status in _STATUS_QUE_CONTAM and not movimento.possivel_duplicata


def _valor_de_gasto(movimento: Movimento) -> Decimal:
    """Gasto = despesa − estorno. Pagamento de fatura, transferência, aporte,
    resgate e ajuste não são gasto."""
    if movimento.tipo == TipoTransacao.despesa:
        return movimento.valor
    if movimento.tipo == TipoTransacao.estorno:
        return -movimento.valor
    return Decimal(0)


def _gasto_entre(movimentos: Sequence[Movimento], inicio: date, fim: date) -> Decimal:
    """Gasto de `inicio` a `fim`, inclusive."""
    return sum((_valor_de_gasto(m) for m in movimentos if inicio <= m.data <= fim), Decimal(0))


def _media_recente(
    referencia: date, inicio_historico: date | None, movimentos: Sequence[Movimento]
) -> _Media | None:
    """Gasto das últimas 8 semanas antes de hoje (hoje ainda não terminou), pelos
    dias que o histórico tem. Nula com menos de 4 semanas de histórico."""
    if inicio_historico is None:
        return None
    dias = min((referencia - inicio_historico).days, _DIAS_DA_MEDIA)
    if dias < _DIAS_MINIMOS_DE_HISTORICO:
        return None
    total = _gasto_entre(
        movimentos, referencia - timedelta(days=dias), referencia - timedelta(days=1)
    )
    return _Media(total=total, dias=dias)


def _gasto_mensal(
    referencia: date,
    inicio_historico: date | None,
    movimentos: Sequence[Movimento],
    configuracao: Configuracao | None,
) -> GastoMensal | None:
    """O valor fixo da configuração ou a média dos 3 últimos meses fechados.

    Na média só entra mês inteiro dentro do histórico: um mês pela metade
    puxaria a média para baixo.
    """
    if configuracao is not None and configuracao.gasto_mensal_referencia is not None:
        return GastoMensal(valor=configuracao.gasto_mensal_referencia, meses=[])
    if inicio_historico is None:
        return None
    meses = []
    mes = referencia.replace(day=1)
    for _ in range(_MESES_DA_MEDIA):
        mes = mes_anterior(mes)
        if mes >= inicio_historico:
            meses.insert(0, mes)
    if not meses:
        return None
    total = sum(
        (_gasto_entre(movimentos, mes, mes_seguinte(mes) - timedelta(days=1)) for mes in meses),
        Decimal(0),
    )
    return GastoMensal(valor=_centavos(total / len(meses)), meses=meses)


def _meses_de_reserva(reserva: Decimal, gasto_mensal: GastoMensal | None) -> Decimal | None:
    if gasto_mensal is None or gasto_mensal.valor <= 0:
        return None
    return (reserva / gasto_mensal.valor).quantize(_DECIMO, rounding=ROUND_DOWN)


@dataclass(frozen=True)
class _Ciclo:
    """Uma data esperada de uma renda e o crédito reconhecido como o salário dela."""

    renda: RendaPrevista
    data: DataSalario
    credito: Movimento | None

    @property
    def fim_da_janela(self) -> date:
        return self.data.efetiva + timedelta(days=_DIAS_DEPOIS_DO_SALARIO)


def _ciclos(
    rendas: Sequence[RendaPrevista],
    referencia: date,
    feriados: Collection[date],
    movimentos: Sequence[Movimento],
) -> list[_Ciclo]:
    """Do mês anterior ao de `referencia` até dois meses depois: o salário do
    fim do mês anterior pode ser ajustado para este, e o deste pode chegar
    adiantado e deixar o próximo salário no outro mês.

    Um crédito é o salário de um ciclo só: as datas esperadas pegam os créditos
    na ordem, a mais cedo primeiro (duas rendas na mesma conta, com dias
    próximos e valores parecidos, teriam janelas que se cruzam).
    """
    datas = []
    for renda in rendas:
        mes = mes_anterior(referencia.replace(day=1))
        for _ in range(4):
            datas.append((renda, data_do_salario(renda.dia_previsto, mes, feriados)))
            mes = mes_seguinte(mes)
    datas.sort(key=lambda par: (par[1].efetiva, str(par[0].id)))

    livres = list(movimentos)
    ciclos = []
    for renda, data in datas:
        credito = _credito_do_salario(renda, data.efetiva, referencia, livres)
        if credito is not None:
            livres.remove(credito)
        ciclos.append(_Ciclo(renda=renda, data=data, credito=credito))
    return ciclos


def _credito_do_salario(
    renda: RendaPrevista, esperada: date, referencia: date, movimentos: Sequence[Movimento]
) -> Movimento | None:
    inicio = esperada - timedelta(days=_DIAS_ANTES_DO_SALARIO)
    fim = min(esperada + timedelta(days=_DIAS_DEPOIS_DO_SALARIO), referencia)
    tolerancia = renda.valor * _TOLERANCIA_DO_SALARIO
    creditos = [
        m
        for m in movimentos
        if m.tipo == TipoTransacao.receita
        and m.conta_id == renda.conta_id
        and inicio <= m.data <= fim
        and abs(m.valor - renda.valor) <= tolerancia
    ]
    return min(creditos, key=lambda m: m.data, default=None)


def _proximo_salario(ciclos: Sequence[_Ciclo], referencia: date) -> DataSalario:
    """A data esperada mais próxima ainda sem crédito cuja janela não acabou.

    Salário adiantado já leva ao seguinte; salário atrasado continua sendo o
    próximo até o fim da janela, e depois disso o cálculo passa para o seguinte.
    """
    pendentes = [c.data for c in ciclos if c.credito is None and c.fim_da_janela >= referencia]
    return min(pendentes, key=lambda data: data.efetiva)


def _salario_recebido(ciclos: Sequence[_Ciclo], referencia: date) -> SalarioRecebido | None:
    """O crédito mais recente cuja janela ainda está aberta."""
    abertos = [c for c in ciclos if c.credito is not None and referencia <= c.fim_da_janela]
    if not abertos:
        return None
    ciclo = max(abertos, key=lambda c: c.credito.data)
    return SalarioRecebido(
        renda_id=ciclo.renda.id,
        data_esperada=ciclo.data,
        data=ciclo.credito.data,
        valor=ciclo.credito.valor,
    )


def _faturas_ate(salario: date, faturas: Sequence[FaturaEmAberto]) -> list[FaturaReservada]:
    """Faturas que vencem até o salário, inclusive (as vencidas também), pelo que
    falta pagar do maior entre o valor informado e o calculado. O que já foi pago
    saiu do saldo disponível."""
    reservadas = []
    for fatura in sorted(faturas, key=lambda f: (f.vencimento, str(f.cartao_id))):
        valor = max(fatura.valor_informado or Decimal(0), fatura.valor_calculado)
        falta = valor - fatura.valor_pago
        if fatura.vencimento <= salario and falta > 0:
            reservadas.append(
                FaturaReservada(fatura.cartao_id, fatura.competencia, fatura.vencimento, falta)
            )
    return reservadas


def _nivel(sobra: Decimal, colchao: Decimal) -> NivelRitmo:
    if sobra >= colchao:
        return NivelRitmo.verde
    if sobra >= 0:
        return NivelRitmo.amarelo
    return NivelRitmo.vermelho


def _centavos(valor: Decimal) -> Decimal:
    return valor.quantize(_CENTAVO, rounding=ROUND_HALF_UP)


def _centavos_para_cima(valor: Decimal) -> Decimal:
    return valor.quantize(_CENTAVO, rounding=ROUND_UP)
