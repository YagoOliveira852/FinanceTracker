"""Possível duplicata e transação que sumiu da origem: decisões da revisão em
que nada é apagado."""

import uuid
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.modulos.cartoes import service as cartoes_service
from app.modulos.categorias.models import Categoria, RegraClassificacao
from tests.utils import HOJE, criar_conta, criar_transacao

SUMIU_EM = datetime(2026, 10, 20, 10, 0, tzinfo=UTC)


@pytest.fixture
def conta(sessao):
    return criar_conta(sessao)


@pytest.fixture
def mercado(sessao) -> Categoria:
    return sessao.scalars(select(Categoria).where(Categoria.nome == "Mercado")).one()


@pytest.fixture
def confirmada(sessao, conta, mercado):
    """A do extrato OFX, já confirmada como Mercado."""
    return criar_transacao(
        sessao,
        conta,
        "COMPRA NO DEBITO MERCADO DO BAIRRO",
        fonte="ofx",
        status="confirmada",
        categoria_id=mercado.id,
        descricao="Mercado do bairro",
        valor=Decimal("64.90"),
    )


@pytest.fixture
def rascunho(sessao, conta, confirmada):
    """A mesma compra pelo Open Finance."""
    return criar_transacao(
        sessao,
        conta,
        "MERCADO DO BAIRRO LTDA",
        valor=Decimal("64.90"),
        possivel_duplicata_de=confirmada.id,
    )


def _resolver(api, rascunho, manter):
    return api.post(f"/revisao/transacoes/{rascunho.id}/duplicata", json={"manter": manter})


def test_ficar_com_a_outra_ignora_o_rascunho(api, sessao, rascunho, confirmada):
    resposta = _resolver(api, rascunho, "outra")

    assert resposta.status_code == 204, resposta.text
    sessao.refresh(rascunho)
    sessao.refresh(confirmada)
    assert (rascunho.status, confirmada.status) == ("ignorada", "confirmada")
    assert api.get("/revisao").json()["total"] == 0


def test_ficar_com_o_rascunho_herda_e_confirma(api, sessao, rascunho, confirmada):
    resposta = _resolver(api, rascunho, "rascunho")

    assert resposta.status_code == 204, resposta.text
    sessao.refresh(rascunho)
    sessao.refresh(confirmada)
    assert confirmada.status == "ignorada"
    assert (rascunho.status, rascunho.categoria.nome, rascunho.descricao) == (
        "confirmada",
        "Mercado",
        "Mercado do bairro",
    )
    assert rascunho.descricao_original == "MERCADO DO BAIRRO LTDA"
    (regra,) = sessao.scalars(select(RegraClassificacao)).all()
    assert (regra.padrao, regra.categoria.nome) == ("mercado do bairro ltda", "Mercado")


def test_ficar_com_o_rascunho_herda_o_par(api, sessao, conta, mercado):
    carteira = criar_conta(sessao, "Carteira", "carteira")
    saida = criar_transacao(
        sessao, conta, "SAQUE", tipo="transferencia_saida", status="confirmada", fonte="ofx"
    )
    entrada = criar_transacao(
        sessao, carteira, "SAQUE", tipo="transferencia_entrada", status="confirmada", fonte="manual"
    )
    saida.transferencia_par = entrada
    entrada.transferencia_par = saida
    sessao.flush()
    rascunho = criar_transacao(sessao, conta, "SAQUE 24H", possivel_duplicata_de=saida.id)

    _resolver(api, rascunho, "rascunho")

    sessao.refresh(rascunho)
    sessao.refresh(entrada)
    sessao.refresh(saida)
    assert (rascunho.tipo, rascunho.status) == ("transferencia_saida", "confirmada")
    assert rascunho.transferencia_par_id == entrada.id
    assert entrada.transferencia_par_id == rascunho.id
    assert saida.transferencia_par_id is None


def test_ficar_com_o_rascunho_herda_a_fatura_paga(api, sessao, conta):
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
    fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, date(2026, 10, 1))
    pago = criar_transacao(
        sessao,
        conta,
        "PAGAMENTO DE FATURA",
        tipo="pagamento_fatura",
        status="confirmada",
        fonte="ofx",
        fatura_id=fatura.id,
    )
    rascunho = criar_transacao(
        sessao, conta, "PAGAMENTO DE FATURA", tipo="pagamento_fatura", possivel_duplicata_de=pago.id
    )

    _resolver(api, rascunho, "rascunho")

    sessao.refresh(rascunho)
    assert (rascunho.fatura_id, rascunho.status) == (fatura.id, "confirmada")


def test_entre_rascunhos_o_que_fica_vai_para_a_lista(api, sessao, conta):
    outra = criar_transacao(sessao, conta, "MERCADO DO BAIRRO", fonte="ofx")
    outra.descricao = "Mercado do bairro"
    rascunho = criar_transacao(
        sessao, conta, "MERCADO DO BAIRRO LTDA", possivel_duplicata_de=outra.id
    )

    _resolver(api, rascunho, "rascunho")

    sessao.refresh(rascunho)
    sessao.refresh(outra)
    assert (rascunho.status, rascunho.descricao, outra.status) == (
        "rascunho",
        "Mercado do bairro",
        "ignorada",
    )
    lista = api.get("/revisao").json()
    assert [r["id"] for r in lista["rascunhos"]] == [str(rascunho.id)]


def test_manter_as_duas(api, sessao, rascunho, confirmada):
    _resolver(api, rascunho, "as_duas")

    sessao.refresh(rascunho)
    assert (rascunho.possivel_duplicata_de, rascunho.status) == (None, "rascunho")
    lista = api.get("/revisao").json()
    assert (len(lista["duplicatas"]), len(lista["rascunhos"])) == (0, 1)


def test_sem_duplicata_pendente_e_conflito(api, sessao, conta):
    rascunho = criar_transacao(sessao, conta)

    assert _resolver(api, rascunho, "rascunho").status_code == 409


def test_opcao_invalida(api, rascunho):
    assert _resolver(api, rascunho, "nenhuma").status_code == 422


def test_manter_a_que_sumiu_limpa_o_alerta(api, sessao, conta):
    sumida = criar_transacao(sessao, conta, status="confirmada", removida_na_origem_em=SUMIU_EM)

    resposta = api.post(f"/revisao/transacoes/{sumida.id}/manter")

    assert resposta.status_code == 204
    sessao.refresh(sumida)
    assert (sumida.status, sumida.removida_na_origem_em) == ("confirmada", None)


def test_remover_a_que_sumiu_ignora(api, sessao, conta):
    sumida = criar_transacao(sessao, conta, status="confirmada", removida_na_origem_em=SUMIU_EM)

    resposta = api.post(f"/revisao/transacoes/{sumida.id}/remover")

    assert resposta.status_code == 204
    sessao.refresh(sumida)
    assert sumida.status == "ignorada"
    assert api.get("/revisao").json()["total"] == 0


def test_remover_lado_de_transferencia_devolve_o_outro_a_rascunho(api, sessao, conta):
    dia_a_dia = criar_conta(sessao, "Conta do dia a dia")
    saida = criar_transacao(
        sessao,
        conta,
        "PIX ENVIADO",
        tipo="transferencia_saida",
        status="confirmada",
        removida_na_origem_em=SUMIU_EM,
    )
    entrada = criar_transacao(
        sessao, dia_a_dia, "PIX RECEBIDO", tipo="transferencia_entrada", status="confirmada"
    )
    saida.transferencia_par = entrada
    entrada.transferencia_par = saida
    sessao.flush()

    api.post(f"/revisao/transacoes/{saida.id}/remover")

    sessao.refresh(saida)
    sessao.refresh(entrada)
    assert (saida.status, saida.transferencia_par_id) == ("ignorada", None)
    assert (entrada.status, entrada.transferencia_par_id) == ("rascunho", None)


@pytest.mark.parametrize("acao", ["manter", "remover"])
def test_so_vale_para_a_que_sumiu(api, sessao, conta, acao):
    confirmada = criar_transacao(sessao, conta, status="confirmada")

    assert api.post(f"/revisao/transacoes/{confirmada.id}/{acao}").status_code == 409
    assert api.post(f"/revisao/transacoes/{uuid.uuid4()}/{acao}").status_code == 404
