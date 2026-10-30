"""Cálculo do planejamento: data do salário, aporte, alerta de ritmo e meses de
reserva (spec `2026-10-19-calculo-aporte-alerta-design.md`). Valores fictícios."""

import uuid
from datetime import date, timedelta
from decimal import Decimal

import pytest

from app.modulos.contas.models import TipoConta
from app.modulos.planejamento.calculo import (
    Configuracao,
    DataSalario,
    EntradaPlanejamento,
    FaturaEmAberto,
    FaturaReservada,
    GastoMensal,
    Movimento,
    NivelRitmo,
    RendaPrevista,
    SalarioRecebido,
    SaldoConta,
    calcular,
    data_do_salario,
)
from app.modulos.transacoes.models import StatusTransacao, TipoTransacao

# Feriados nacionais de verdade (não são dado pessoal).
FERIADOS = {
    date(2026, 10, 12),
    date(2026, 11, 2),
    date(2026, 11, 15),
    date(2026, 11, 20),
    date(2026, 12, 25),
    date(2027, 1, 1),
}


@pytest.mark.parametrize(
    ("dia", "mes", "prevista", "efetiva"),
    [
        (10, date(2026, 11, 1), date(2026, 11, 10), date(2026, 11, 10)),  # terça: dia útil
        (15, date(2026, 11, 1), date(2026, 11, 15), date(2026, 11, 16)),  # domingo e feriado
        (12, date(2026, 10, 1), date(2026, 10, 12), date(2026, 10, 13)),  # feriado numa segunda
        (31, date(2027, 2, 1), date(2027, 2, 28), date(2027, 3, 1)),  # mês curto, e é domingo
        (30, date(2026, 11, 1), date(2026, 11, 30), date(2026, 11, 30)),  # o dia existe
        (31, date(2026, 12, 1), date(2026, 12, 31), date(2026, 12, 31)),  # quinta
        (25, date(2026, 12, 1), date(2026, 12, 25), date(2026, 12, 28)),  # Natal numa sexta
    ],
)
def test_data_do_salario(dia, mes, prevista, efetiva):
    assert data_do_salario(dia, mes, FERIADOS) == DataSalario(prevista=prevista, efetiva=efetiva)


CONTA_SALARIO = uuid.uuid4()
CARTAO = uuid.uuid4()
CONTA_DIA_A_DIA = uuid.uuid4()
REFERENCIA = date(2026, 10, 20)

CONFIGURACAO = Configuracao(
    colchao=Decimal("500.00"),
    gasto_semanal_estimado=Decimal("280.00"),
    gasto_mensal_referencia=None,
)


def _renda(**campos) -> RendaPrevista:
    padrao = {
        "id": uuid.uuid4(),
        "valor": Decimal("4200.00"),
        "dia_previsto": 10,
        "conta_id": CONTA_SALARIO,
        "ativa": True,
    }
    return RendaPrevista(**(padrao | campos))


def _entrada(**campos) -> EntradaPlanejamento:
    padrao = {
        "referencia": date(2026, 10, 20),
        "contas": [SaldoConta(TipoConta.corrente, Decimal("3180.10"))],
        "rendas": [_renda()],
        "configuracao": CONFIGURACAO,
        "feriados": FERIADOS,
    }
    return EntradaPlanejamento(**(padrao | campos))


def test_saldo_disponivel_soma_correntes_e_carteiras_sem_cartao():
    contas = [
        SaldoConta(TipoConta.corrente, Decimal("2000.00")),
        SaldoConta(TipoConta.corrente, Decimal("-150.25")),
        SaldoConta(TipoConta.carteira, Decimal("80.50")),
        SaldoConta(TipoConta.cartao_credito, Decimal("-900.00")),
    ]
    assert calcular(_entrada(contas=contas)).saldo_disponivel == Decimal("1930.25")


@pytest.mark.parametrize(
    "campos",
    [
        {"configuracao": None},
        {"rendas": []},
        {"rendas": [_renda(ativa=False)]},
    ],
    ids=["sem configuracao", "sem renda", "so renda inativa"],
)
def test_sem_configuracao_ou_renda_ativa_nao_ha_previsao(campos):
    planejamento = calcular(_entrada(**campos))

    assert planejamento.previsao is None
    assert planejamento.saldo_disponivel == Decimal("3180.10")


def test_sem_historico_os_gastos_previstos_usam_o_gasto_semanal_estimado():
    previsao = calcular(_entrada()).previsao

    assert previsao.proximo_salario == DataSalario(date(2026, 11, 10), date(2026, 11, 10))
    assert previsao.dias_ate_salario == 21
    assert previsao.gastos_previstos == Decimal("840.00")  # R$ 40,00 por dia
    assert previsao.gastos_pela_media is False
    assert previsao.sobra == Decimal("2340.10")
    assert previsao.nivel == NivelRitmo.verde


@pytest.mark.parametrize(
    ("saldo", "sobra", "nivel"),
    [
        ("1340.00", "500.00", NivelRitmo.verde),  # a sobra cobre o colchão
        ("1339.99", "499.99", NivelRitmo.amarelo),
        ("840.00", "0.00", NivelRitmo.amarelo),
        ("839.99", "-0.01", NivelRitmo.vermelho),  # exigiria resgatar a reserva
    ],
)
def test_nivel_do_ritmo_pela_sobra_e_o_colchao(saldo, sobra, nivel):
    contas = [SaldoConta(TipoConta.corrente, Decimal(saldo))]
    previsao = calcular(_entrada(contas=contas)).previsao

    assert previsao.sobra == Decimal(sobra)
    assert previsao.nivel == nivel


def _fatura(vencimento: date, **campos) -> FaturaEmAberto:
    padrao = {
        "cartao_id": CARTAO,
        "competencia": vencimento.replace(day=1),
        "vencimento": vencimento,
        "valor_informado": None,
        "valor_calculado": Decimal("1032.15"),
        "valor_pago": Decimal("0"),
    }
    return FaturaEmAberto(**(padrao | campos))


def test_exemplo_do_design_no_ritmo():
    previsao = calcular(_entrada(faturas=[_fatura(date(2026, 11, 10))])).previsao

    assert previsao.faturas == [
        FaturaReservada(CARTAO, date(2026, 11, 1), date(2026, 11, 10), Decimal("1032.15"))
    ]
    assert previsao.sobra == Decimal("1307.95")  # 3.180,10 − 1.032,15 − 840,00
    assert previsao.nivel == NivelRitmo.verde


@pytest.mark.parametrize(
    ("campos", "reservado"),
    [
        ({"vencimento": date(2026, 11, 10)}, "1032.15"),  # vence no dia do salário: entra
        ({"vencimento": date(2026, 10, 15)}, "1032.15"),  # vencida e não paga: entra
        ({"vencimento": date(2026, 11, 11)}, None),  # vence depois do salário
        ({"valor_informado": Decimal("1100.00")}, "1100.00"),  # o maior: informado
        ({"valor_informado": Decimal("900.00")}, "1032.15"),  # o maior: calculado
        ({"valor_pago": Decimal("132.15")}, "900.00"),  # pagamento parcial já saiu do saldo
        ({"valor_pago": Decimal("1032.15")}, None),  # paga
        ({"valor_pago": Decimal("1600.00")}, None),  # paga a mais: não vira crédito
    ],
)
def test_fatura_reserva_o_que_falta_pagar_ate_o_salario(campos, reservado):
    fatura = _fatura(**({"vencimento": date(2026, 11, 10)} | campos))
    previsao = calcular(_entrada(faturas=[fatura])).previsao

    assert [f.valor for f in previsao.faturas] == ([Decimal(reservado)] if reservado else [])
    total = Decimal(reservado) if reservado else Decimal(0)
    assert previsao.sobra == Decimal("2340.10") - total


def test_faturas_reservadas_em_ordem_de_vencimento():
    outro_cartao = uuid.uuid4()
    faturas = [
        _fatura(date(2026, 11, 10)),
        _fatura(date(2026, 10, 26), cartao_id=outro_cartao, valor_calculado=Decimal("50.00")),
    ]
    previsao = calcular(_entrada(faturas=faturas)).previsao

    assert [f.cartao_id for f in previsao.faturas] == [outro_cartao, CARTAO]
    assert previsao.sobra == Decimal("1257.95")


def _movimento(data: date, valor: str, **campos) -> Movimento:
    padrao = {
        "conta_id": CONTA_DIA_A_DIA,
        "tipo": TipoTransacao.despesa,
        "valor": Decimal(valor),
        "data": data,
        "status": StatusTransacao.confirmada,
        "possivel_duplicata": False,
    }
    return Movimento(**(padrao | campos))


def _dias_atras(dias: int) -> date:
    return REFERENCIA - timedelta(days=dias)


def _gastos_por_semana(semanal: str, semanas: int = 8) -> list[Movimento]:
    """Um gasto por semana, dentro das últimas `semanas` semanas antes de hoje."""
    return [_movimento(_dias_atras(7 * semana + 1), semanal) for semana in range(semanas)]


def test_media_recente_acima_do_gasto_semanal_estimado_vira_os_gastos_previstos():
    entrada = _entrada(
        faturas=[_fatura(date(2026, 11, 10))],
        movimentos=_gastos_por_semana("600.00"),
        inicio_historico=_dias_atras(90),
    )
    planejamento = calcular(entrada)

    assert planejamento.media_semanal_real == Decimal("600.00")
    assert planejamento.previsao.gastos_previstos == Decimal("1800.00")  # 21 × 600 / 7
    assert planejamento.previsao.gastos_pela_media is True
    assert planejamento.previsao.sobra == Decimal("347.95")
    assert planejamento.previsao.nivel == NivelRitmo.amarelo


def test_media_recente_abaixo_do_piso_fica_com_o_gasto_semanal_estimado():
    entrada = _entrada(movimentos=_gastos_por_semana("252.00"), inicio_historico=_dias_atras(90))
    planejamento = calcular(entrada)

    assert planejamento.media_semanal_real == Decimal("252.00")
    assert planejamento.previsao.gastos_previstos == Decimal("840.00")
    assert planejamento.previsao.gastos_pela_media is False


@pytest.mark.parametrize(
    ("inicio", "media", "gastos_previstos"),
    [
        (None, None, "840.00"),  # sem nenhum gasto
        (_dias_atras(27), None, "840.00"),  # menos de 4 semanas: só o piso
        (_dias_atras(28), "1200.00", "3600.00"),  # 4 semanas: média dos 28 dias
        (_dias_atras(42), "800.00", "2400.00"),  # 6 semanas: média dos 42 dias
        (_dias_atras(56), "600.00", "1800.00"),
        (_dias_atras(400), "600.00", "1800.00"),  # nunca mais que 8 semanas
    ],
)
def test_historico_curto_divide_pelos_dias_que_existem(inicio, media, gastos_previstos):
    # R$ 4.800,00 de gasto nos últimos 28 dias, nada antes.
    movimentos = _gastos_por_semana("1200.00", semanas=4)
    planejamento = calcular(_entrada(movimentos=movimentos, inicio_historico=inicio))

    assert planejamento.media_semanal_real == (Decimal(media) if media else None)
    assert planejamento.previsao.gastos_previstos == Decimal(gastos_previstos)


@pytest.mark.parametrize(
    ("movimento", "conta"),
    [
        (_movimento(_dias_atras(3), "100.00"), True),
        (_movimento(_dias_atras(3), "100.00", status=StatusTransacao.rascunho), True),
        (_movimento(_dias_atras(3), "100.00", conta_id=CARTAO), True),  # compra no cartão
        (_movimento(_dias_atras(56), "100.00"), True),  # primeiro dia da janela
        (_movimento(_dias_atras(57), "100.00"), False),  # antes da janela
        (_movimento(REFERENCIA, "100.00"), False),  # hoje ainda não terminou
        (_movimento(_dias_atras(3), "100.00", status=StatusTransacao.ignorada), False),
        (
            _movimento(
                _dias_atras(3), "100.00", status=StatusTransacao.rascunho, possivel_duplicata=True
            ),
            False,
        ),
        (_movimento(_dias_atras(3), "100.00", tipo=TipoTransacao.pagamento_fatura), False),
        (_movimento(_dias_atras(3), "100.00", tipo=TipoTransacao.transferencia_saida), False),
        (_movimento(_dias_atras(3), "100.00", tipo=TipoTransacao.aporte), False),
        (_movimento(_dias_atras(3), "100.00", tipo=TipoTransacao.ajuste_saida), False),
        (_movimento(_dias_atras(3), "100.00", tipo=TipoTransacao.receita), False),
    ],
)
def test_o_que_conta_como_gasto(movimento, conta):
    base = _gastos_por_semana("560.00")  # R$ 80,00 por dia
    planejamento = calcular(
        _entrada(movimentos=[*base, movimento], inicio_historico=_dias_atras(90))
    )

    # R$ 100,00 a mais em 56 dias são R$ 12,50 por semana.
    assert planejamento.media_semanal_real == Decimal("572.50" if conta else "560.00")


def test_estorno_desconta_do_gasto():
    estorno = _movimento(_dias_atras(3), "560.00", tipo=TipoTransacao.estorno)
    movimentos = [*_gastos_por_semana("560.00"), estorno]
    planejamento = calcular(_entrada(movimentos=movimentos, inicio_historico=_dias_atras(90)))

    assert planejamento.media_semanal_real == Decimal("490.00")


NOV_10 = DataSalario(date(2026, 11, 10), date(2026, 11, 10))
DEZ_10 = DataSalario(date(2026, 12, 10), date(2026, 12, 10))


def _salario(data: date, valor: str = "4200.00", **campos) -> Movimento:
    return _movimento(
        data, valor, **({"conta_id": CONTA_SALARIO, "tipo": TipoTransacao.receita} | campos)
    )


def test_exemplo_do_design_salario_chegou():
    renda = _renda()
    entrada = _entrada(
        referencia=date(2026, 11, 10),
        contas=[SaldoConta(TipoConta.corrente, Decimal("5430.10"))],
        rendas=[renda],
        faturas=[_fatura(date(2026, 12, 10), valor_calculado=Decimal("1410.30"))],
        movimentos=[_salario(date(2026, 11, 10))],
    )
    previsao = calcular(entrada).previsao

    assert previsao.salario_recebido == SalarioRecebido(
        renda_id=renda.id, data_esperada=NOV_10, data=date(2026, 11, 10), valor=Decimal("4200.00")
    )
    assert previsao.proximo_salario == DEZ_10
    assert previsao.dias_ate_salario == 30
    assert previsao.gastos_previstos == Decimal("1200.00")
    assert previsao.aporte == Decimal("2319.80")  # 5.430,10 − 1.410,30 − 1.200,00 − 500,00


def test_sem_salario_detectado_nao_ha_aporte():
    previsao = calcular(_entrada()).previsao

    assert previsao.salario_recebido is None
    assert previsao.aporte is None


def test_aporte_negativo_vira_zero_e_o_alerta_assume():
    entrada = _entrada(
        referencia=date(2026, 11, 10),
        contas=[SaldoConta(TipoConta.corrente, Decimal("1450.00"))],
        movimentos=[_salario(date(2026, 11, 10))],
    )
    previsao = calcular(entrada).previsao

    assert previsao.sobra == Decimal("250.00")  # 1.450,00 − 1.200,00
    assert previsao.aporte == Decimal("0")
    assert previsao.nivel == NivelRitmo.amarelo


@pytest.mark.parametrize(
    ("referencia", "credito", "recebido", "proximo", "dias"),
    [
        # Esperado em 10/nov. A receita conta de 3 dias antes a 5 dias depois.
        (date(2026, 11, 7), date(2026, 11, 7), True, DEZ_10, 33),  # adiantado: já olha dez
        (date(2026, 11, 6), date(2026, 11, 6), False, NOV_10, 4),  # cedo demais
        (date(2026, 11, 15), date(2026, 11, 15), True, DEZ_10, 25),  # atrasado, na janela
        (date(2026, 11, 12), None, False, NOV_10, 0),  # atrasado: ainda o espera
        (date(2026, 11, 15), None, False, NOV_10, 0),  # último dia da janela
        (date(2026, 11, 16), None, False, DEZ_10, 24),  # não chegou: passa para o seguinte
        (date(2026, 11, 16), date(2026, 11, 10), False, DEZ_10, 24),  # a sugestão acabou
        (date(2026, 11, 16), date(2026, 11, 16), False, DEZ_10, 24),  # fora da janela
        (date(2026, 11, 7), date(2026, 10, 13), False, NOV_10, 3),  # o do mês passado
    ],
)
def test_janela_de_deteccao_do_salario(referencia, credito, recebido, proximo, dias):
    movimentos = [_salario(credito)] if credito else []
    previsao = calcular(_entrada(referencia=referencia, movimentos=movimentos)).previsao

    assert (previsao.salario_recebido is not None) is recebido
    assert previsao.proximo_salario == proximo
    assert previsao.dias_ate_salario == dias


@pytest.mark.parametrize(
    ("credito", "recebido"),
    [
        (_salario(date(2026, 11, 10), "3360.00"), True),  # 80% do previsto
        (_salario(date(2026, 11, 10), "3359.99"), False),
        (_salario(date(2026, 11, 10), "5040.00"), True),  # 120%
        (_salario(date(2026, 11, 10), "5040.01"), False),
        (_salario(date(2026, 11, 10), status=StatusTransacao.rascunho), True),
        (_salario(date(2026, 11, 10), status=StatusTransacao.ignorada), False),
        (
            _salario(date(2026, 11, 10), status=StatusTransacao.rascunho, possivel_duplicata=True),
            False,
        ),
        (_salario(date(2026, 11, 10), conta_id=CONTA_DIA_A_DIA), False),  # outra conta
        (_salario(date(2026, 11, 10), tipo=TipoTransacao.transferencia_entrada), False),
    ],
)
def test_receita_que_conta_como_salario(credito, recebido):
    entrada = _entrada(referencia=date(2026, 11, 10), movimentos=[credito])

    assert (calcular(entrada).previsao.salario_recebido is not None) is recebido


def test_com_duas_rendas_o_proximo_salario_e_o_da_outra():
    primeira = _renda(dia_previsto=6, valor=Decimal("1800.00"))
    segunda = _renda(dia_previsto=20, valor=Decimal("2400.00"))
    entrada = _entrada(
        referencia=date(2026, 11, 6),
        rendas=[primeira, segunda],
        movimentos=[_salario(date(2026, 11, 6), "1800.00")],
    )
    previsao = calcular(entrada).previsao

    assert previsao.salario_recebido.renda_id == primeira.id
    # 20/11 é feriado numa sexta.
    assert previsao.proximo_salario == DataSalario(date(2026, 11, 20), date(2026, 11, 23))
    assert previsao.dias_ate_salario == 17


JUL, AGO, SET = date(2026, 7, 1), date(2026, 8, 1), date(2026, 9, 1)

# Gasto por mês fechado (o de outubro é o mês corrente e não entra).
GASTOS_POR_MES = [
    _movimento(date(2026, 6, 15), "9000.00"),
    _movimento(date(2026, 7, 3), "2000.00"),
    _movimento(date(2026, 7, 31), "800.00"),
    _movimento(date(2026, 8, 1), "3000.00"),
    _movimento(date(2026, 9, 30), "3200.00"),
    _movimento(date(2026, 10, 5), "9000.00"),
]


@pytest.mark.parametrize(
    ("inicio", "valor", "meses"),
    [
        (date(2026, 6, 1), "3000.00", [JUL, AGO, SET]),  # 2.800, 3.000 e 3.200
        (date(2026, 8, 1), "3100.00", [AGO, SET]),  # só os meses que existem
        (date(2026, 8, 2), "3200.00", [SET]),  # agosto pela metade não entra
        (date(2026, 10, 1), None, None),  # nenhum mês fechado
        (None, None, None),
    ],
)
def test_gasto_mensal_automatico_e_a_media_dos_3_ultimos_meses_fechados(inicio, valor, meses):
    entrada = _entrada(movimentos=GASTOS_POR_MES, inicio_historico=inicio)

    esperado = GastoMensal(Decimal(valor), meses) if valor else None
    assert calcular(entrada).gasto_mensal == esperado


def test_gasto_mensal_automatico_tambem_sem_configuracao():
    entrada = _entrada(configuracao=None, movimentos=GASTOS_POR_MES, inicio_historico=JUL)

    assert calcular(entrada).gasto_mensal == GastoMensal(Decimal("3000.00"), [JUL, AGO, SET])


def test_gasto_mensal_fixo_vem_da_configuracao():
    configuracao = Configuracao(
        colchao=Decimal("500.00"),
        gasto_semanal_estimado=Decimal("280.00"),
        gasto_mensal_referencia=Decimal("2500.00"),
    )
    entrada = _entrada(configuracao=configuracao, movimentos=GASTOS_POR_MES, inicio_historico=JUL)

    assert calcular(entrada).gasto_mensal == GastoMensal(Decimal("2500.00"), [])


def test_media_mensal_arredonda_ao_centavo():
    movimentos = [
        _movimento(date(2026, 7, 10), "1100.00"),
        _movimento(date(2026, 8, 10), "1100.00"),
        _movimento(date(2026, 9, 10), "1100.02"),
    ]
    entrada = _entrada(movimentos=movimentos, inicio_historico=JUL)

    assert calcular(entrada).gasto_mensal.valor == Decimal("1100.01")


@pytest.mark.parametrize(
    ("reserva", "meses"),
    [
        ("12600.00", "4.2"),  # exemplo do design: R$ 12.600,00 para R$ 3.000,00 por mês
        ("12899.99", "4.2"),  # arredonda para baixo
        ("11999.99", "3.9"),
        ("0", "0.0"),
    ],
)
def test_meses_de_reserva(reserva, meses):
    entrada = _entrada(reserva=Decimal(reserva), movimentos=GASTOS_POR_MES, inicio_historico=JUL)

    assert calcular(entrada).meses_de_reserva == Decimal(meses)


@pytest.mark.parametrize(
    "campos",
    [
        {"inicio_historico": None},  # sem gasto mensal
        {"movimentos": [], "inicio_historico": JUL},  # gasto mensal zero
    ],
)
def test_sem_gasto_mensal_nao_ha_meses_de_reserva(campos):
    entrada = _entrada(reserva=Decimal("12600.00"), **({"movimentos": GASTOS_POR_MES} | campos))

    assert calcular(entrada).meses_de_reserva is None


def test_meses_de_reserva_depois_do_aporte():
    configuracao = Configuracao(
        colchao=Decimal("500.00"),
        gasto_semanal_estimado=Decimal("280.00"),
        gasto_mensal_referencia=Decimal("3000.00"),
    )
    entrada = _entrada(
        referencia=date(2026, 11, 10),
        contas=[SaldoConta(TipoConta.corrente, Decimal("5430.10"))],
        configuracao=configuracao,
        faturas=[_fatura(date(2026, 12, 10), valor_calculado=Decimal("1410.30"))],
        movimentos=[_salario(date(2026, 11, 10))],
        reserva=Decimal("12600.00"),
    )
    planejamento = calcular(entrada)

    assert planejamento.previsao.aporte == Decimal("2319.80")
    assert planejamento.meses_de_reserva == Decimal("4.2")
    # (12.600,00 + 2.319,80) / 3.000,00 = 4,97
    assert planejamento.previsao.meses_de_reserva_apos_aporte == Decimal("4.9")


def test_sem_aporte_nao_ha_meses_depois_do_aporte():
    entrada = _entrada(reserva=Decimal("12600.00"), movimentos=GASTOS_POR_MES, inicio_historico=JUL)

    assert calcular(entrada).previsao.meses_de_reserva_apos_aporte is None


def test_um_credito_e_o_salario_de_uma_renda_so():
    # Mesma conta, janelas que se cruzam (6/nov e 9/nov) e valores parecidos.
    primeira = _renda(dia_previsto=6, valor=Decimal("2000.00"))
    segunda = _renda(dia_previsto=9, valor=Decimal("2100.00"))
    entrada = _entrada(
        referencia=date(2026, 11, 7),
        rendas=[segunda, primeira],
        movimentos=[_salario(date(2026, 11, 6), "2050.00")],
    )
    previsao = calcular(entrada).previsao

    assert previsao.salario_recebido.renda_id == primeira.id  # a data esperada mais cedo
    assert previsao.proximo_salario == DataSalario(date(2026, 11, 9), date(2026, 11, 9))
