"""Pagamento de fatura vindo das fontes: o usuário escolhe a fatura na revisão.

"Hoje" é 20/10/2026. Cartão com fechamento dia 3 e vencimento dia 10: a
fatura de outubro já fechou (03/10 é sábado → 05/10) e a atual é a de
novembro."""

import uuid
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.modulos.cartoes import service as cartoes_service
from app.modulos.cartoes.models import Fatura
from tests.utils import HOJE, criar_conta, criar_transacao

OUTUBRO = date(2026, 10, 1)
NOVEMBRO = date(2026, 11, 1)


@pytest.fixture
def conta(sessao):
    return criar_conta(sessao)


def _cartao(sessao, nome, conta_pagamento):
    return cartoes_service.criar_cartao(
        sessao,
        nome=nome,
        nome_instituicao=f"Banco de {nome}",
        conta_pagamento_id=conta_pagamento.id,
        dia_fechamento=3,
        dia_vencimento=10,
        limite=None,
        hoje=HOJE,
    )


@pytest.fixture
def cartao(sessao, conta):
    return _cartao(sessao, "Cartão Exemplo", conta)


def _compra(sessao, cartao, competencia, valor="100.00"):
    fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, competencia)
    criar_transacao(
        sessao,
        cartao.conta,
        "LOJA EXEMPLO",
        valor=Decimal(valor),
        status="confirmada",
        fatura_id=fatura.id,
    )
    return fatura


def _pagamento(sessao, conta, valor="100.00", **mudancas):
    return criar_transacao(
        sessao,
        conta,
        "PAGAMENTO DE FATURA CARTAO EXEMPLO",
        tipo="pagamento_fatura",
        valor=Decimal(valor),
        data=date(2026, 10, 13),
        **mudancas,
    )


def _candidatas(api, pagamento) -> list[dict]:
    resposta = api.get(f"/revisao/transacoes/{pagamento.id}/faturas")
    assert resposta.status_code == 200, resposta.text
    return resposta.json()


def test_candidatas_e_a_sugerida(api, sessao, conta, cartao):
    _compra(sessao, cartao, OUTUBRO)
    pagamento = _pagamento(sessao, conta)

    candidatas = _candidatas(api, pagamento)

    assert [(c["competencia"], c["status"], c["sugerida"]) for c in candidatas] == [
        ("2026-11-01", "aberta", False),
        ("2026-10-01", "fechada", True),
    ]
    outubro = candidatas[1]
    assert outubro["cartao_nome"] == "Cartão Exemplo"
    assert outubro["cartao_id"] == str(cartao.conta_id)
    assert (outubro["valor"], outubro["valor_pago"], outubro["fica_paga"]) == (
        "100.00",
        "0.00",
        True,
    )
    assert candidatas[0]["fica_paga"] is False  # aberta nunca fica paga


def test_pagamento_menor_nao_quita(api, sessao, conta, cartao):
    _compra(sessao, cartao, OUTUBRO)
    pagamento = _pagamento(sessao, conta, valor="50.00")

    assert _candidatas(api, pagamento)[1]["fica_paga"] is False


def test_so_duas_anteriores(api, sessao, conta, cartao):
    for mes in (7, 8, 9, 10):
        _compra(sessao, cartao, date(2026, mes, 1))
    pagamento = _pagamento(sessao, conta)

    competencias = [c["competencia"] for c in _candidatas(api, pagamento)]

    assert competencias == ["2026-11-01", "2026-10-01", "2026-09-01"]


def test_cartao_pago_por_outra_conta_nao_e_sugerido(api, sessao, conta):
    outra = criar_conta(sessao, "Conta do dia a dia")
    _compra(sessao, _cartao(sessao, "Cartão Fictício", outra), OUTUBRO)
    pagamento = _pagamento(sessao, conta)

    candidatas = _candidatas(api, pagamento)

    assert len(candidatas) == 2
    assert not any(c["sugerida"] for c in candidatas)


def test_cartao_desativado_fica_de_fora(api, sessao, conta, cartao):
    cartao.conta.ativa = False
    pagamento = _pagamento(sessao, conta)

    assert _candidatas(api, pagamento) == []


def test_fatura_ja_ligada_pela_fonte_e_a_sugerida_sem_contar_duas_vezes(api, sessao, conta, cartao):
    _compra(sessao, cartao, OUTUBRO)
    novembro = _compra(sessao, cartao, NOVEMBRO)
    pagamento = _pagamento(sessao, conta, fatura_id=novembro.id)

    novembro_saida = _candidatas(api, pagamento)[0]

    assert novembro_saida["sugerida"] is True
    assert novembro_saida["valor_pago"] == "100.00"


def test_pagar_grava_a_fatura_e_confirma(api, sessao, conta, cartao):
    pagamento = _pagamento(sessao, conta)

    resposta = api.post(
        f"/revisao/transacoes/{pagamento.id}/pagamento",
        json={"cartao_id": str(cartao.conta_id), "competencia": "2026-11"},
    )

    assert resposta.status_code == 204, resposta.text
    fatura = sessao.scalars(select(Fatura).where(Fatura.competencia == NOVEMBRO)).one()
    sessao.refresh(pagamento)
    assert (pagamento.fatura_id, pagamento.status) == (fatura.id, "confirmada")


def test_fatura_fica_paga(api, sessao, conta, cartao):
    _compra(sessao, cartao, OUTUBRO)
    pagamento = _pagamento(sessao, conta)

    api.post(
        f"/revisao/transacoes/{pagamento.id}/pagamento",
        json={"cartao_id": str(cartao.conta_id), "competencia": "2026-10"},
    )

    fatura = api.get(f"/cartoes/{cartao.conta_id}/faturas/2026-10").json()
    assert fatura["status"] == "paga"


def test_rascunho_que_nao_e_pagamento(api, sessao, conta, cartao):
    despesa = criar_transacao(sessao, conta)

    lista = api.get(f"/revisao/transacoes/{despesa.id}/faturas")
    pagar = api.post(
        f"/revisao/transacoes/{despesa.id}/pagamento",
        json={"cartao_id": str(cartao.conta_id), "competencia": "2026-10"},
    )

    assert (lista.status_code, pagar.status_code) == (422, 422)
    assert lista.json()["detail"] == "Este rascunho não é pagamento de fatura."


@pytest.mark.parametrize(
    ("corpo", "campo"),
    [
        ({"cartao_id": str(uuid.uuid4()), "competencia": "2026-10"}, "body.cartao_id"),
        ({"competencia": "2026-13"}, "body.competencia"),
    ],
)
def test_pagar_invalido(api, sessao, conta, cartao, corpo, campo):
    pagamento = _pagamento(sessao, conta)
    corpo = {"cartao_id": str(cartao.conta_id)} | corpo

    resposta = api.post(f"/revisao/transacoes/{pagamento.id}/pagamento", json=corpo)

    assert resposta.status_code == 422
    assert resposta.json()["campos"][0]["campo"] == campo


def test_pagamento_ja_confirmado_e_conflito(api, sessao, conta, cartao):
    pagamento = _pagamento(sessao, conta, status="confirmada")

    assert api.get(f"/revisao/transacoes/{pagamento.id}/faturas").status_code == 409
