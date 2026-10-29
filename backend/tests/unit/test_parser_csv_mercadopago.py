"""Leitor do CSV do extrato do Mercado Pago (função pura): fixture fictícia no
formato da amostra real (spec `2026-10-28-importacao-design`, adendo de
2026-10-29)."""

from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest

from app.modulos.importacao.models import FonteImportacao
from app.modulos.importacao.parsers import ler_extrato
from app.modulos.importacao.parsers.csv_mercadopago import ler_csv_mercadopago
from app.modulos.importacao.parsers.extrato import (
    FormatoNaoReconhecido,
    IdentificadorRepetido,
    TipoExtrato,
)

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures"
EXTRATO = FIXTURES / "csv_mercadopago" / "extrato.csv"


def _dados() -> bytes:
    return EXTRATO.read_bytes()


def test_extrato_da_conta():
    extrato = ler_csv_mercadopago(_dados())

    assert extrato.fonte == FonteImportacao.csv_mercadopago
    assert extrato.tipo == TipoExtrato.conta
    assert (extrato.periodo_inicio, extrato.periodo_fim) == (date(2026, 10, 1), date(2026, 10, 6))
    assert [(linha.data, linha.valor) for linha in extrato.linhas] == [
        (date(2026, 10, 1), Decimal("2500.00")),
        (date(2026, 10, 2), Decimal("-1500.00")),
        (date(2026, 10, 2), Decimal("0.12")),
        (date(2026, 10, 3), Decimal("-64.90")),
        (date(2026, 10, 3), Decimal("0.10")),
        (date(2026, 10, 5), Decimal("150.00")),
        (date(2026, 10, 6), Decimal("1.15")),
    ]


def test_reference_id_e_o_id_externo_e_a_descricao_vem_sem_espaco_no_fim():
    linhas = ler_csv_mercadopago(_dados()).linhas

    assert linhas[3].descricao == "Pix enviado João Fictício"
    assert linhas[3].identificador == linhas[3].id_externo == "100000000004"
    assert linhas[2].descricao == "Rendimentos"
    assert all(linha.parcela is None for linha in linhas)


def test_saldo_e_o_da_ultima_linha():
    saldo = ler_csv_mercadopago(_dados()).saldo

    assert saldo is not None
    assert (saldo.valor, saldo.data) == (Decimal("1186.47"), date(2026, 10, 6))


def test_saldo_negativo():
    dados = _dados().replace(b"1,15;1.186,47", b"1,15;-1.186,47")

    saldo = ler_csv_mercadopago(dados).saldo

    assert saldo is not None
    assert saldo.valor == Decimal("-1186.47")


def test_valor_zero_e_descartado_mas_o_saldo_continua_o_da_ultima_linha():
    dados = _dados() + b"07-10-2026;Rendimentos ;1000000000008;0,00;1.186,47\n"

    extrato = ler_csv_mercadopago(dados)

    assert len(extrato.linhas) == 7
    assert extrato.saldo is not None
    assert extrato.saldo.data == date(2026, 10, 7)
    assert extrato.periodo_fim == date(2026, 10, 7)


def test_sem_lancamentos_nao_tem_saldo_nem_periodo():
    cabecalho = _dados().split(b"RELEASE_DATE")[0]
    dados = (
        cabecalho
        + b"RELEASE_DATE;TRANSACTION_TYPE;REFERENCE_ID;TRANSACTION_NET_AMOUNT;PARTIAL_BALANCE\n"
    )

    extrato = ler_csv_mercadopago(dados)

    assert extrato.linhas == []
    assert extrato.saldo is None
    assert (extrato.periodo_inicio, extrato.periodo_fim) == (None, None)


def test_crlf_bom_e_cp1252_sao_aceitos():
    texto = _dados().decode("utf-8").replace("\n", "\r\n")

    assert len(ler_csv_mercadopago(b"\xef\xbb\xbf" + texto.encode("utf-8")).linhas) == 7
    em_cp1252 = ler_csv_mercadopago(texto.encode("cp1252")).linhas
    assert em_cp1252[3].descricao == "Pix enviado João Fictício"


def test_reference_id_repetido_nao_importa_nada():
    dados = _dados().replace(b"100000000004", b"100000000002")

    with pytest.raises(IdentificadorRepetido) as erro:
        ler_csv_mercadopago(dados)

    assert erro.value.campo == "REFERENCE_ID"
    assert [linha.descricao for linha in erro.value.linhas] == [
        "Dinheiro reservado Cofrinho Exemplo",
        "Pix enviado João Fictício",
    ]


@pytest.mark.parametrize(
    ("trocar", "por", "trecho"),
    [
        (b";100000000004;", b";;", "REFERENCE_ID"),
        (b"03-10-2026;Pix", b"2026-10-03;Pix", "data"),
        (b"03-10-2026;Pix", b"31-02-2026;Pix", "data"),
        (b";-64,90;", b";-64.90;", "valor"),
        (b";-64,90;", b";-64,905;", "valor"),
        (b";-64,90;", b";;", "valor"),
        (b";-64,90;1.035,22", b";-64,90", "colunas"),
    ],
)
def test_lancamento_incompleto_aponta_a_linha(trocar, por, trecho):
    dados = _dados()
    assert trocar in dados

    with pytest.raises(FormatoNaoReconhecido) as erro:
        ler_csv_mercadopago(dados.replace(trocar, por, 1))

    assert "lançamento 4" in erro.value.mensagem
    assert trecho in erro.value.mensagem


def test_saldo_ilegivel_aponta_a_linha():
    with pytest.raises(FormatoNaoReconhecido) as erro:
        ler_csv_mercadopago(_dados().replace(b"1,15;1.186,47", b"1,15;saldo"))

    assert "lançamento 7" in erro.value.mensagem


@pytest.mark.parametrize(
    "dados",
    [
        b"",
        b"date,title,amount\n2026-10-01,Padaria,10.00\n",
        b"%PDF-1.7 qualquer coisa",
    ],
)
def test_sem_o_cabecalho_dos_lancamentos_nao_e_reconhecido(dados):
    with pytest.raises(FormatoNaoReconhecido):
        ler_csv_mercadopago(dados)


def test_ler_extrato_escolhe_o_leitor_pelo_conteudo():
    ofx = (FIXTURES / "ofx" / "conta.ofx").read_bytes()

    assert ler_extrato(_dados()).fonte == FonteImportacao.csv_mercadopago
    assert ler_extrato(ofx).fonte == FonteImportacao.ofx


@pytest.mark.parametrize("dados", [b"", b"date,title,amount\n", b"%PDF-1.7 qualquer coisa"])
def test_ler_extrato_recusa_o_que_nao_e_ofx_nem_csv_do_mercado_pago(dados):
    with pytest.raises(FormatoNaoReconhecido) as erro:
        ler_extrato(dados)

    assert "nem um CSV do Mercado Pago" in erro.value.mensagem
