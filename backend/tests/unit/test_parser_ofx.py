"""Leitor de OFX (função pura): fixtures fictícias no formato das amostras do
Nubank (spec `2026-10-28-importacao-design`, "Leitura do OFX")."""

from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest

from app.modulos.importacao.parsers.ofx import (
    FitidRepetido,
    FormatoNaoReconhecido,
    TipoExtrato,
    ler_ofx,
)

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "ofx"


def _ler(nome: str):
    return ler_ofx((FIXTURES / nome).read_bytes())


def test_extrato_da_conta():
    extrato = _ler("conta.ofx")

    assert extrato.tipo == TipoExtrato.conta
    assert (extrato.periodo_inicio, extrato.periodo_fim) == (date(2026, 10, 1), date(2026, 10, 15))
    assert extrato.saldo is not None
    assert (extrato.saldo.valor, extrato.saldo.data) == (Decimal("2340.15"), date(2026, 10, 15))
    assert [(linha.data, linha.valor) for linha in extrato.linhas] == [
        (date(2026, 10, 5), Decimal("2500.00")),
        (date(2026, 10, 6), Decimal("-18.50")),
        (date(2026, 10, 7), Decimal("18.50")),
        (date(2026, 10, 10), Decimal("-1032.15")),
        (date(2026, 10, 12), Decimal("-64.90")),
    ]


def test_descricao_em_utf8_e_fitid_como_id_externo():
    linha = _ler("conta.ofx").linhas[1]

    assert linha.descricao == "Compra no débito - Padaria Pão Quente"
    assert linha.fitid == linha.id_externo == "0a1b2c3d-0000-4000-8000-000000000002"
    assert linha.parcela is None


def test_fatura_do_cartao():
    extrato = _ler("fatura.ofx")

    assert extrato.tipo == TipoExtrato.fatura
    assert (extrato.periodo_inicio, extrato.periodo_fim) == (date(2026, 9, 13), date(2026, 10, 13))
    assert extrato.saldo is not None
    assert extrato.saldo.valor == Decimal("-202.84")
    assert len(extrato.linhas) == 6


def test_iof_usa_fitid_com_sufixo():
    compra, iof = _ler("fatura.ofx").linhas[1:3]

    assert compra.fitid == iof.fitid
    assert compra.id_externo == compra.fitid
    assert iof.id_externo == f"{iof.fitid}:iof"
    assert iof.descricao == 'IOF de "Streaming Exemplo"'


def test_parcela():
    linha = _ler("fatura.ofx").linhas[0]

    assert linha.parcela is not None
    assert (linha.parcela.numero, linha.parcela.total) == (3, 10)
    assert linha.parcela.descricao == "Loja Ficticia"
    assert linha.descricao == "Loja Ficticia - Parcela 3/10"


@pytest.mark.parametrize(
    ("memo", "parcela"),
    [
        ("Loja - Parcela 1/2", (1, 2)),
        ("Loja - Parcela 12/12", (12, 12)),
        ("Loja - Parcela 3/1", None),  # número maior que o total
        ("Loja - Parcela 0/3", None),
        ("Loja - Parcela 1/1", None),  # 1x não é parcelada
        ("Parcela 2/3", None),  # sem descrição antes
        ("Loja Parcela 2/3", None),  # sem o " - "
    ],
)
def test_reconhece_parcela_pelo_sufixo(memo, parcela):
    dados = (
        (FIXTURES / "fatura.ofx")
        .read_bytes()
        .replace(b"Loja Ficticia - Parcela 3/10", memo.encode())
    )

    lida = ler_ofx(dados).linhas[0].parcela

    assert (None if lida is None else (lida.numero, lida.total)) == parcela


def test_fitid_repetido_falha_com_as_linhas():
    with pytest.raises(FitidRepetido) as erro:
        _ler("fitid_repetido.ofx")

    assert [linha.fitid for linha in erro.value.linhas] == [
        "1b2c3d4e-0000-4000-8000-000000000005",
        "1b2c3d4e-0000-4000-8000-000000000005",
    ]
    assert erro.value.linhas[0].descricao == "Mercado do Bairro"
    assert erro.value.linhas[0].valor == Decimal("-64.90")


def test_folhas_sem_fechamento_crlf_cp1252_e_valor_zero():
    extrato = _ler("sem_fechamento.ofx")

    assert extrato.tipo == TipoExtrato.conta
    # A linha de valor zero não entra; NAME vale quando não há MEMO; entidade
    # SGML (&amp;) volta a ser o caractere; vírgula decimal é aceita.
    assert [(linha.descricao, linha.valor) for linha in extrato.linhas] == [
        ("Café Fictício & Cia", Decimal("-7.50"))
    ]
    assert extrato.saldo is not None
    assert extrato.saldo.valor == Decimal("-12.30")


def test_bom_utf8_e_aceito():
    extrato = ler_ofx(b"\xef\xbb\xbf" + (FIXTURES / "conta.ofx").read_bytes())

    assert len(extrato.linhas) == 5


@pytest.mark.parametrize(
    "dados",
    [
        b"",
        b"Data,Valor,Identificador,Descricao\n2026-10-01,10.00,abc,Padaria\n",
        b"%PDF-1.7 qualquer coisa",
        b"OFXHEADER:100\n\n<OFX><SIGNONMSGSRSV1></SIGNONMSGSRSV1></OFX>",  # sem extrato
    ],
)
def test_formato_nao_reconhecido(dados):
    with pytest.raises(FormatoNaoReconhecido):
        ler_ofx(dados)


@pytest.mark.parametrize(
    ("trocar", "por", "trecho"),
    [
        (b"<FITID>0a1b2c3d-0000-4000-8000-000000000002</FITID>", b"", "FITID"),
        (b"<DTPOSTED>20261006000000[-3:BRT]</DTPOSTED>", b"", "data"),
        (b"<DTPOSTED>20261006000000", b"<DTPOSTED>20261306000000", "data"),
        (b"<TRNAMT>-18.50</TRNAMT>", b"<TRNAMT>dezoito</TRNAMT>", "valor"),
        (b"<TRNAMT>-18.50</TRNAMT>", b"", "valor"),
        (b"<TRNAMT>-18.50</TRNAMT>", b"<TRNAMT>-18.505</TRNAMT>", "valor"),
    ],
)
def test_lancamento_incompleto_aponta_a_linha(trocar, por, trecho):
    dados = (FIXTURES / "conta.ofx").read_bytes()
    assert trocar in dados

    with pytest.raises(FormatoNaoReconhecido) as erro:
        ler_ofx(dados.replace(trocar, por))

    assert "lançamento 2" in erro.value.mensagem
    assert trecho in erro.value.mensagem


def test_muitas_aberturas_sem_fechamento_terminam_rapido():
    # Proteção contra o regex quadrático: 5 MB de `<STMTTRN>` soltos.
    dados = (FIXTURES / "conta.ofx").read_bytes().replace(
        b"</BANKTRANLIST>", b"<STMTTRN>" * 500_000 + b"</BANKTRANLIST>"
    )

    assert len(ler_ofx(dados).linhas) == 5
