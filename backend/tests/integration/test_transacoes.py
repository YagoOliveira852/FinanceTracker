"""Transações pela API: lançamento manual, efeito no saldo e consulta."""

import uuid
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy.exc import IntegrityError

from app.modulos.contas.models import Conta
from app.modulos.transacoes.models import Transacao
from tests.utils import HOJE


@pytest.fixture
def conta(api) -> dict:
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
def carteira(api) -> dict:
    resposta = api.post(
        "/contas",
        json={
            "nome": "Carteira",
            "tipo": "carteira",
            "saldo_inicial": "50.00",
            "data_saldo_inicial": "2026-10-01",
        },
    )
    assert resposta.status_code == 201
    return resposta.json()


def _dados(id_conta, **mudancas) -> dict:
    return {
        "conta_id": id_conta,
        "tipo": "despesa",
        "valor": "187.40",
        "data": HOJE.isoformat(),
        "descricao": "Mercado do bairro",
        **mudancas,
    }


def _lancar(api, id_conta, **mudancas) -> dict:
    resposta = api.post("/transacoes", json=_dados(id_conta, **mudancas))
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


def _saldo(api, conta_id) -> str:
    return api.get(f"/contas/{conta_id}").json()["saldo_atual"]


def _campos(resposta) -> dict:
    assert resposta.status_code == 422
    return {erro["campo"]: erro["mensagem"] for erro in resposta.json()["campos"]}


# --- lançamento --------------------------------------------------------------


def test_lancamento_manual_entra_confirmado_e_reduz_o_saldo(api, conta):
    transacao = _lancar(api, conta["id"], descricao="  Mercado do bairro ")

    assert transacao["conta_id"] == conta["id"]
    assert transacao["tipo"] == "despesa"
    assert transacao["valor"] == "187.40"
    assert transacao["data"] == HOJE.isoformat()
    assert transacao["descricao"] == "Mercado do bairro"
    assert transacao["descricao_original"] == "Mercado do bairro"
    assert transacao["status"] == "confirmada"
    assert transacao["fonte"] == "manual"
    assert _saldo(api, conta["id"]) == "812.60"
    assert api.get(f"/transacoes/{transacao['id']}").json() == transacao


def test_receita_aumenta_o_saldo(api, conta):
    _lancar(api, conta["id"], tipo="receita", valor="850", descricao="Freela de design")

    assert _saldo(api, conta["id"]) == "1850.00"


def test_criar_conta_lancar_e_ver_saldo_e_total(api, conta, carteira):
    """A fatia vertical inteira: duas contas, lançamentos e o total disponível."""
    _lancar(api, conta["id"], tipo="receita", valor="850.00")
    _lancar(api, conta["id"], valor="187.40")
    _lancar(api, carteira["id"], valor="4.50", descricao="Ônibus")

    corpo = api.get("/contas").json()

    saldos = {c["nome"]: c["saldo_atual"] for c in corpo["contas"]}
    assert saldos == {"Conta principal": "1662.60", "Carteira": "45.50"}
    assert corpo["total_disponivel"] == "1708.10"


@pytest.mark.parametrize("valor", ["0", "0.00", "-10.00"])
def test_valor_precisa_ser_maior_que_zero(api, conta, valor):
    campos = _campos(api.post("/transacoes", json=_dados(conta["id"], valor=valor)))

    assert campos == {"body.valor": "Informe um valor maior que zero."}


@pytest.mark.parametrize(
    ("mudanca", "campo", "mensagem"),
    [
        ({"descricao": "  "}, "body.descricao", "Não pode ficar em branco."),
        ({"descricao": "x" * 201}, "body.descricao", "Texto longo demais."),
        ({"tipo": "transferencia_saida"}, "body.tipo", "Opção inválida."),
        ({"valor": 12.5}, "body.valor", None),
        ({"data": "20/10/2026"}, "body.data", None),
        ({"conta_id": "nao-e-uuid"}, "body.conta_id", "Deve ser um UUID."),
        ({"status": "rascunho"}, "body.status", "Campo não permitido."),
    ],
    ids=["descricao-em-branco", "descricao-longa", "tipo", "float", "data", "uuid", "extra"],
)
def test_validacao_da_entrada(api, conta, mudanca, campo, mensagem):
    campos = _campos(api.post("/transacoes", json=_dados(conta["id"], **mudanca)))

    assert campo in campos
    if mensagem:
        assert campos[campo] == mensagem


def test_conta_inexistente_e_recusada_no_campo(api):
    campos = _campos(api.post("/transacoes", json=_dados(str(uuid.uuid4()))))

    assert campos == {"body.conta_id": "Conta não encontrada."}


def test_conta_desativada_e_recusada(api, sessao, conta):
    sessao.get(Conta, uuid.UUID(conta["id"])).ativa = False
    sessao.flush()

    campos = _campos(api.post("/transacoes", json=_dados(conta["id"])))

    assert campos == {"body.conta_id": "Esta conta está desativada."}


# --- consulta ----------------------------------------------------------------


def test_lista_da_mais_recente_para_a_mais_antiga(api, conta):
    antiga = _lancar(api, conta["id"], data="2026-10-05", descricao="Antiga")
    recente = _lancar(api, conta["id"], data="2026-10-19", descricao="Recente")
    meio = _lancar(api, conta["id"], data="2026-10-12", descricao="Meio")

    ids = [t["id"] for t in api.get("/transacoes").json()]

    assert ids == [recente["id"], meio["id"], antiga["id"]]


def test_filtra_por_conta_e_periodo_inclusivo(api, conta, carteira):
    _lancar(api, conta["id"], data="2026-09-30")
    primeiro_dia = _lancar(api, conta["id"], data="2026-10-01")
    ultimo_dia = _lancar(api, conta["id"], data="2026-10-31")
    _lancar(api, carteira["id"], data="2026-10-15")

    resposta = api.get(
        "/transacoes", params={"conta_id": conta["id"], "de": "2026-10-01", "ate": "2026-10-31"}
    )

    assert [t["id"] for t in resposta.json()] == [ultimo_dia["id"], primeiro_dia["id"]]


def test_periodo_invertido_e_422(api):
    resposta = api.get("/transacoes", params={"de": "2026-10-31", "ate": "2026-10-01"})

    assert _campos(resposta) == {"query.ate": "A data final não pode ser antes da inicial."}


def test_transacao_inexistente_e_404(api):
    resposta = api.get(f"/transacoes/{uuid.uuid4()}")

    assert resposta.status_code == 404
    assert resposta.json() == {"detail": "Transação não encontrada."}


def test_id_malformado_e_422(api):
    assert _campos(api.get("/transacoes/123")) == {"path.transacao_id": "Deve ser um UUID."}


# --- banco -------------------------------------------------------------------


@pytest.mark.parametrize(
    "mudanca",
    [{"valor": Decimal("0.00")}, {"tipo": "ajuste"}, {"status": "pendente"}, {"fonte": "pdf"}],
    ids=["valor-zero", "tipo", "status", "fonte"],
)
def test_banco_recusa_o_que_o_check_nao_permite(sessao, conta, mudanca):
    """Mesmo quem grava sem passar pela API (jobs, seed) esbarra nos CHECKs."""
    campos = {
        "conta_id": uuid.UUID(conta["id"]),
        "tipo": "despesa",
        "valor": Decimal("10.00"),
        "data": date(2026, 10, 5),
        "descricao_original": "Exemplo",
        "descricao": "Exemplo",
        "status": "confirmada",
        "fonte": "manual",
        **mudanca,
    }
    sessao.add(Transacao(**campos))

    with pytest.raises(IntegrityError):
        sessao.flush()


def test_mesma_transacao_externa_nao_entra_duas_vezes(sessao, conta):
    for _ in range(2):
        sessao.add(
            Transacao(
                conta_id=uuid.UUID(conta["id"]),
                tipo="despesa",
                valor=Decimal("10.00"),
                data=date(2026, 10, 5),
                descricao_original="Exemplo",
                descricao="Exemplo",
                status="rascunho",
                fonte="ofx",
                id_externo="FITID-FICTICIO-1",
            )
        )

    with pytest.raises(IntegrityError):
        sessao.flush()


# --- autenticação ------------------------------------------------------------


@pytest.mark.parametrize(
    ("metodo", "caminho"),
    [("get", "/transacoes"), ("post", "/transacoes"), ("get", f"/transacoes/{uuid.uuid4()}")],
)
def test_rotas_exigem_token(client, metodo, caminho):
    resposta = client.request(metodo, caminho, json={})

    assert resposta.status_code == 401
    assert resposta.json() == {"detail": "Não autenticado."}
