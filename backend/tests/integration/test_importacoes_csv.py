"""Importação do CSV do extrato do Mercado Pago pela API (spec
`2026-10-28-importacao-design`, adendo de 2026-10-29). Fixture fictícia em
`tests/fixtures/csv_mercadopago/`; o fluxo comum (hash do arquivo, tudo ou
nada, histórico) está em `test_importacoes.py`."""

import uuid
from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest
from sqlalchemy import func, select

from app.modulos.contas.models import SnapshotSaldo
from app.modulos.importacao.models import Importacao
from app.modulos.transacoes.models import Transacao

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures"
CABECALHO = b"RELEASE_DATE;TRANSACTION_TYPE;REFERENCE_ID;TRANSACTION_NET_AMOUNT;PARTIAL_BALANCE\n"


def _csv() -> bytes:
    return (FIXTURES / "csv_mercadopago" / "extrato.csv").read_bytes()


def _importar(api, conta, dados: bytes, nome="extrato.csv"):
    return api.post(
        "/importacoes",
        data={"conta_id": conta["id"]},
        files={"arquivo": (nome, dados, "text/csv")},
    )


def _ok(resposta, codigo=201) -> dict | None:
    assert resposta.status_code == codigo, resposta.text
    return resposta.json() if resposta.content else None


def _campos(resposta) -> dict:
    assert resposta.status_code == 422, resposta.json()
    return {campo["campo"]: campo["mensagem"] for campo in resposta.json()["campos"]}


def _transacoes(sessao, importacao_id) -> list[Transacao]:
    sessao.expire_all()
    return list(
        sessao.scalars(
            select(Transacao)
            .where(Transacao.importacao_id == uuid.UUID(importacao_id))
            .order_by(Transacao.data, Transacao.id_externo)
        )
    )


def _conta(api, nome: str, tipo: str, **extra) -> dict:
    return _ok(
        api.post(
            "/contas",
            json={
                "nome": nome,
                "tipo": tipo,
                "saldo_inicial": "100.00",
                "data_saldo_inicial": "2026-09-30",
            }
            | extra,
        )
    )


@pytest.fixture
def corrente(api) -> dict:
    return _conta(api, "Conta Exemplo", "corrente", instituicao="Banco Exemplo")


def test_extrato_entra_como_rascunhos_com_o_tipo_de_cada_linha(api, sessao, corrente):
    importacao = _ok(_importar(api, corrente, _csv()))["importacao"]

    assert importacao["fonte"] == "csv_mercadopago"
    assert (importacao["periodo_inicio"], importacao["periodo_fim"]) == ("2026-10-01", "2026-10-06")
    assert importacao["qtd_novas"] == 7
    assert importacao["saldo_extrato"] == {"valor": "1186.47", "data": "2026-10-06"}
    transacoes = _transacoes(sessao, importacao["id"])
    assert [(t.id_externo, t.tipo, t.valor, t.descricao) for t in transacoes] == [
        ("100000000001", "receita", Decimal("2500.00"), "Pix recebido Maria Exemplo"),
        ("1000000000003", "receita", Decimal("0.12"), "Rendimentos"),
        ("100000000002", "aporte", Decimal("1500.00"), "Dinheiro reservado Cofrinho Exemplo"),
        ("1000000000005", "receita", Decimal("0.10"), "Rendimentos"),
        ("100000000004", "despesa", Decimal("64.90"), "Pix enviado João Fictício"),
        ("100000000006", "resgate", Decimal("150.00"), "Dinheiro retirado Cofrinho Exemplo"),
        ("100000000007", "receita", Decimal("1.15"), "Venda de Produto Exemplo"),
    ]
    assert {(t.status, t.fonte, t.descricao_original == t.descricao) for t in transacoes} == {
        ("rascunho", "csv_mercadopago", True)
    }


def test_estorno(api, sessao, corrente):
    dados = _csv() + b"07-10-2026;Estorno Loja Exemplo;100000000008;64,90;1.251,37\n"

    importacao = _ok(_importar(api, corrente, dados))["importacao"]

    assert _transacoes(sessao, importacao["id"])[-1].tipo == "estorno"


def test_saldo_vira_snapshot_do_csv(api, sessao, corrente):
    importacao = _ok(_importar(api, corrente, _csv()))["importacao"]

    snapshot = sessao.scalar(select(SnapshotSaldo))
    assert snapshot is not None
    assert (snapshot.data, snapshot.saldo, snapshot.fonte, snapshot.importacao_id) == (
        date(2026, 10, 6),
        Decimal("1186.47"),
        "csv_mercadopago",
        uuid.UUID(importacao["id"]),
    )


def test_csv_sem_lancamentos_nao_grava_snapshot(api, sessao, corrente):
    dados = _csv().split(b"RELEASE_DATE")[0] + CABECALHO

    importacao = _ok(_importar(api, corrente, dados))["importacao"]

    assert importacao["qtd_novas"] == 0
    assert importacao["saldo_extrato"] is None
    assert sessao.scalar(select(func.count()).select_from(SnapshotSaldo)) == 0


def test_extrato_seguinte_com_sobreposicao_traz_so_as_novas(api, sessao, corrente):
    _ok(_importar(api, corrente, _csv()))
    seguinte = _csv() + b"07-10-2026;Pix enviado Padaria Exemplo;100000000008;-12,00;1.174,47\n"

    importacao = _ok(_importar(api, corrente, seguinte))["importacao"]

    assert (importacao["qtd_novas"], importacao["qtd_ja_importadas"]) == (1, 7)


def test_mesmo_identificador_por_ofx_nao_conta_como_ja_importado(api, sessao, corrente):
    # A fonte separa as idempotências: um FITID igual a um REFERENCE_ID é outra linha.
    sessao.add(
        Transacao(
            conta_id=uuid.UUID(corrente["id"]),
            tipo="despesa",
            valor=Decimal("9.99"),
            data=date(2026, 9, 1),
            descricao_original="Outra coisa",
            descricao="Outra coisa",
            status="rascunho",
            fonte="ofx",
            id_externo="100000000004",
        )
    )
    sessao.flush()

    importacao = _ok(_importar(api, corrente, _csv()))["importacao"]

    assert importacao["qtd_novas"] == 7


def test_possivel_duplicata_de_lancamento_manual(api, sessao, corrente):
    manual = _ok(
        api.post(
            "/transacoes",
            json={
                "conta_id": corrente["id"],
                "tipo": "despesa",
                "valor": "64.90",
                "data": "2026-10-04",
                "descricao": "Pix para o João",
            },
        )
    )

    importacao = _ok(_importar(api, corrente, _csv()))["importacao"]

    assert (importacao["qtd_novas"], importacao["qtd_possiveis_duplicatas"]) == (6, 1)
    (duplicata,) = [
        t for t in _transacoes(sessao, importacao["id"]) if t.possivel_duplicata_de is not None
    ]
    assert (duplicata.id_externo, str(duplicata.possivel_duplicata_de)) == (
        "100000000004",
        manual["id"],
    )


def test_csv_na_carteira_e_erro_no_campo_conta(api, sessao):
    conta = _conta(api, "Carteira", "carteira")

    assert _campos(_importar(api, conta, _csv())) == {
        "body.conta_id": "Este CSV é de extrato do Mercado Pago. Escolha uma conta corrente."
    }
    assert sessao.scalar(select(func.count()).select_from(Importacao)) == 0


def test_csv_em_cartao_e_erro_no_campo_conta(api, corrente):
    cartao = _ok(
        api.post(
            "/cartoes",
            json={
                "nome": "Cartão Exemplo",
                "instituicao": "Banco Exemplo",
                "conta_pagamento_id": corrente["id"],
                "dia_fechamento": 13,
                "dia_vencimento": 20,
            },
        )
    )

    assert "body.conta_id" in _campos(_importar(api, cartao, _csv()))


def test_reference_id_repetido_nao_importa_nada_e_mostra_as_linhas(api, sessao, corrente):
    dados = _csv().replace(b"100000000004", b"100000000002")

    resposta = _importar(api, corrente, dados)

    assert resposta.status_code == 422
    corpo = resposta.json()
    assert "(REFERENCE_ID)" in corpo["detail"]
    assert [linha["fitid"] for linha in corpo["linhas_repetidas"]] == ["100000000002"] * 2
    assert sessao.scalar(select(func.count()).select_from(Importacao)) == 0


def test_lancamento_ilegivel_e_erro_no_arquivo(api, corrente):
    dados = _csv().replace(b"03-10-2026;Pix", b"2026-10-03;Pix")

    mensagem = _campos(_importar(api, corrente, dados))["body.arquivo"]

    assert mensagem.startswith("Não reconheci este arquivo: o lançamento 4")


def test_desfazer_apaga_transacoes_snapshot_e_libera_o_arquivo(api, sessao, corrente):
    importacao = _ok(_importar(api, corrente, _csv()))["importacao"]

    _ok(api.delete(f"/importacoes/{importacao['id']}"), codigo=204)

    assert sessao.scalar(select(func.count()).select_from(Transacao)) == 0
    assert sessao.scalar(select(func.count()).select_from(SnapshotSaldo)) == 0
    assert _importar(api, corrente, _csv()).status_code == 201
