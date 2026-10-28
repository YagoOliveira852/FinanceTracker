"""Importação de OFX pela API (spec `2026-10-28-importacao-design`).

Fixtures fictícias em `tests/fixtures/ofx/`. O cartão dos testes fecha dia 13
e vence dia 20: a fatura de outubro/2026 fecha em 13/10 (terça) e vence em
20/10, como o `DTEND` de `fatura.ofx`; a de setembro fecha em 14/09 (13/09 é
domingo) e a de novembro em 13/11.
"""

import uuid
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path

import pytest
from sqlalchemy import func, select

from app.modulos.cartoes.models import Fatura
from app.modulos.contas.models import SnapshotSaldo
from app.modulos.importacao.models import Importacao
from app.modulos.transacoes.models import CompraParcelada, Transacao

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "ofx"


def _ofx(nome: str) -> bytes:
    return (FIXTURES / nome).read_bytes()


def _importar(api, conta, dados: bytes, nome="extrato.ofx"):
    return api.post(
        "/importacoes",
        data={"conta_id": conta["id"]},
        files={"arquivo": (nome, dados, "application/octet-stream")},
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


def _qtd_importacoes(sessao) -> int:
    return sessao.scalar(select(func.count()).select_from(Importacao))


@pytest.fixture
def corrente(api) -> dict:
    return _ok(
        api.post(
            "/contas",
            json={
                "nome": "Conta principal",
                "tipo": "corrente",
                "instituicao": "Banco Exemplo",
                "saldo_inicial": "1000.00",
                "data_saldo_inicial": "2026-10-01",
            },
        )
    )


@pytest.fixture
def cartao(api, corrente) -> dict:
    return _ok(
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


@pytest.fixture
def carteira(api) -> dict:
    return _ok(
        api.post(
            "/contas",
            json={
                "nome": "Carteira",
                "tipo": "carteira",
                "saldo_inicial": "50.00",
                "data_saldo_inicial": "2026-10-01",
            },
        )
    )


# --- Extrato da conta -------------------------------------------------------


def test_extrato_da_conta_entra_como_rascunhos(api, sessao, corrente):
    resumo = _ok(_importar(api, corrente, _ofx("conta.ofx"), "extrato-outubro.ofx"))

    importacao = resumo["importacao"]
    assert resumo["ja_importada"] is False
    assert importacao["nome_arquivo"] == "extrato-outubro.ofx"
    assert importacao["conta"] == {
        "id": corrente["id"],
        "nome": "Conta principal",
        "tipo": "corrente",
    }
    assert (importacao["periodo_inicio"], importacao["periodo_fim"]) == ("2026-10-01", "2026-10-15")
    assert importacao["qtd_novas"] == 5
    assert importacao["qtd_possiveis_duplicatas"] == 0
    assert importacao["qtd_ja_importadas"] == 0
    assert importacao["qtd_pendentes"] == 5
    assert importacao["qtd_confirmadas"] == 0
    assert importacao["pode_desfazer"] is True
    assert importacao["saldo_extrato"] == {"valor": "2340.15", "data": "2026-10-15"}
    assert importacao["fatura"] is None

    transacoes = _transacoes(sessao, importacao["id"])
    assert [(t.tipo, t.valor, t.data) for t in transacoes] == [
        ("receita", Decimal("2500.00"), date(2026, 10, 5)),
        ("despesa", Decimal("18.50"), date(2026, 10, 6)),
        ("estorno", Decimal("18.50"), date(2026, 10, 7)),
        ("pagamento_fatura", Decimal("1032.15"), date(2026, 10, 10)),
        ("despesa", Decimal("64.90"), date(2026, 10, 12)),
    ]
    padaria = transacoes[1]
    assert padaria.status == "rascunho"
    assert padaria.fonte == "ofx"
    assert padaria.id_externo == "0a1b2c3d-0000-4000-8000-000000000002"
    assert (
        padaria.descricao_original == padaria.descricao == "Compra no débito - Padaria Pão Quente"
    )
    assert padaria.categoria_id is None
    assert all(t.fatura_id is None for t in transacoes)


def test_extrato_aparece_na_revisao(api, corrente):
    _ok(_importar(api, corrente, _ofx("conta.ofx")))

    revisao = api.get("/revisao").json()

    assert revisao["total"] == 5
    assert len(revisao["pagamentos"]) == 1


def test_saldo_do_extrato_vira_snapshot(api, sessao, corrente):
    importacao = _ok(_importar(api, corrente, _ofx("conta.ofx")))["importacao"]

    snapshot = sessao.scalar(select(SnapshotSaldo))
    assert snapshot is not None
    assert (snapshot.conta_id, snapshot.data, snapshot.saldo, snapshot.fonte) == (
        uuid.UUID(corrente["id"]),
        date(2026, 10, 15),
        Decimal("2340.15"),
        "ofx",
    )
    assert snapshot.importacao_id == uuid.UUID(importacao["id"])


def test_snapshot_da_mesma_data_e_substituido(api, sessao, corrente):
    _ok(_importar(api, corrente, _ofx("conta.ofx")))
    outro = _ofx("conta.ofx").replace(b"<BALAMT>2340.15", b"<BALAMT>2299.99")

    segunda = _ok(_importar(api, corrente, outro))["importacao"]

    sessao.expire_all()
    snapshots = list(sessao.scalars(select(SnapshotSaldo)))
    assert [(s.saldo, s.importacao_id) for s in snapshots] == [
        (Decimal("2299.99"), uuid.UUID(segunda["id"]))
    ]


# --- Idempotência -------------------------------------------------------------


def test_mesmo_arquivo_de_novo_e_aviso_com_a_importacao_anterior(api, sessao, corrente):
    primeira = _ok(_importar(api, corrente, _ofx("conta.ofx")))["importacao"]

    resposta = _ok(_importar(api, corrente, _ofx("conta.ofx"), "outro-nome.ofx"), codigo=200)

    assert resposta["ja_importada"] is True
    assert resposta["importacao"]["id"] == primeira["id"]
    assert resposta["importacao"]["nome_arquivo"] == "extrato.ofx"
    assert _qtd_importacoes(sessao) == 1


def test_mesmo_arquivo_em_outra_conta_tambem_e_aviso(api, sessao, corrente):
    outra = _ok(
        api.post(
            "/contas",
            json={
                "nome": "Conta do dia a dia",
                "tipo": "corrente",
                "instituicao": "Banco Fictício",
                "saldo_inicial": "0.00",
                "data_saldo_inicial": "2026-10-01",
            },
        )
    )
    _ok(_importar(api, corrente, _ofx("conta.ofx")))

    resposta = _ok(_importar(api, outra, _ofx("conta.ofx")), codigo=200)

    assert resposta["importacao"]["conta"]["id"] == corrente["id"]


def test_linhas_ja_importadas_ficam_de_fora_mesmo_ignoradas(api, sessao, corrente):
    primeira = _ok(_importar(api, corrente, _ofx("conta.ofx")))["importacao"]
    ignorada = _transacoes(sessao, primeira["id"])[0]
    _ok(api.post(f"/revisao/transacoes/{ignorada.id}/ignorar"), codigo=204)
    # Outro arquivo (outro hash) com os mesmos lançamentos e um novo.
    novo = _ofx("conta.ofx").replace(
        b"</BANKTRANLIST>",
        b"<STMTTRN>\n<TRNTYPE>DEBIT</TRNTYPE>\n<DTPOSTED>20261016000000[-3:BRT]</DTPOSTED>\n"
        b"<TRNAMT>-9.90</TRNAMT>\n<FITID>0a1b2c3d-0000-4000-8000-000000000006</FITID>\n"
        b"<MEMO>Compra no d\xc3\xa9bito - Banca de Jornal</MEMO>\n</STMTTRN>\n</BANKTRANLIST>",
    )

    segunda = _ok(_importar(api, corrente, novo))["importacao"]

    assert (segunda["qtd_novas"], segunda["qtd_ja_importadas"]) == (1, 5)
    assert [t.valor for t in _transacoes(sessao, segunda["id"])] == [Decimal("9.90")]


# --- Possível duplicata -------------------------------------------------------


def _lancar(api, conta, data, valor="64.90", tipo="despesa", descricao="Mercado") -> dict:
    return _ok(
        api.post(
            "/transacoes",
            json={
                "conta_id": conta["id"],
                "tipo": tipo,
                "valor": valor,
                "data": data,
                "descricao": descricao,
            },
        )
    )


def test_possivel_duplicata_de_lancamento_manual(api, sessao, corrente):
    manual = _lancar(api, corrente, "2026-10-11")
    _lancar(api, corrente, "2026-10-11", valor="18.50", tipo="receita")  # sentido oposto

    importacao = _ok(_importar(api, corrente, _ofx("conta.ofx")))["importacao"]

    assert (importacao["qtd_novas"], importacao["qtd_possiveis_duplicatas"]) == (4, 1)
    marcadas = [t for t in _transacoes(sessao, importacao["id"]) if t.possivel_duplicata_de]
    assert [(t.valor, t.possivel_duplicata_de) for t in marcadas] == [
        (Decimal("64.90"), uuid.UUID(manual["id"]))
    ]
    assert [d["outra"]["id"] for d in api.get("/revisao").json()["duplicatas"]] == [manual["id"]]


def test_manual_a_tres_dias_ou_ignorado_nao_e_duplicata(api, sessao, corrente):
    _lancar(api, corrente, "2026-10-09")  # 3 dias antes de 12/10
    ignorado = _lancar(api, corrente, "2026-10-12")
    sessao.get(Transacao, uuid.UUID(ignorado["id"])).status = "ignorada"
    sessao.flush()

    importacao = _ok(_importar(api, corrente, _ofx("conta.ofx")))["importacao"]

    assert importacao["qtd_possiveis_duplicatas"] == 0


def test_manual_de_outra_conta_nao_e_duplicata(api, corrente, carteira):
    _lancar(api, carteira, "2026-10-12")

    importacao = _ok(_importar(api, corrente, _ofx("conta.ofx")))["importacao"]

    assert importacao["qtd_possiveis_duplicatas"] == 0


# --- Fatura do cartão ---------------------------------------------------------


def test_fatura_do_cartao(api, sessao, cartao):
    importacao = _ok(_importar(api, cartao, _ofx("fatura.ofx"), "fatura-outubro.ofx"))["importacao"]

    assert importacao["qtd_novas"] == 5  # "Pagamento recebido" fica de fora
    assert importacao["qtd_parcelas"] == 1
    assert importacao["saldo_extrato"] is None
    assert importacao["fatura"] == {
        "competencia": "2026-10-01",
        "valor_informado": "202.84",
        "data_fechamento": "2026-10-13",
    }
    transacoes = _transacoes(sessao, importacao["id"])
    assert [(t.tipo, t.valor, t.id_externo[-4:]) for t in transacoes] == [
        ("despesa", Decimal("120.00"), "0001"),
        ("despesa", Decimal("45.00"), "0002"),
        ("despesa", Decimal("2.94"), ":iof"),
        ("estorno", Decimal("30.00"), "0004"),
        ("despesa", Decimal("64.90"), "0005"),
    ]
    fatura = sessao.get(Fatura, transacoes[0].fatura_id)
    assert {t.fatura_id for t in transacoes} == {fatura.id}
    assert (fatura.competencia, fatura.valor_informado, fatura.data_fechamento) == (
        date(2026, 10, 1),
        Decimal("202.84"),
        date(2026, 10, 13),
    )
    assert sessao.scalar(select(func.count()).select_from(SnapshotSaldo)) == 0


def test_parcela_cria_compra_com_data_estimada(api, sessao, cartao):
    importacao = _ok(_importar(api, cartao, _ofx("fatura.ofx")))["importacao"]

    parcela = _transacoes(sessao, importacao["id"])[0]
    compra = sessao.get(CompraParcelada, parcela.compra_parcelada_id)
    assert parcela.parcela_numero == 3
    assert (compra.descricao, compra.qtd_parcelas, compra.valor_total) == (
        "Loja Ficticia",
        10,
        Decimal("1200.00"),
    )
    assert (compra.data_compra, compra.data_compra_estimada) == (date(2026, 7, 15), True)


def test_parcela_seguinte_reaproveita_a_compra(api, sessao, cartao):
    primeira = _ok(_importar(api, cartao, _ofx("fatura.ofx")))["importacao"]
    novembro = (
        _ofx("fatura.ofx")
        .replace(b"<DTSTART>20260913", b"<DTSTART>20261013")
        .replace(b"<DTEND>20261013", b"<DTEND>20261113")
        .replace(b"20260915000000[-3:BRT]</DTPOSTED>", b"20261016000000[-3:BRT]</DTPOSTED>")
        .replace(b"Parcela 3/10", b"Parcela 4/10")
        .replace(b"1b2c3d4e-0000-4000-8000-000000000001", b"1b2c3d4e-0000-4000-8000-0000000000a1")
    )

    segunda = _ok(_importar(api, cartao, novembro))["importacao"]

    compra_1 = _transacoes(sessao, primeira["id"])[0].compra_parcelada_id
    parcela_4 = next(t for t in _transacoes(sessao, segunda["id"]) if t.parcela_numero)
    assert parcela_4.parcela_numero == 4
    assert parcela_4.compra_parcelada_id == compra_1
    assert sessao.scalar(select(func.count()).select_from(CompraParcelada)) == 1


def test_fatura_escolhida_pelo_fechamento_mais_perto(api, sessao, cartao):
    # O banco fechou em 15/10, dois dias depois da regra (13/10): continua
    # sendo a fatura de outubro, não a de novembro.
    dados = _ofx("fatura.ofx").replace(b"<DTEND>20261013", b"<DTEND>20261015")

    importacao = _ok(_importar(api, cartao, dados))["importacao"]

    assert importacao["fatura"]["competencia"] == "2026-10-01"
    assert importacao["fatura"]["data_fechamento"] == "2026-10-15"


def test_fechamento_fora_dos_vizinhos_e_erro(api, sessao, cartao):
    # 25/10 fica depois do vencimento de outubro (20/10) e perto demais do
    # fechamento de novembro: não combina com o cartão.
    dados = _ofx("fatura.ofx").replace(b"<DTEND>20261013", b"<DTEND>20261025")

    campos = _campos(_importar(api, cartao, dados))

    assert "body.arquivo" in campos
    assert _qtd_importacoes(sessao) == 0


def test_fatura_credora_grava_valor_zero(api, sessao, cartao):
    dados = _ofx("fatura.ofx").replace(b"<BALAMT>-202.84", b"<BALAMT>15.00")

    importacao = _ok(_importar(api, cartao, dados))["importacao"]

    assert importacao["fatura"]["valor_informado"] == "0.00"


def _competencia(sessao, transacao_id) -> date:
    sessao.expire_all()
    transacao = sessao.get(Transacao, uuid.UUID(str(transacao_id)))
    return sessao.get(Fatura, transacao.fatura_id).competencia


def test_compra_manual_e_realocada_mas_importada_nao(api, sessao, cartao):
    # Compra manual em 14/10 cai na fatura de novembro pela regra (fecha 13/10).
    manual = _lancar(api, cartao, "2026-10-14", valor="10.00", descricao="Padaria")
    # O OFX diz que outubro fechou em 15/10: a manual volta para outubro.
    dados = _ofx("fatura.ofx").replace(b"<DTEND>20261013", b"<DTEND>20261015")
    importacao = _ok(_importar(api, cartao, dados))["importacao"]
    assert _competencia(sessao, manual["id"]) == date(2026, 10, 1)

    # Antecipar o fechamento de outubro para 01/10 manda para novembro a
    # manual, mas a importada de 02/10 fica onde o banco disse.
    _ok(
        api.put(
            f"/cartoes/{cartao['id']}/faturas/2026-10",
            json={
                "data_fechamento": "2026-10-01",
                "data_vencimento": "2026-10-20",
                "valor_informado": "202.84",
            },
        ),
        codigo=200,
    )

    importadas = _transacoes(sessao, importacao["id"])
    assert {_competencia(sessao, t.id) for t in importadas} == {date(2026, 10, 1)}
    assert _competencia(sessao, manual["id"]) == date(2026, 11, 1)


# --- Arquivo × conta e erros --------------------------------------------------


def test_fatura_em_conta_corrente_e_erro_no_campo_conta(api, sessao, corrente):
    campos = _campos(_importar(api, corrente, _ofx("fatura.ofx")))

    assert campos == {"body.conta_id": "Este OFX é de fatura de cartão. Escolha um cartão."}
    assert _qtd_importacoes(sessao) == 0


def test_extrato_de_conta_em_cartao_e_erro(api, cartao):
    campos = _campos(_importar(api, cartao, _ofx("conta.ofx")))

    assert campos == {
        "body.conta_id": "Este OFX é de extrato de conta. Escolha uma conta corrente."
    }


def test_extrato_de_conta_na_carteira_e_erro(api, carteira):
    assert "body.conta_id" in _campos(_importar(api, carteira, _ofx("conta.ofx")))


def test_conta_inexistente_e_erro(api):
    campos = _campos(_importar(api, {"id": str(uuid.uuid4())}, _ofx("conta.ofx")))

    assert campos == {"body.conta_id": "Conta não encontrada."}


def test_conta_id_malformado_e_422(api):
    assert "body.conta_id" in _campos(_importar(api, {"id": "abc"}, _ofx("conta.ofx")))


def test_sem_arquivo_e_422(api, corrente):
    resposta = api.post("/importacoes", data={"conta_id": corrente["id"]})

    assert "body.arquivo" in _campos(resposta)


def test_formato_nao_reconhecido(api, sessao, corrente):
    campos = _campos(_importar(api, corrente, b"Data,Valor\n2026-10-01,10.00\n", "gastos.csv"))

    assert campos["body.arquivo"].startswith("Não reconheci este arquivo")
    assert _qtd_importacoes(sessao) == 0


def test_arquivo_grande_demais(api, corrente):
    grande = _ofx("conta.ofx") + b" " * (5 * 1024 * 1024)

    assert _campos(_importar(api, corrente, grande)) == {"body.arquivo": "O arquivo passa de 5 MB."}


def test_fitid_repetido_nao_importa_nada_e_mostra_as_linhas(api, sessao, cartao):
    resposta = _importar(api, cartao, _ofx("fitid_repetido.ofx"))

    assert resposta.status_code == 422
    corpo = resposta.json()
    assert corpo["detail"].startswith("Nada foi importado")
    assert (
        corpo["linhas_repetidas"]
        == [
            {
                "fitid": "1b2c3d4e-0000-4000-8000-000000000005",
                "data": "2026-10-02",
                "valor": "-64.90",
                "descricao": "Mercado do Bairro",
            }
        ]
        * 2
    )
    assert _qtd_importacoes(sessao) == 0
    assert sessao.scalar(select(func.count()).select_from(Transacao)) == 0
    # O hash não foi gravado: o mesmo arquivo continua dando o mesmo erro.
    assert _importar(api, cartao, _ofx("fitid_repetido.ofx")).status_code == 422


# --- Histórico e resumo -------------------------------------------------------


def test_historico_do_mais_recente_para_o_mais_antigo(api, sessao, corrente, cartao):
    conta = _ok(_importar(api, corrente, _ofx("conta.ofx"), "extrato.ofx"))["importacao"]
    # Dentro da transação do teste, now() é o mesmo para as duas importações.
    sessao.get(Importacao, uuid.UUID(conta["id"])).criado_em -= timedelta(minutes=1)
    sessao.flush()
    fatura = _ok(_importar(api, cartao, _ofx("fatura.ofx"), "fatura.ofx"))["importacao"]

    historico = api.get("/importacoes").json()

    assert [item["id"] for item in historico] == [fatura["id"], conta["id"]]
    assert historico[0]["conta"]["tipo"] == "cartao_credito"


def test_resumo_conta_confirmadas_e_pendentes_na_leitura(api, sessao, corrente):
    importacao = _ok(_importar(api, corrente, _ofx("conta.ofx")))["importacao"]
    for transacao in _transacoes(sessao, importacao["id"])[:2]:
        transacao.status = "confirmada"
    sessao.flush()

    resumo = _ok(api.get(f"/importacoes/{importacao['id']}"), codigo=200)

    assert (resumo["qtd_confirmadas"], resumo["qtd_pendentes"]) == (2, 3)
    assert resumo["pode_desfazer"] is False


def test_importacao_inexistente_e_404(api):
    resposta = api.get(f"/importacoes/{uuid.uuid4()}")

    assert resposta.status_code == 404
    assert resposta.json() == {"detail": "Importação não encontrada."}


def test_sem_login_e_401(client):
    assert client.get("/importacoes").status_code == 401


# --- Desfazer -----------------------------------------------------------------


def test_desfazer_apaga_transacoes_snapshot_e_libera_o_arquivo(api, sessao, corrente):
    importacao = _ok(_importar(api, corrente, _ofx("conta.ofx")))["importacao"]
    ignorada = _transacoes(sessao, importacao["id"])[0]
    _ok(api.post(f"/revisao/transacoes/{ignorada.id}/ignorar"), codigo=204)

    resposta = api.delete(f"/importacoes/{importacao['id']}")

    assert resposta.status_code == 204
    sessao.expire_all()
    assert sessao.scalar(select(func.count()).select_from(Transacao)) == 0
    assert sessao.scalar(select(func.count()).select_from(SnapshotSaldo)) == 0
    assert _qtd_importacoes(sessao) == 0
    assert _ok(_importar(api, corrente, _ofx("conta.ofx")))["ja_importada"] is False


def test_desfazer_com_confirmada_e_409(api, sessao, corrente):
    importacao = _ok(_importar(api, corrente, _ofx("conta.ofx")))["importacao"]
    _transacoes(sessao, importacao["id"])[0].status = "confirmada"
    sessao.flush()

    resposta = api.delete(f"/importacoes/{importacao['id']}")

    assert resposta.status_code == 409
    assert resposta.json()["detail"].startswith("Não dá mais para desfazer")
    assert len(_transacoes(sessao, importacao["id"])) == 5


def test_desfazer_inexistente_e_404(api):
    assert api.delete(f"/importacoes/{uuid.uuid4()}").status_code == 404


def test_desfazer_mantem_o_manual_e_limpa_a_marca_de_duplicata(api, sessao, corrente):
    manual = _lancar(api, corrente, "2026-10-12")
    importacao = _ok(_importar(api, corrente, _ofx("conta.ofx")))["importacao"]

    _ok(api.delete(f"/importacoes/{importacao['id']}"), codigo=204)

    sessao.expire_all()
    assert sessao.get(Transacao, uuid.UUID(manual["id"])).status == "confirmada"


def test_desfazer_fatura_volta_valor_e_fechamento_anteriores(api, sessao, cartao):
    _ok(
        api.put(
            f"/cartoes/{cartao['id']}/faturas/2026-10",
            json={
                "data_fechamento": "2026-10-14",
                "data_vencimento": "2026-10-20",
                "valor_informado": "100.00",
            },
        ),
        codigo=200,
    )
    importacao = _ok(_importar(api, cartao, _ofx("fatura.ofx")))["importacao"]

    _ok(api.delete(f"/importacoes/{importacao['id']}"), codigo=204)

    sessao.expire_all()
    fatura = sessao.scalar(select(Fatura).where(Fatura.competencia == date(2026, 10, 1)))
    assert (fatura.valor_informado, fatura.data_fechamento) == (
        Decimal("100.00"),
        date(2026, 10, 14),
    )
    assert sessao.scalar(select(func.count()).select_from(CompraParcelada)) == 0


def test_desfazer_fatura_criada_volta_ao_calculado(api, sessao, cartao):
    dados = _ofx("fatura.ofx").replace(b"<DTEND>20261013", b"<DTEND>20261015")
    importacao = _ok(_importar(api, cartao, dados))["importacao"]

    _ok(api.delete(f"/importacoes/{importacao['id']}"), codigo=204)

    sessao.expire_all()
    fatura = sessao.scalar(select(Fatura).where(Fatura.competencia == date(2026, 10, 1)))
    assert (fatura.valor_informado, fatura.data_fechamento) == (None, date(2026, 10, 13))


def test_desfazer_nao_mexe_na_fatura_editada_depois(api, sessao, cartao):
    importacao = _ok(_importar(api, cartao, _ofx("fatura.ofx")))["importacao"]
    _ok(
        api.put(
            f"/cartoes/{cartao['id']}/faturas/2026-10",
            json={
                "data_fechamento": "2026-10-13",
                "data_vencimento": "2026-10-20",
                "valor_informado": "250.00",
            },
        ),
        codigo=200,
    )

    _ok(api.delete(f"/importacoes/{importacao['id']}"), codigo=204)

    sessao.expire_all()
    fatura = sessao.scalar(select(Fatura).where(Fatura.competencia == date(2026, 10, 1)))
    assert fatura.valor_informado == Decimal("250.00")


def test_desfazer_mantem_a_compra_parcelada_que_tem_parcela_de_outra_importacao(
    api, sessao, cartao
):
    primeira = _ok(_importar(api, cartao, _ofx("fatura.ofx")))["importacao"]
    novembro = (
        _ofx("fatura.ofx")
        .replace(b"<DTEND>20261013", b"<DTEND>20261113")
        .replace(b"20260915000000[-3:BRT]</DTPOSTED>", b"20261015000000[-3:BRT]</DTPOSTED>")
        .replace(b"Parcela 3/10", b"Parcela 4/10")
        .replace(b"1b2c3d4e-0000-4000-8000-000000000001", b"1b2c3d4e-0000-4000-8000-0000000000a1")
    )
    _ok(_importar(api, cartao, novembro))

    _ok(api.delete(f"/importacoes/{primeira['id']}"), codigo=204)

    sessao.expire_all()
    compra = sessao.scalar(select(CompraParcelada))
    assert compra is not None
    assert [parcela.parcela_numero for parcela in compra.parcelas] == [4]
