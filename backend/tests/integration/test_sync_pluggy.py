"""Sync da Pluggy contra o banco real, com um cliente falso: nenhum teste chama
a Pluggy. Hoje = 2026-10-20; a janela de 40 dias começa em 2026-09-10. Dados
fictícios."""

from datetime import UTC, date, datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import func, select

from app.modulos.cartoes import service as cartoes_service
from app.modulos.cartoes.models import Fatura
from app.modulos.contas.models import Instituicao
from app.modulos.pluggy.client import ErroPluggy
from app.modulos.pluggy.models import ConexaoPluggy
from app.modulos.pluggy.sync import ERRO_INESPERADO, sincronizar_todas
from app.modulos.pluggy.tipos import FaturaPluggy
from app.modulos.transacoes.models import CompraParcelada, Transacao
from tests.pluggy_falsa import AGORA, CONSENTIMENTO, PluggyFalsa
from tests.pluggy_falsa import tx as _tx
from tests.utils import HOJE, criar_conta, criar_transacao

FORTALEZA = ZoneInfo("America/Fortaleza")


@pytest.fixture
def pluggy():
    return PluggyFalsa()


def _conexao(sessao, item_id: str = "item-1", **mudancas) -> ConexaoPluggy:
    instituicao = sessao.scalar(select(Instituicao).where(Instituicao.nome == "Banco Exemplo"))
    if instituicao is None:
        instituicao = Instituicao(nome="Banco Exemplo")
    conexao = ConexaoPluggy(item_id=item_id, instituicao=instituicao, **mudancas)
    sessao.add(conexao)
    sessao.flush()
    return conexao


@pytest.fixture
def conexao(sessao):
    return _conexao(sessao)


@pytest.fixture
def conta(sessao, conexao):
    conta = criar_conta(sessao)
    conta.data_saldo_inicial = date(2026, 9, 1)
    conta.conexao_pluggy_id = conexao.id
    conta.pluggy_account_id = "conta-1"
    sessao.flush()
    return conta


@pytest.fixture
def cartao(sessao, conexao, conta):
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
    cartao.conta.conexao_pluggy_id = conexao.id
    cartao.conta.pluggy_account_id = "cartao-1"
    sessao.flush()
    return cartao


def _rodar(sessao, pluggy, **kwargs):
    return sincronizar_todas(sessao, pluggy, agora=AGORA, hoje=HOJE, fuso=FORTALEZA, **kwargs)


def _transacoes(sessao, conta) -> list[Transacao]:
    return list(
        sessao.scalars(
            select(Transacao).where(Transacao.conta_id == conta.id).order_by(Transacao.id_externo)
        )
    )


def test_transacao_nova_vira_rascunho_com_data_local(sessao, pluggy, conexao, conta):
    pluggy.transacoes["conta-1"] = [
        # 01:30 UTC de 20/10 é 19/10 em Fortaleza.
        _tx("tx-1", momento=datetime(2026, 10, 20, 1, 30, tzinfo=UTC)),
        _tx("tx-2", valor=Decimal("4200"), sentido="CREDIT", descricao_bruta="SALARIO"),
    ]

    (resultado,) = _rodar(sessao, pluggy)

    assert (resultado.ok, resultado.novas) == (True, 2)
    assert pluggy.pedidos == [("conta-1", date(2026, 9, 10))]
    padaria, salario = _transacoes(sessao, conta)
    assert (padaria.tipo, padaria.valor, padaria.data) == (
        "despesa",
        Decimal("18.50"),
        date(2026, 10, 19),
    )
    assert (padaria.status, padaria.fonte, padaria.id_externo) == ("rascunho", "pluggy", "tx-1")
    assert padaria.descricao_original == padaria.descricao == "PADARIA EXEMPLO"
    assert padaria.importacao_id is None
    assert (salario.tipo, salario.valor) == ("receita", Decimal("4200.00"))
    sessao.refresh(conexao)
    assert conexao.ultimo_sync_em == conexao.ultima_tentativa_em == AGORA
    assert (conexao.status, conexao.consentimento_expira_em, conexao.ultimo_erro) == (
        "UPDATED",
        CONSENTIMENTO,
        None,
    )


def test_rodar_de_novo_nao_duplica(sessao, pluggy, conexao, conta):
    pluggy.transacoes["conta-1"] = [_tx("tx-1")]

    _rodar(sessao, pluggy)
    (resultado,) = _rodar(sessao, pluggy)

    assert (resultado.novas, resultado.atualizadas) == (0, 0)
    assert len(_transacoes(sessao, conta)) == 1


def test_rascunho_acompanha_a_pluggy_e_guarda_a_descricao_editada(sessao, pluggy, conexao, conta):
    pluggy.transacoes["conta-1"] = [_tx("tx-1", status="PENDING"), _tx("tx-2")]
    _rodar(sessao, pluggy)
    editada = _transacoes(sessao, conta)[1]
    editada.descricao = "Pão da semana"
    sessao.commit()

    pluggy.transacoes["conta-1"] = [
        _tx("tx-1", valor=Decimal("-19.90"), descricao_bruta="PADARIA EXEMPLO 2"),
        _tx("tx-2", valor=Decimal("-20.00")),
    ]
    (resultado,) = _rodar(sessao, pluggy)

    primeira, segunda = _transacoes(sessao, conta)
    assert resultado.atualizadas == 2
    assert (primeira.valor, primeira.descricao) == (Decimal("19.90"), "PADARIA EXEMPLO 2")
    assert (segunda.valor, segunda.descricao) == (Decimal("20.00"), "Pão da semana")


def test_confirmada_nao_muda_e_sumir_so_marca(sessao, pluggy, conexao, conta):
    pluggy.transacoes["conta-1"] = [_tx("tx-1")]
    _rodar(sessao, pluggy)
    (confirmada,) = _transacoes(sessao, conta)
    confirmada.status = "confirmada"
    sessao.commit()

    pluggy.transacoes["conta-1"] = [_tx("tx-1", valor=Decimal("-99.00"))]
    _rodar(sessao, pluggy)
    assert confirmada.valor == Decimal("18.50")

    pluggy.transacoes["conta-1"] = []
    (sumiu,) = _rodar(sessao, pluggy)
    sessao.refresh(confirmada)
    assert (sumiu.marcadas_removidas, confirmada.removida_na_origem_em) == (1, AGORA)

    pluggy.transacoes["conta-1"] = [_tx("tx-1")]
    _rodar(sessao, pluggy)
    sessao.refresh(confirmada)
    assert confirmada.removida_na_origem_em is None


def test_rascunho_que_sumiu_da_janela_e_apagado(sessao, pluggy, conexao, conta):
    pluggy.transacoes["conta-1"] = [_tx("tx-1"), _tx("tx-2")]
    _rodar(sessao, pluggy)
    # Fora da janela de 40 dias: a Pluggy não manda mais, e fica como está.
    criar_transacao(sessao, conta, data=date(2026, 9, 9), id_externo="tx-antiga")
    sessao.commit()

    pluggy.transacoes["conta-1"] = [_tx("tx-2")]
    (resultado,) = _rodar(sessao, pluggy)

    assert resultado.removidas == 1
    assert [t.id_externo for t in _transacoes(sessao, conta)] == ["tx-2", "tx-antiga"]


def test_bate_com_lancamento_manual_vira_possivel_duplicata(sessao, pluggy, conexao, conta):
    manual = criar_transacao(
        sessao,
        conta,
        "PADARIA",
        fonte="manual",
        id_externo=None,
        status="confirmada",
        data=date(2026, 10, 18),
    )
    pluggy.transacoes["conta-1"] = [_tx("tx-1")]

    _rodar(sessao, pluggy)

    nova = sessao.scalar(select(Transacao).where(Transacao.id_externo == "tx-1"))
    assert nova.possivel_duplicata_de == manual.id


def test_cartao_grava_a_fatura_do_banco_e_liga_as_compras(sessao, pluggy, conexao, cartao):
    pluggy.faturas["cartao-1"] = [
        FaturaPluggy(
            id="bill-nov",
            vencimento=date(2026, 11, 10),
            fechamento=date(2026, 11, 4),
            total=Decimal("1032.15"),
        ),
        # Venceu antes da janela: fica de fora.
        FaturaPluggy(
            id="bill-ago", vencimento=date(2026, 8, 10), fechamento=None, total=Decimal("900")
        ),
    ]
    pluggy.transacoes["cartao-1"] = [
        _tx("c-1", valor=Decimal("120.00"), bill_id="bill-nov"),
        # Pendente da fatura aberta, sem billId: a regra do cartão manda em dezembro.
        _tx("c-2", status="PENDING", momento=datetime(2026, 11, 6, 15, tzinfo=UTC)),
        # Estorno no cartão.
        _tx("c-3", valor=Decimal("-30.00"), sentido="CREDIT", bill_id="bill-nov"),
        # O pagamento da fatura do lado do cartão não entra.
        _tx("c-4", valor=Decimal("900.00"), sentido="CREDIT", tipo_operacao="PAGAMENTO_FATURA"),
    ]

    (resultado,) = _rodar(sessao, pluggy)

    assert resultado.novas == 3
    novembro = sessao.scalar(select(Fatura).where(Fatura.pluggy_bill_id == "bill-nov"))
    assert (novembro.competencia, novembro.data_vencimento, novembro.data_fechamento) == (
        date(2026, 11, 1),
        date(2026, 11, 10),
        date(2026, 11, 4),
    )
    assert novembro.valor_informado == Decimal("1032.15")
    assert sessao.scalar(select(func.count()).where(Fatura.pluggy_bill_id == "bill-ago")) == 0
    compra, pendente, estorno = _transacoes(sessao, cartao.conta)
    assert compra.fatura_id == estorno.fatura_id == novembro.id
    assert estorno.tipo == "estorno"
    assert sessao.get(Fatura, pendente.fatura_id).competencia == date(2026, 12, 1)


def test_parcelas_da_mesma_compra_ficam_juntas(sessao, pluggy, conexao, cartao):
    compra = datetime(2026, 9, 14, 13, tzinfo=UTC)
    pluggy.transacoes["cartao-1"] = [
        _tx(
            f"p-{n}",
            valor=Decimal("50.00"),
            descricao_bruta="LOJA EXEMPLO",
            parcela_numero=n,
            total_parcelas=6,
            data_compra=compra,
            momento=datetime(2026, 9 + n, 14, 15, tzinfo=UTC),
            status="POSTED" if n == 1 else "PENDING",
        )
        for n in (1, 2, 3)
    ]

    _rodar(sessao, pluggy)

    parcelas = _transacoes(sessao, cartao.conta)
    (compra_parcelada,) = sessao.scalars(select(CompraParcelada))
    assert [p.parcela_numero for p in parcelas] == [1, 2, 3]
    assert {p.compra_parcelada_id for p in parcelas} == {compra_parcelada.id}
    assert (compra_parcelada.data_compra, compra_parcelada.data_compra_estimada) == (
        date(2026, 9, 14),
        False,
    )
    assert (compra_parcelada.qtd_parcelas, compra_parcelada.valor_total) == (6, Decimal("300.00"))


def test_erro_numa_conexao_nao_grava_nada_dela_nem_para_as_outras(sessao, pluggy, conexao, conta):
    outra = _conexao(sessao, "item-2")
    conta2 = criar_conta(sessao, "Conta do dia a dia")
    conta2.conexao_pluggy_id = outra.id
    conta2.pluggy_account_id = "conta-2"
    sessao.flush()
    pluggy.transacoes["conta-1"] = [_tx("tx-1")]
    pluggy.transacoes["conta-2"] = [_tx("tx-9")]
    pluggy.erros["item-1"] = ErroPluggy("A Pluggy respondeu com erro (500).")

    falhou, deu_certo = _rodar(sessao, pluggy)

    assert (falhou.ok, falhou.erro) == (False, "A Pluggy respondeu com erro (500).")
    assert deu_certo.ok
    sessao.refresh(conexao)
    assert (conexao.ultimo_erro, conexao.ultima_tentativa_em, conexao.ultimo_sync_em) == (
        "A Pluggy respondeu com erro (500).",
        AGORA,
        None,
    )
    assert _transacoes(sessao, conta) == []
    assert len(_transacoes(sessao, conta2)) == 1


def test_erro_inesperado_vira_mensagem_generica(sessao, pluggy, conexao, conta):
    pluggy.erros["item-1"] = KeyError("campo")

    (resultado,) = _rodar(sessao, pluggy)

    assert resultado.erro == ERRO_INESPERADO


def test_repescagem_so_relê_quem_falhou(sessao, pluggy):
    ok = _conexao(sessao, "item-ok", ultima_tentativa_em=AGORA, ultimo_sync_em=AGORA)
    falhou = _conexao(sessao, "item-falhou", ultima_tentativa_em=AGORA, ultimo_sync_em=None)

    resultados = _rodar(sessao, pluggy, repescagem=True)

    assert [r.conexao_id for r in resultados] == [falhou.id]
    assert ok.id not in [r.conexao_id for r in resultados]


def test_conexao_desativada_e_conta_desativada_ficam_de_fora(sessao, pluggy, conexao, conta):
    inativa = _conexao(sessao, "item-inativo", ativa=False)
    conta.ativa = False
    sessao.flush()
    pluggy.transacoes["conta-1"] = [_tx("tx-1")]

    resultados = _rodar(sessao, pluggy)

    assert [r.conexao_id for r in resultados] == [conexao.id]
    assert inativa.ultima_tentativa_em is None
    assert pluggy.pedidos == []
