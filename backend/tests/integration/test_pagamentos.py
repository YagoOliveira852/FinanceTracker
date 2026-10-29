"""Pagamento de fatura pela API e o status `paga`.

Exemplo de referência (plano 2026-10-25): cartão fecha dia 3 e vence dia 10;
hoje = 2026-10-20. Outubro fechou em 05/10 e vence em 13/10 (fechada);
novembro fecha em 03/11 e vence em 10/11 (a atual, aberta). Uma compra em
01/10 entra em outubro.
"""

import uuid
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import func, select

from app.core.deps import get_hoje
from app.main import app
from app.modulos.cartoes.models import Fatura
from app.modulos.contas.models import Conta
from app.modulos.transacoes.models import Transacao


@pytest.fixture
def corrente(api) -> dict:
    resposta = api.post(
        "/contas",
        json={
            "nome": "Conta principal",
            "tipo": "corrente",
            "instituicao": "Banco Exemplo",
            "saldo_inicial": "1000.00",
            "data_saldo_inicial": "2026-10-01",
        },
    )
    assert resposta.status_code == 201
    return resposta.json()


@pytest.fixture
def cartao(api, corrente) -> dict:
    resposta = api.post(
        "/cartoes",
        json={
            "nome": "Cartão Exemplo",
            "instituicao": "Banco Exemplo",
            "conta_pagamento_id": corrente["id"],
            "dia_fechamento": 3,
            "dia_vencimento": 10,
        },
    )
    assert resposta.status_code == 201
    return resposta.json()


def _url(cartao, resto="") -> str:
    return f"/cartoes/{cartao['id']}/faturas{resto}"


def _comprar(api, cartao, data, valor="100.00") -> dict:
    resposta = api.post(
        "/transacoes",
        json={
            "conta_id": cartao["id"],
            "tipo": "despesa",
            "valor": valor,
            "data": data,
            "descricao": "Mercado do bairro",
        },
    )
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


def _pagar(api, cartao, competencia, conta, valor="100.00", data="2026-10-13"):
    return api.post(
        _url(cartao, f"/{competencia}/pagamentos"),
        json={"conta_id": conta["id"], "valor": valor, "data": data},
    )


def _pago(api, cartao, competencia, conta, valor="100.00", data="2026-10-13") -> dict:
    resposta = _pagar(api, cartao, competencia, conta, valor, data)
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


def _detalhe(api, cartao, competencia) -> dict:
    resposta = api.get(_url(cartao, f"/{competencia}"))
    assert resposta.status_code == 200
    return resposta.json()


def _campos(resposta) -> dict:
    assert resposta.status_code == 422
    return {erro["campo"]: erro["mensagem"] for erro in resposta.json()["campos"]}


def _outubro(sessao, cartao) -> Fatura:
    return sessao.scalar(
        select(Fatura).where(
            Fatura.cartao_id == uuid.UUID(cartao["id"]), Fatura.competencia == date(2026, 10, 1)
        )
    )


def test_pagamento_total_deixa_paga(api, cartao, corrente):
    compra = _comprar(api, cartao, "2026-10-01")

    detalhe = _pago(api, cartao, "2026-10", corrente)

    assert detalhe["status"] == "paga"
    assert detalhe["valor_pago"] == "100.00"
    assert detalhe["valor_calculado"] == "100.00"
    [pagamento] = detalhe["pagamentos"]
    assert pagamento["tipo"] == "pagamento_fatura"
    assert pagamento["conta_id"] == corrente["id"]
    assert pagamento["descricao"] == "Pagamento de fatura · Cartão Exemplo"
    assert (pagamento["data"], pagamento["valor"]) == ("2026-10-13", "100.00")
    assert [t["id"] for t in detalhe["transacoes"]] == [compra["id"]]
    assert api.get(f"/contas/{corrente['id']}").json()["saldo_atual"] == "900.00"


def test_pagamento_parcial_continua_fechada(api, cartao, corrente):
    _comprar(api, cartao, "2026-10-01")

    parcial = _pago(api, cartao, "2026-10", corrente, valor="40.00", data="2026-10-09")
    assert (parcial["status"], parcial["valor_pago"]) == ("fechada", "40.00")

    completa = _pago(api, cartao, "2026-10", corrente, valor="60.00", data="2026-10-13")
    assert (completa["status"], completa["valor_pago"]) == ("paga", "100.00")
    assert [p["data"] for p in completa["pagamentos"]] == ["2026-10-09", "2026-10-13"]


def test_pagar_a_mais_deixa_paga(api, cartao, corrente):
    _comprar(api, cartao, "2026-10-01")

    detalhe = _pago(api, cartao, "2026-10", corrente, valor="150.00")

    assert (detalhe["status"], detalhe["valor_pago"]) == ("paga", "150.00")


def test_pagamento_adiantado_na_aberta(api, cartao, corrente):
    _comprar(api, cartao, "2026-10-20", valor="50.00")

    detalhe = _pago(api, cartao, "2026-11", corrente, valor="50.00", data="2026-10-20")
    assert (detalhe["status"], detalhe["valor_pago"]) == ("aberta", "50.00")

    app.dependency_overrides[get_hoje] = lambda: date(2026, 11, 3)
    assert _detalhe(api, cartao, "2026-11")["status"] == "paga"


def test_compra_nova_volta_para_fechada(api, cartao, corrente):
    _comprar(api, cartao, "2026-10-01")
    _pago(api, cartao, "2026-10", corrente)

    _comprar(api, cartao, "2026-10-02", valor="10.00")

    assert _detalhe(api, cartao, "2026-10")["status"] == "fechada"


def test_ajuste_maior_volta_para_fechada(api, cartao, corrente):
    _comprar(api, cartao, "2026-10-01")
    _pago(api, cartao, "2026-10", corrente)

    resposta = api.post(_url(cartao, "/2026-10/ajuste"), json={"valor_real": "150.00"})

    assert resposta.status_code == 200
    assert resposta.json()["status"] == "fechada"


def test_pagar_fatura_so_calculada_grava_a_fatura(api, sessao, cartao, corrente):
    detalhe = _pago(api, cartao, "2026-12", corrente, valor="30.00", data="2026-10-20")

    assert detalhe["status"] == "aberta"
    assert detalhe["valor_pago"] == "30.00"
    gravada = sessao.scalar(
        select(Fatura).where(
            Fatura.cartao_id == uuid.UUID(cartao["id"]), Fatura.competencia == date(2026, 12, 1)
        )
    )
    assert gravada is not None


def test_pagamento_fora_das_compras_e_da_realocacao(api, sessao, cartao, corrente):
    _comprar(api, cartao, "2026-10-01")
    pagamento = _pago(api, cartao, "2026-10", corrente)["pagamentos"][0]

    resposta = api.put(
        _url(cartao, "/2026-10"),
        json={
            "data_fechamento": "2026-10-02",
            "data_vencimento": "2026-10-13",
            "valor_informado": None,
        },
    )

    assert resposta.status_code == 200
    detalhe = resposta.json()
    assert [p["id"] for p in detalhe["pagamentos"]] == [pagamento["id"]]
    assert pagamento["id"] not in {t["id"] for t in detalhe["transacoes"]}
    assert detalhe["valor_calculado"] == "100.00"
    transacao = sessao.get(Transacao, uuid.UUID(pagamento["id"]))
    sessao.refresh(transacao)
    assert transacao.fatura_id == _outubro(sessao, cartao).id


def test_valor_pago_conta_rascunho_e_nao_ignorada_nem_cartao(api, sessao, cartao, corrente):
    _comprar(api, cartao, "2026-10-01")
    fatura = _outubro(sessao, cartao)
    for conta_id, status, valor in [
        (corrente["id"], "rascunho", "30.00"),
        (corrente["id"], "ignorada", "20.00"),
        (cartao["id"], "confirmada", "50.00"),
    ]:
        sessao.add(
            Transacao(
                conta_id=uuid.UUID(conta_id),
                tipo="pagamento_fatura",
                valor=Decimal(valor),
                data=date(2026, 10, 13),
                descricao_original="Pagamento de fatura",
                descricao="Pagamento de fatura",
                status=status,
                fonte="pluggy",
                id_externo=str(uuid.uuid4()),
                fatura_id=fatura.id,
            )
        )
    sessao.flush()

    detalhe = _detalhe(api, cartao, "2026-10")

    assert detalhe["valor_pago"] == "30.00"
    assert detalhe["status"] == "fechada"
    assert [p["valor"] for p in detalhe["pagamentos"]] == ["30.00"]


def test_lista_e_contas_mostram_o_pagamento(api, cartao, corrente):
    _comprar(api, cartao, "2026-10-01")
    _pago(api, cartao, "2026-10", corrente)

    lista = api.get(_url(cartao)).json()
    [outubro] = [f for f in lista["anteriores"] if f["competencia"] == "2026-10-01"]
    conta = api.get(f"/contas/{cartao['id']}").json()

    assert (outubro["status"], outubro["valor_pago"]) == ("paga", "100.00")
    assert conta["cartao"]["fatura_atual"]["valor_pago"] == "0.00"


def test_cartao_desativado_pode_ser_pago(api, sessao, cartao, corrente):
    _comprar(api, cartao, "2026-10-01")
    sessao.get(Conta, uuid.UUID(cartao["id"])).ativa = False
    sessao.flush()

    assert _pago(api, cartao, "2026-10", corrente)["status"] == "paga"


@pytest.mark.parametrize(
    ("caso", "campo", "mensagem"),
    [
        ("cartão", "conta_id", "Pague com uma conta corrente ou carteira."),
        ("desativada", "conta_id", "Esta conta está desativada."),
        ("inexistente", "conta_id", "Conta não encontrada."),
    ],
)
def test_pagamento_recusado(api, sessao, cartao, corrente, caso, campo, mensagem):
    conta = corrente
    if caso == "cartão":
        conta = cartao
    elif caso == "desativada":
        sessao.get(Conta, uuid.UUID(corrente["id"])).ativa = False
        sessao.flush()
    elif caso == "inexistente":
        conta = {"id": str(uuid.uuid4())}
    antes = sessao.scalar(select(func.count()).select_from(Transacao))

    campos = _campos(_pagar(api, cartao, "2026-10", conta))

    assert campos == {f"body.{campo}": mensagem}
    assert sessao.scalar(select(func.count()).select_from(Transacao)) == antes


def test_pagamento_de_valor_zero_e_recusado(api, cartao, corrente):
    assert list(_campos(_pagar(api, cartao, "2026-10", corrente, valor="0.00"))) == ["body.valor"]


def test_pagamento_cartao_inexistente_404(api, corrente):
    resposta = _pagar(api, {"id": str(uuid.uuid4())}, "2026-10", corrente)

    assert resposta.status_code == 404
    assert resposta.json()["detail"] == "Cartão não encontrado."


def test_pagamento_competencia_invalida_422(api, cartao, corrente):
    assert _pagar(api, cartao, "2026-13", corrente).status_code == 422


def test_pagamento_exige_token(client):
    resposta = client.post(f"/cartoes/{uuid.uuid4()}/faturas/2026-10/pagamentos", json={})

    assert resposta.status_code == 401


def test_pagamento_na_lista_diz_qual_fatura_pagou(api, cartao, corrente):
    _comprar(api, cartao, "2026-10-01")
    _pago(api, cartao, "2026-10", corrente)

    resposta = api.get("/transacoes", params={"conta_id": corrente["id"]})

    assert resposta.status_code == 200
    [pagamento] = [t for t in resposta.json() if t["tipo"] == "pagamento_fatura"]
    assert pagamento["fatura"] == {"cartao_id": cartao["id"], "competencia": "2026-10-01"}
