"""Resumo do planejamento pela API: o que o Início mostra (sobra, alerta,
aporte, rascunhos considerados, gasto mensal e meta da reserva), calculado por
`planejamento/calculo.py` a partir do banco.

Hoje = 2026-10-20 (terça). A renda do dia 10 já passou (10/10 é sábado e 12/10
é feriado: caiu em 13/10, e a janela acabou em 18/10), então o próximo salário
é 10/11 (terça): 21 dias de gasto a R$ 40,00 por dia (R$ 280,00 por semana).
Valores fictícios.
"""

from datetime import date
from decimal import Decimal

import pytest

from app.modulos.cartoes import service as cartoes_service
from app.modulos.planejamento.models import ID_CONFIGURACAO, Configuracao, RendaPrevista
from tests.utils import HOJE, criar_conta, criar_transacao


@pytest.fixture
def conta(sessao):
    conta = criar_conta(sessao)
    conta.saldo_inicial = Decimal("3210.10")
    return conta


@pytest.fixture
def rascunhos(sessao, conta):
    """Dois rascunhos (R$ 10,00 e R$ 20,00) e a possível duplicata do primeiro,
    que fica fora do saldo e da contagem: saldo de R$ 3.180,10."""
    original = criar_transacao(sessao, conta, valor=Decimal("10.00"))
    criar_transacao(sessao, conta, valor=Decimal("20.00"), data=date(2026, 10, 18))
    criar_transacao(
        sessao, conta, valor=Decimal("10.00"), fonte="ofx", possivel_duplicata_de=original.id
    )


def _configurar(sessao, **mudancas) -> Configuracao:
    dados = {
        "colchao": Decimal("500.00"),
        "meta_reserva_meses": Decimal("6.0"),
        "gasto_semanal_estimado": Decimal("280.00"),
        "gasto_mensal_referencia": None,
    }
    configuracao = Configuracao(id=ID_CONFIGURACAO, **(dados | mudancas))
    sessao.add(configuracao)
    sessao.flush()
    return configuracao


def _renda(sessao, conta, dia: int = 10, **mudancas) -> RendaPrevista:
    dados = {"descricao": "Salário", "valor": Decimal("4200.00"), "dia_previsto": dia}
    renda = RendaPrevista(conta_id=conta.id, **(dados | mudancas))
    sessao.add(renda)
    sessao.flush()
    return renda


def _cartao(sessao, conta, nome: str = "Cartão Exemplo"):
    return cartoes_service.criar_cartao(
        sessao,
        nome=nome,
        nome_instituicao=f"Banco de {nome}",
        conta_pagamento_id=conta.id,
        dia_fechamento=3,
        dia_vencimento=10,
        limite=None,
        hoje=HOJE,
    )


def _fatura(sessao, cartao, competencia: date, valor: str):
    fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, competencia)
    fatura.valor_informado = Decimal(valor)
    sessao.flush()
    return fatura


def test_sem_renda_nem_configuracao_so_o_saldo_e_os_rascunhos(api, rascunhos):
    resposta = api.get("/planejamento/resumo")

    assert resposta.status_code == 200, resposta.json()
    assert resposta.json() == {
        "saldo_disponivel": "3180.10",
        "rascunhos": 2,
        "previsao": None,
        "gasto_mensal": None,
        "meta_reserva_meses": None,
    }


def test_sem_configuracao_nao_ha_previsao(api, sessao, conta):
    _renda(sessao, conta)

    assert api.get("/planejamento/resumo").json()["previsao"] is None


def test_renda_inativa_nao_entra(api, sessao, conta):
    _configurar(sessao)
    _renda(sessao, conta, ativa=False)

    resumo = api.get("/planejamento/resumo").json()

    assert resumo["previsao"] is None
    assert resumo["meta_reserva_meses"] == "6.0"


def test_no_ritmo_mostra_a_sobra_ate_o_proximo_salario(api, sessao, conta, rascunhos):
    _configurar(sessao)
    _renda(sessao, conta)
    cartao = _cartao(sessao, conta)
    novembro = _fatura(sessao, cartao, date(2026, 11, 1), "1032.15")
    # Vence depois do salário: fica para o seguinte.
    _fatura(sessao, cartao, date(2026, 12, 1), "700.00")

    resposta = api.get("/planejamento/resumo")

    assert resposta.status_code == 200, resposta.json()
    assert resposta.json() == {
        "saldo_disponivel": "3180.10",
        "rascunhos": 2,
        "previsao": {
            "proximo_salario": "2026-11-10",
            "dias_ate_salario": 21,
            "faturas": [
                {
                    "cartao_id": str(cartao.conta_id),
                    "cartao": "Cartão Exemplo",
                    "competencia": "2026-11-01",
                    "vencimento": str(novembro.data_vencimento),
                    "valor": "1032.15",
                }
            ],
            "gastos_previstos": "840.00",
            "gastos_pela_media": False,
            "sobra": "1307.95",
            "nivel": "verde",
            "colchao": "500.00",
            "salario_recebido": None,
            "aporte": None,
        },
        "gasto_mensal": None,
        "meta_reserva_meses": "6.0",
    }


@pytest.mark.parametrize(
    ("colchao", "nivel"),
    [("1307.95", "verde"), ("1307.96", "amarelo"), ("0.00", "verde")],
)
def test_nivel_pela_sobra_e_o_colchao(api, sessao, conta, rascunhos, colchao, nivel):
    _configurar(sessao, colchao=Decimal(colchao))
    _renda(sessao, conta)
    _fatura(sessao, _cartao(sessao, conta), date(2026, 11, 1), "1032.15")

    assert api.get("/planejamento/resumo").json()["previsao"]["nivel"] == nivel


def test_sobra_negativa_e_risco(api, sessao, conta, rascunhos):
    _configurar(sessao)
    _renda(sessao, conta)
    _fatura(sessao, _cartao(sessao, conta), date(2026, 11, 1), "3000.00")

    previsao = api.get("/planejamento/resumo").json()["previsao"]

    assert previsao["sobra"] == "-659.90"
    assert previsao["nivel"] == "vermelho"


def test_fatura_de_cartao_desativado_nao_entra(api, sessao, conta, rascunhos):
    _configurar(sessao)
    _renda(sessao, conta)
    cartao = _cartao(sessao, conta, "Cartão Antigo")
    _fatura(sessao, cartao, date(2026, 11, 1), "1032.15")
    cartao.conta.ativa = False
    sessao.flush()

    previsao = api.get("/planejamento/resumo").json()["previsao"]

    assert previsao["faturas"] == []
    assert previsao["sobra"] == "2340.10"


def test_conta_desativada_sai_do_saldo(api, sessao, conta):
    antiga = criar_conta(sessao, "Conta antiga")
    antiga.saldo_inicial = Decimal("999.00")
    antiga.ativa = False
    carteira = criar_conta(sessao, "Carteira", tipo="carteira")
    carteira.saldo_inicial = Decimal("50.00")
    sessao.flush()

    assert api.get("/planejamento/resumo").json()["saldo_disponivel"] == "3260.10"


def test_salario_recebido_sugere_o_aporte(api, sessao, conta):
    """Renda do dia 20, que caiu hoje: o próximo salário é 23/11 (20/11 é
    feriado numa sexta), 34 dias de gasto (R$ 1.360,00)."""
    conta.saldo_inicial = Decimal("1230.10")
    _configurar(sessao)
    renda = _renda(sessao, conta, dia=20)
    criar_transacao(
        sessao,
        conta,
        "SALARIO EMPRESA EXEMPLO",
        tipo="receita",
        valor=Decimal("4200.00"),
        data=HOJE,
        status="confirmada",
    )
    _fatura(sessao, _cartao(sessao, conta), date(2026, 11, 1), "1032.15")

    previsao = api.get("/planejamento/resumo").json()["previsao"]

    assert previsao["proximo_salario"] == "2026-11-23"
    assert previsao["dias_ate_salario"] == 34
    assert previsao["gastos_previstos"] == "1360.00"
    assert previsao["sobra"] == "3037.95"
    assert previsao["salario_recebido"] == {
        "renda_id": str(renda.id),
        "descricao": "Salário",
        "conta_id": str(conta.id),
        "conta": "Conta principal",
        "data_esperada": "2026-10-20",
        "data": "2026-10-20",
        "valor": "4200.00",
    }
    assert previsao["aporte"] == "2537.95"


def test_gasto_mensal_fixo_ou_automatico(api, sessao, conta):
    """Gasto desde julho: julho, agosto e setembro fechados (R$ 900,00 de
    média); o fixo da configuração vale no lugar dela."""
    for mes in (7, 8, 9):
        criar_transacao(
            sessao, conta, valor=Decimal("900.00"), data=date(2026, mes, 1), status="confirmada"
        )

    automatico = api.get("/planejamento/resumo").json()["gasto_mensal"]
    _configurar(sessao, gasto_mensal_referencia=Decimal("3000.00"))
    fixo = api.get("/planejamento/resumo").json()["gasto_mensal"]

    assert automatico == {"valor": "900.00", "automatico": True}
    assert fixo == {"valor": "3000.00", "automatico": False}


def test_gastos_pela_media_quando_ela_passa_do_piso(api, sessao, conta):
    """Oito semanas de gasto (desde 25/08) somando R$ 5.600,00: R$ 100,00 por
    dia, acima dos R$ 40,00 do gasto semanal estimado."""
    criar_transacao(
        sessao, conta, valor=Decimal("5600.00"), data=date(2026, 8, 25), status="confirmada"
    )
    _configurar(sessao)
    _renda(sessao, conta)

    previsao = api.get("/planejamento/resumo").json()["previsao"]

    assert previsao["gastos_pela_media"] is True
    assert previsao["gastos_previstos"] == "2100.00"


def test_exige_login(client):
    assert client.get("/planejamento/resumo").status_code == 401
