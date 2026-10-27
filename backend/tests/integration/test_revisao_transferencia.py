"""Rascunho marcado como transferência na revisão (campo "Para"/"De"): cria o
outro lado só quando a outra conta não recebe extrato nem Open Finance."""

from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.modulos.cartoes import service as cartoes_service
from app.modulos.revisao.models import ParRecusado
from app.modulos.transacoes.models import Transacao
from tests.utils import HOJE, criar_conta, criar_transacao

VALOR = Decimal("200.00")


@pytest.fixture
def conta(sessao):
    return criar_conta(sessao)


@pytest.fixture
def carteira(sessao):
    return criar_conta(sessao, "Carteira", "carteira")


@pytest.fixture
def dia_a_dia(sessao):
    """Conta do dia a dia que recebe Open Finance (já tem transação da Pluggy)."""
    conta = criar_conta(sessao, "Conta do dia a dia")
    criar_transacao(sessao, conta, "MERCADO DO BAIRRO", status="confirmada")
    return conta


def _transferir(api, transacao, conta, descricao="Saque"):
    return api.post(
        f"/revisao/transacoes/{transacao.id}/transferencia",
        json={"conta_id": str(conta.id), "descricao": descricao},
    )


def _da_conta(sessao, conta) -> list[Transacao]:
    return list(sessao.scalars(select(Transacao).where(Transacao.conta_id == conta.id)))


def test_saida_para_a_carteira_cria_a_entrada(api, sessao, conta, carteira):
    saque = criar_transacao(sessao, conta, "SAQUE 24H BANCO EXEMPLO 24/10", valor=VALOR)

    resposta = _transferir(api, saque, carteira)

    assert resposta.status_code == 204, resposta.text
    sessao.refresh(saque)
    (entrada,) = _da_conta(sessao, carteira)
    assert (saque.tipo, saque.status, saque.descricao) == (
        "transferencia_saida",
        "confirmada",
        "Saque",
    )
    assert (entrada.tipo, entrada.status, entrada.fonte) == (
        "transferencia_entrada",
        "confirmada",
        "manual",
    )
    assert (entrada.valor, entrada.data) == (VALOR, saque.data)
    assert saque.transferencia_par_id == entrada.id
    assert entrada.transferencia_par_id == saque.id


def test_entrada_vinda_da_carteira_cria_a_saida(api, sessao, conta, carteira):
    deposito = criar_transacao(sessao, conta, "DEPOSITO EM DINHEIRO", tipo="receita", valor=VALOR)

    _transferir(api, deposito, carteira, "Depósito")

    sessao.refresh(deposito)
    (saida,) = _da_conta(sessao, carteira)
    assert deposito.tipo == "transferencia_entrada"
    assert saida.tipo == "transferencia_saida"
    assert saida.transferencia_par_id == deposito.id


def test_conta_com_fonte_liga_com_o_rascunho_de_la(api, sessao, conta, dia_a_dia):
    saida = criar_transacao(sessao, conta, "PIX ENVIADO", valor=VALOR, data=date(2026, 10, 19))
    longe = criar_transacao(
        sessao, dia_a_dia, "PIX RECEBIDO", tipo="receita", valor=VALOR, data=date(2026, 10, 21)
    )
    perto = criar_transacao(
        sessao, dia_a_dia, "PIX RECEBIDO", tipo="receita", valor=VALOR, data=date(2026, 10, 20)
    )
    antes = len(_da_conta(sessao, dia_a_dia))

    resposta = _transferir(api, saida, dia_a_dia, "Pix para o dia a dia")

    assert resposta.status_code == 204, resposta.text
    sessao.refresh(perto)
    sessao.refresh(longe)
    assert len(_da_conta(sessao, dia_a_dia)) == antes
    assert (perto.tipo, perto.transferencia_par_id) == ("transferencia_entrada", saida.id)
    assert longe.status == "rascunho"


def test_conta_com_fonte_ignora_par_recusado(api, sessao, conta, dia_a_dia):
    saida = criar_transacao(sessao, conta, valor=VALOR)
    recusada = criar_transacao(sessao, dia_a_dia, tipo="receita", valor=VALOR)
    sessao.add(ParRecusado(saida_id=saida.id, entrada_id=recusada.id))
    sessao.flush()

    resposta = _transferir(api, saida, dia_a_dia)

    assert resposta.status_code == 422


def test_conta_com_fonte_sem_o_outro_lado_recusa(api, sessao, conta, dia_a_dia):
    saida = criar_transacao(sessao, conta, valor=VALOR)
    criar_transacao(sessao, dia_a_dia, tipo="receita", valor=VALOR, data=date(2026, 10, 25))

    resposta = _transferir(api, saida, dia_a_dia)

    assert resposta.status_code == 422
    (erro,) = resposta.json()["campos"]
    assert erro == {
        "campo": "body.conta_id",
        "mensagem": "A Conta do dia a dia recebe extrato ou Open Finance: confirme quando a "
        "entrada chegar de lá.",
    }
    sessao.refresh(saida)
    assert saida.status == "rascunho"


def test_pagamento_que_era_transferencia_perde_a_fatura(api, sessao, conta, carteira):
    cartao = cartoes_service.criar_cartao(
        sessao,
        nome="Cartão Exemplo",
        nome_instituicao="Banco Exemplo",
        conta_pagamento_id=conta.id,
        dia_fechamento=3,
        dia_vencimento=10,
        limite=None,
        hoje=HOJE,
    )
    fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, date(2026, 11, 1))
    pagamento = criar_transacao(
        sessao, conta, tipo="pagamento_fatura", valor=VALOR, fatura_id=fatura.id
    )

    _transferir(api, pagamento, carteira)

    sessao.refresh(pagamento)
    assert (pagamento.tipo, pagamento.fatura_id) == ("transferencia_saida", None)


@pytest.mark.parametrize("problema", ["mesma_conta", "cartao", "desativada"])
def test_conta_invalida(api, sessao, conta, carteira, problema):
    saida = criar_transacao(sessao, conta, valor=VALOR)
    if problema == "mesma_conta":
        destino = conta
    elif problema == "cartao":
        destino = cartoes_service.criar_cartao(
            sessao,
            nome="Cartão Exemplo",
            nome_instituicao="Banco Exemplo",
            conta_pagamento_id=conta.id,
            dia_fechamento=3,
            dia_vencimento=10,
            limite=None,
            hoje=HOJE,
        ).conta
    else:
        carteira.ativa = False
        destino = carteira

    resposta = _transferir(api, saida, destino)

    assert resposta.status_code == 422
    assert resposta.json()["campos"][0]["campo"] == "body.conta_id"


def test_rascunho_do_cartao_nao_e_transferencia(api, sessao, conta, carteira):
    cartao = cartoes_service.criar_cartao(
        sessao,
        nome="Cartão Exemplo",
        nome_instituicao="Banco Exemplo",
        conta_pagamento_id=conta.id,
        dia_fechamento=3,
        dia_vencimento=10,
        limite=None,
        hoje=HOJE,
    )
    compra = criar_transacao(sessao, cartao.conta, valor=VALOR)

    assert _transferir(api, compra, carteira).status_code == 422


def test_ja_confirmada_e_conflito(api, sessao, conta, carteira):
    saida = criar_transacao(sessao, conta, valor=VALOR, status="confirmada")

    assert _transferir(api, saida, carteira).status_code == 409
