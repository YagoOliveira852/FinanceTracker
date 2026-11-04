"""Cliente da Pluggy contra respostas simuladas (respx): nenhum teste chama a
API real. Formatos conferidos no MCP pluggy-docs em 2026-11-04. Dados
fictícios."""

from datetime import UTC, date, datetime
from decimal import Decimal

import httpx
import pytest
import respx

from app.modulos.pluggy.client import ClientePluggy, ErroPluggy, ItemNaoEncontrado

URL = "https://api.pluggy.example"


class Relogio:
    def __init__(self):
        self.agora = 0.0

    def __call__(self) -> float:
        return self.agora


@pytest.fixture
def relogio():
    return Relogio()


@pytest.fixture
def pluggy(relogio):
    with respx.mock(base_url=URL, assert_all_called=False) as mock:
        mock.post("/auth").respond(200, json={"apiKey": "chave-1"})
        yield mock


@pytest.fixture
def cliente(relogio):
    with ClientePluggy("id-ficticio", "segredo-ficticio", URL, relogio=relogio) as cliente:
        yield cliente


def _transacao(id_: str, **mudancas) -> dict:
    return {
        "id": id_,
        "description": "Padaria Exemplo",
        "descriptionRaw": "PADARIA EXEMPLO LTDA",
        "currencyCode": "BRL",
        "amount": -18.5,
        "date": "2026-10-19T15:00:00.000Z",
        "type": "DEBIT",
        "status": "POSTED",
        "category": "Bakeries",
        "operationType": "PIX",
        "accountId": "conta-1",
        "createdAt": "2026-10-19T16:00:00.000Z",
        "updatedAt": "2026-10-19T16:00:00.000Z",
        **mudancas,
    }


def test_autentica_com_as_credenciais_e_manda_a_chave(pluggy, cliente):
    rota = pluggy.get("/items/item-1").respond(
        200,
        json={
            "id": "item-1",
            "status": "UPDATED",
            "connector": {"id": 1, "name": "Banco Exemplo"},
            "consentExpiresAt": "2027-08-15T12:00:00.000Z",
            "lastUpdatedAt": "2026-11-04T10:02:00.000Z",
        },
    )

    item = cliente.obter_item("item-1")

    auth = pluggy.calls[0].request
    assert auth.url.path == "/auth"
    assert b'"clientId":"id-ficticio"' in auth.content.replace(b" ", b"")
    assert rota.calls.last.request.headers["X-API-KEY"] == "chave-1"
    assert item.instituicao == "Banco Exemplo"
    assert item.status == "UPDATED"
    assert item.consentimento_expira_em == datetime(2027, 8, 15, 12, tzinfo=UTC)


def test_reaproveita_a_chave_e_renova_antes_de_vencer(pluggy, cliente, relogio):
    auth = pluggy.routes[0]
    pluggy.get("/accounts").respond(200, json={"page": 1, "totalPages": 1, "results": []})

    cliente.listar_contas("item-1")
    cliente.listar_contas("item-1")
    relogio.agora = 2 * 60 * 60  # 2 h: a chave já venceu
    cliente.listar_contas("item-1")

    assert auth.call_count == 2


def test_401_renova_a_chave_uma_vez_e_repete(pluggy, cliente):
    auth = pluggy.routes[0]
    contas = pluggy.get("/accounts")
    contas.side_effect = [
        httpx.Response(401, json={"code": 401, "message": "expired"}),
        httpx.Response(200, json={"page": 1, "totalPages": 1, "results": []}),
    ]

    assert cliente.listar_contas("item-1") == []
    assert auth.call_count == 2


def test_credenciais_recusadas(cliente):
    with respx.mock(base_url=URL) as mock:
        mock.post("/auth").respond(401, json={"code": 401, "message": "Client keys are invalid"})
        with pytest.raises(ErroPluggy, match="credenciais da Pluggy"):
            cliente.listar_contas("item-1")


def test_item_inexistente(pluggy, cliente):
    pluggy.get("/items/nao-existe").respond(404, json={"code": 404, "message": "Item not found"})

    with pytest.raises(ItemNaoEncontrado):
        cliente.obter_item("nao-existe")


@pytest.mark.parametrize(
    ("resposta", "mensagem"),
    [
        (httpx.Response(500, json={"code": 500}), "A Pluggy respondeu com erro"),
        (httpx.Response(429, json={"code": 429}), "limite de requisições"),
        (httpx.ConnectTimeout("tempo esgotado"), "Não deu para falar com a Pluggy"),
    ],
)
def test_erros_viram_mensagem_em_portugues(pluggy, cliente, resposta, mensagem):
    pluggy.get("/accounts").mock(side_effect=[resposta])

    with pytest.raises(ErroPluggy, match=mensagem):
        cliente.listar_contas("item-1")


def test_contas_com_tipo_numero_e_saldo(pluggy, cliente):
    pluggy.get("/accounts", params={"itemId": "item-1"}).respond(
        200,
        json={
            "page": 1,
            "totalPages": 1,
            "results": [
                {
                    "id": "conta-1",
                    "type": "BANK",
                    "subtype": "CHECKING_ACCOUNT",
                    "name": "Conta corrente",
                    "number": "0001/12345-6",
                    "balance": 3180.1,
                },
                {
                    "id": "cartao-1",
                    "type": "CREDIT",
                    "subtype": "CREDIT_CARD",
                    "name": "Cartão Exemplo",
                    "number": "5678",
                    "balance": 1032.15,
                },
            ],
        },
    )

    conta, cartao = cliente.listar_contas("item-1")

    assert (conta.cartao, conta.numero_final, conta.saldo) == (False, "3456", Decimal("3180.1"))
    assert (cartao.cartao, cartao.numero_final) == (True, "5678")


def test_transacoes_percorrem_o_cursor(pluggy, cliente):
    rota = pluggy.get("/v2/transactions")
    rota.side_effect = [
        httpx.Response(
            200,
            json={
                "results": [_transacao("tx-1")],
                "next": "?accountId=conta-1&after=Y3Vyc29yLTE%3D",
            },
        ),
        httpx.Response(200, json={"results": [_transacao("tx-2", amount=1500)], "next": None}),
    ]

    primeira, segunda = cliente.listar_transacoes("conta-1", desde=date(2026, 9, 25))

    pedidos = [chamada.request.url for chamada in rota.calls]
    assert pedidos[0].params["accountId"] == "conta-1"
    assert pedidos[0].params["dateFrom"] == "2026-09-25"
    assert pedidos[1].params["after"] == "Y3Vyc29yLTE="
    assert primeira.valor == Decimal("-18.5")
    assert primeira.momento == datetime(2026, 10, 19, 15, tzinfo=UTC)
    assert primeira.descricao_bruta == "PADARIA EXEMPLO LTDA"
    assert primeira.tipo_operacao == "PIX"
    assert segunda.valor == Decimal("1500")


def test_transacao_do_cartao_traz_parcela_compra_e_fatura(pluggy, cliente):
    pluggy.get("/v2/transactions").respond(
        200,
        json={
            "results": [
                _transacao(
                    "tx-3",
                    amount=120.0,
                    status="PENDING",
                    creditCardMetadata={
                        "installmentNumber": 2,
                        "totalInstallments": 6,
                        "purchaseDate": "2026-09-14T13:20:00.000Z",
                        "billId": "fatura-out",
                    },
                )
            ],
            "next": None,
        },
    )

    (transacao,) = cliente.listar_transacoes("cartao-1", desde=date(2026, 9, 25))

    assert transacao.status == "PENDING"
    assert (transacao.parcela_numero, transacao.total_parcelas) == (2, 6)
    assert transacao.data_compra == datetime(2026, 9, 14, 13, 20, tzinfo=UTC)
    assert transacao.bill_id == "fatura-out"


def test_faturas_percorrem_as_paginas(pluggy, cliente):
    rota = pluggy.get("/bills")
    rota.side_effect = [
        httpx.Response(
            200,
            json={
                "page": 1,
                "totalPages": 2,
                "results": [
                    {
                        "id": "fatura-out",
                        "dueDate": "2026-10-13T00:00:00.000Z",
                        "billClosingDate": "2026-10-05T00:00:00.000Z",
                        "totalAmount": 987.65,
                    }
                ],
            },
        ),
        httpx.Response(
            200,
            json={
                "page": 2,
                "totalPages": 2,
                "results": [
                    {
                        "id": "fatura-set",
                        "dueDate": "2026-09-10",
                        "billClosingDate": None,
                        "totalAmount": 450,
                    }
                ],
            },
        ),
    ]

    outubro, setembro = cliente.listar_faturas("cartao-1")

    assert rota.calls[1].request.url.params["page"] == "2"
    # Data de vencimento é dia, não instante: não muda de fuso.
    assert (outubro.vencimento, outubro.fechamento) == (date(2026, 10, 13), date(2026, 10, 5))
    assert outubro.total == Decimal("987.65")
    assert (setembro.vencimento, setembro.fechamento, setembro.total) == (
        date(2026, 9, 10),
        None,
        Decimal("450"),
    )


def test_cliente_so_le():
    """Somente leitura na Pluggy: além do /auth, só GET."""
    metodos = {
        nome
        for nome in vars(ClientePluggy)
        if not nome.startswith("_") and callable(getattr(ClientePluggy, nome))
    }

    assert metodos == {
        "obter_item",
        "listar_contas",
        "listar_transacoes",
        "listar_faturas",
        "fechar",
    }
