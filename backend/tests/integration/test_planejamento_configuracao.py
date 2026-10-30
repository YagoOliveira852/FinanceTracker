"""Configuração do planejamento pela API: linha única criada no primeiro
salvamento, e a leitura com o gasto mensal automático e a média semanal real
(calculados por `planejamento/calculo.py`).

Hoje = 2026-10-20: os meses fechados são julho, agosto e setembro, e as
últimas 8 semanas vão de 25/08 a 19/10.
"""

from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import func, select

from app.modulos.planejamento.models import Configuracao
from tests.utils import criar_conta, criar_transacao

SEM_NADA = {
    "configuracao": None,
    "gasto_mensal_automatico": None,
    "media_semanal_real": None,
    "meses_de_reserva": None,
}


def _dados(**mudancas) -> dict:
    return {
        "colchao": "500.00",
        "meta_reserva_meses": "6",
        "gasto_semanal_estimado": "280.00",
        "gasto_mensal_referencia": None,
        **mudancas,
    }


def _campos(resposta) -> dict:
    assert resposta.status_code == 422, resposta.json()
    return {erro["campo"]: erro["mensagem"] for erro in resposta.json()["campos"]}


def test_sem_configuracao_salva_a_leitura_diz_que_nao_ha(api):
    resposta = api.get("/planejamento/configuracao")

    assert resposta.status_code == 200
    assert resposta.json() == SEM_NADA


def test_primeiro_salvamento_cria_a_linha_e_os_seguintes_a_atualizam(api, sessao):
    primeira = api.put("/planejamento/configuracao", json=_dados())
    segunda = api.put(
        "/planejamento/configuracao",
        json=_dados(colchao="350.00", meta_reserva_meses="4.5", gasto_mensal_referencia="3000"),
    )

    assert primeira.status_code == 200, primeira.json()
    assert primeira.json()["configuracao"] == {
        "colchao": "500.00",
        "meta_reserva_meses": "6.0",
        "gasto_semanal_estimado": "280.00",
        "gasto_mensal_referencia": None,
    }
    assert segunda.status_code == 200, segunda.json()
    assert segunda.json()["configuracao"] == {
        "colchao": "350.00",
        "meta_reserva_meses": "4.5",
        "gasto_semanal_estimado": "280.00",
        "gasto_mensal_referencia": "3000.00",
    }
    assert api.get("/planejamento/configuracao").json() == segunda.json()
    assert sessao.scalar(select(func.count()).select_from(Configuracao)) == 1


@pytest.mark.parametrize(
    ("mudanca", "campo", "mensagem"),
    [
        ({"colchao": "-1.00"}, "colchao", "O colchão não pode ser negativo."),
        (
            {"gasto_semanal_estimado": "-1.00"},
            "gasto_semanal_estimado",
            "O gasto semanal não pode ser negativo.",
        ),
        ({"meta_reserva_meses": "0"}, "meta_reserva_meses", "A meta precisa ser maior que zero."),
        (
            {"gasto_mensal_referencia": "0.00"},
            "gasto_mensal_referencia",
            "O gasto mensal precisa ser maior que zero.",
        ),
    ],
)
def test_valida_os_valores(api, mudanca, campo, mensagem):
    resposta = api.put("/planejamento/configuracao", json=_dados(**mudanca))

    assert _campos(resposta) == {f"body.{campo}": mensagem}


@pytest.mark.parametrize("meta", ["4.55", "1000", "seis", 6])
def test_meta_em_meses_com_uma_casa(api, meta):
    resposta = api.put("/planejamento/configuracao", json=_dados(meta_reserva_meses=meta))

    assert list(_campos(resposta)) == ["body.meta_reserva_meses"]


def test_zero_de_colchao_e_de_gasto_semanal_vale(api):
    resposta = api.put(
        "/planejamento/configuracao", json=_dados(colchao="0", gasto_semanal_estimado="0")
    )

    assert resposta.status_code == 200, resposta.json()


@pytest.fixture
def historico(sessao):
    """Gastos fictícios desde 01/07: julho 100, agosto 300, setembro 600 (mais
    uma ignorada e uma possível duplicata, que não contam) e, nas últimas 8
    semanas, 600 + 140 − 40 de estorno = 700."""
    conta = criar_conta(sessao)

    def gasto(dia: date, valor: str, **mudancas) -> None:
        dados = {"data": dia, "valor": Decimal(valor), "status": "confirmada"}
        criar_transacao(sessao, conta, **(dados | mudancas))

    gasto(date(2026, 7, 1), "100.00")
    gasto(date(2026, 8, 15), "300.00")
    gasto(date(2026, 9, 10), "600.00")
    gasto(date(2026, 9, 11), "1000.00", status="ignorada")
    original = criar_transacao(sessao, conta, data=date(2026, 9, 12), valor=Decimal("50.00"))
    criar_transacao(
        sessao,
        conta,
        data=date(2026, 9, 12),
        valor=Decimal("50.00"),
        fonte="ofx",
        possivel_duplicata_de=original.id,
    )
    gasto(date(2026, 10, 15), "140.00", status="rascunho")
    gasto(date(2026, 10, 16), "40.00", tipo="estorno")
    # Receita não é gasto.
    gasto(date(2026, 9, 5), "4200.00", tipo="receita")


def test_leitura_traz_o_automatico_e_a_media_semanal_mesmo_sem_configuracao(api, historico):
    corpo = api.get("/planejamento/configuracao").json()

    assert corpo["configuracao"] is None
    assert corpo["gasto_mensal_automatico"] == {
        # (100 + 300 + 650) / 3: a original da duplicata conta.
        "valor": "350.00",
        "meses": ["2026-07-01", "2026-08-01", "2026-09-01"],
    }
    # (600 + 50 + 140 − 40) × 7 / 56.
    assert corpo["media_semanal_real"] == "93.75"
    # Sem investimentos ainda, a reserva é 0.
    assert corpo["meses_de_reserva"] == "0.0"


def test_valor_fixo_nao_esconde_o_automatico(api, historico):
    api.put("/planejamento/configuracao", json=_dados(gasto_mensal_referencia="3000.00"))

    corpo = api.get("/planejamento/configuracao").json()

    assert corpo["gasto_mensal_automatico"]["valor"] == "350.00"


def test_meses_de_reserva_usam_o_valor_fixo_mesmo_sem_historico(api):
    api.put("/planejamento/configuracao", json=_dados(gasto_mensal_referencia="3000.00"))

    corpo = api.get("/planejamento/configuracao").json()

    assert corpo["gasto_mensal_automatico"] is None
    assert corpo["media_semanal_real"] is None
    assert corpo["meses_de_reserva"] == "0.0"
