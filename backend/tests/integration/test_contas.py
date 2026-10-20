"""Contas pela API: cadastro, validações, saldo atual e total disponível."""

import uuid
from datetime import date, timedelta
from decimal import Decimal

import pytest

from app.modulos.contas.models import Conta, Instituicao
from app.modulos.transacoes.models import Transacao
from tests.utils import HOJE

ONTEM = HOJE - timedelta(days=1)


def _corrente(**mudancas) -> dict:
    return {
        "nome": "Conta principal",
        "tipo": "corrente",
        "instituicao": "Banco Exemplo",
        "saldo_inicial": "2350.00",
        "data_saldo_inicial": ONTEM.isoformat(),
        **mudancas,
    }


def _carteira(**mudancas) -> dict:
    return {
        "nome": "Carteira",
        "tipo": "carteira",
        "saldo_inicial": "950.50",
        "data_saldo_inicial": ONTEM.isoformat(),
        **mudancas,
    }


def _criar(api, dados) -> dict:
    resposta = api.post("/contas", json=dados)
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


def _transacao(sessao, conta_id, tipo, valor, data, status="confirmada") -> None:
    """Grava direto no banco: os testes de saldo cobrem tipos e status que a API
    ainda não lança (transferência, rascunho...)."""
    sessao.add(
        Transacao(
            conta_id=uuid.UUID(conta_id),
            tipo=tipo,
            valor=Decimal(valor),
            data=data,
            descricao_original="Exemplo",
            descricao="Exemplo",
            status=status,
            fonte="manual",
        )
    )
    sessao.flush()


def _campos(resposta) -> dict:
    assert resposta.status_code == 422
    assert resposta.json()["detail"] == "Dados inválidos."
    return {erro["campo"]: erro["mensagem"] for erro in resposta.json()["campos"]}


# --- cadastro ----------------------------------------------------------------


def test_cria_conta_corrente_com_saldo_atual_igual_ao_inicial(api):
    conta = _criar(api, _corrente())

    assert conta["nome"] == "Conta principal"
    assert conta["tipo"] == "corrente"
    assert conta["instituicao"]["nome"] == "Banco Exemplo"
    assert conta["saldo_inicial"] == "2350.00"
    assert conta["saldo_atual"] == "2350.00"
    assert conta["data_saldo_inicial"] == ONTEM.isoformat()
    assert conta["ativa"] is True
    assert api.get(f"/contas/{conta['id']}").json() == conta


def test_cria_carteira_sem_instituicao(api):
    conta = _criar(api, _carteira())

    assert conta["tipo"] == "carteira"
    assert conta["instituicao"] is None


def test_aceita_saldo_inicial_negativo_e_data_de_hoje(api):
    conta = _criar(api, _corrente(saldo_inicial="-120.4", data_saldo_inicial=HOJE.isoformat()))

    assert conta["saldo_atual"] == "-120.40"


def test_reaproveita_instituicao_com_mesmo_nome_sem_diferenciar_maiusculas(api, sessao):
    primeira = _criar(api, _corrente())
    segunda = _criar(api, _corrente(nome="Reserva", instituicao="  banco EXEMPLO "))

    assert segunda["instituicao"] == primeira["instituicao"]
    assert sessao.query(Instituicao).count() == 1


def test_conta_corrente_sem_instituicao_e_recusada(api):
    resposta = api.post("/contas", json=_corrente(instituicao=None))

    assert _campos(resposta) == {"body.instituicao": "Informe a instituição da conta."}


def test_carteira_com_instituicao_e_recusada(api):
    resposta = api.post("/contas", json=_carteira(instituicao="Banco Exemplo"))

    assert _campos(resposta) == {"body.instituicao": "Carteira não tem instituição."}


def test_data_do_saldo_no_futuro_e_recusada(api):
    amanha = HOJE + timedelta(days=1)

    resposta = api.post("/contas", json=_corrente(data_saldo_inicial=amanha.isoformat()))

    assert _campos(resposta) == {
        "body.data_saldo_inicial": "A data do saldo não pode ser depois de hoje."
    }


@pytest.mark.parametrize(
    ("mudanca", "campo", "mensagem"),
    [
        ({"nome": "   "}, "body.nome", "Não pode ficar em branco."),
        ({"nome": "x" * 101}, "body.nome", "Texto longo demais."),
        ({"instituicao": ""}, "body.instituicao", "Não pode ficar em branco."),
        ({"tipo": "cartao_credito"}, "body.tipo", "Opção inválida."),
        ({"saldo_inicial": "1234.567"}, "body.saldo_inicial", None),
        ({"data_saldo_inicial": "25/10/2026"}, "body.data_saldo_inicial", None),
        ({"apelido": "x"}, "body.apelido", "Campo não permitido."),
    ],
    ids=["nome-em-branco", "nome-longo", "instituicao-vazia", "cartao", "3-casas", "data", "extra"],
)
def test_validacao_da_entrada(api, mudanca, campo, mensagem):
    campos = _campos(api.post("/contas", json=_corrente(**mudanca)))

    assert campo in campos
    if mensagem:
        assert campos[campo] == mensagem


def test_saldo_como_numero_json_e_recusado(api):
    campos = _campos(api.post("/contas", json=_corrente(saldo_inicial=2350.0)))

    assert campos["body.saldo_inicial"].startswith("Valor monetário deve ser uma string")


# --- consulta ----------------------------------------------------------------


def test_conta_inexistente_e_404(api):
    resposta = api.get(f"/contas/{uuid.uuid4()}")

    assert resposta.status_code == 404
    assert resposta.json() == {"detail": "Conta não encontrada."}


def test_id_malformado_e_422(api):
    assert _campos(api.get("/contas/nao-e-uuid")) == {"path.conta_id": "Deve ser um UUID."}


def test_lista_vazia(api):
    assert api.get("/contas").json() == {"total_disponivel": "0.00", "contas": []}


def test_lista_em_ordem_de_nome_com_total_disponivel(api):
    _criar(api, _corrente(nome="Conta principal", saldo_inicial="2350.00"))
    _criar(api, _corrente(nome="Conta do dia a dia", saldo_inicial="-120.40"))
    _criar(api, _carteira(nome="Carteira", saldo_inicial="950.50"))

    corpo = api.get("/contas").json()

    assert [c["nome"] for c in corpo["contas"]] == [
        "Carteira",
        "Conta do dia a dia",
        "Conta principal",
    ]
    assert corpo["total_disponivel"] == "3180.10"


def test_total_disponivel_ignora_conta_desativada_e_cartao(api, sessao):
    _criar(api, _carteira(saldo_inicial="100.00"))
    desativada = _criar(api, _corrente(saldo_inicial="500.00"))
    sessao.get(Conta, uuid.UUID(desativada["id"])).ativa = False
    sessao.add(
        Conta(
            nome="Cartão Exemplo",
            tipo="cartao_credito",
            instituicao=sessao.query(Instituicao).one(),
            saldo_inicial=Decimal("-300.00"),
            data_saldo_inicial=ONTEM,
        )
    )
    sessao.flush()

    corpo = api.get("/contas").json()

    assert len(corpo["contas"]) == 3
    assert corpo["total_disponivel"] == "100.00"


# --- saldo atual -------------------------------------------------------------


def test_saldo_soma_entradas_e_subtrai_saidas_confirmadas_a_partir_da_data_inicial(api, sessao):
    conta = _criar(api, _corrente(saldo_inicial="1000.00", data_saldo_inicial="2026-10-01"))
    depois = date(2026, 10, 5)
    _transacao(sessao, conta["id"], "receita", "850.00", depois)
    _transacao(sessao, conta["id"], "despesa", "187.40", depois)
    _transacao(sessao, conta["id"], "transferencia_saida", "200.00", depois)
    _transacao(sessao, conta["id"], "pagamento_fatura", "100.00", depois)
    _transacao(sessao, conta["id"], "estorno", "10.00", depois)
    _transacao(sessao, conta["id"], "ajuste_entrada", "30.00", depois)
    _transacao(sessao, conta["id"], "ajuste_saida", "5.00", depois)

    assert api.get(f"/contas/{conta['id']}").json()["saldo_atual"] == "1397.60"


def test_transacao_no_dia_do_saldo_inicial_entra_no_saldo(api, sessao):
    """O saldo inicial é o do começo do dia: quem cria a conta e já lança uma
    despesa do mesmo dia vê o saldo mudar."""
    conta = _criar(api, _corrente(saldo_inicial="1000.00", data_saldo_inicial=HOJE.isoformat()))
    _transacao(sessao, conta["id"], "despesa", "50.00", HOJE)

    assert api.get(f"/contas/{conta['id']}").json()["saldo_atual"] == "950.00"


@pytest.mark.parametrize(
    ("data", "status"),
    [
        (date(2026, 9, 30), "confirmada"),  # antes do saldo inicial
        (date(2026, 10, 5), "rascunho"),  # ainda não revisada
        (date(2026, 10, 5), "ignorada"),
    ],
    ids=["antes", "rascunho", "ignorada"],
)
def test_saldo_nao_conta_transacao(api, sessao, data, status):
    conta = _criar(api, _corrente(saldo_inicial="1000.00", data_saldo_inicial="2026-10-01"))
    _transacao(sessao, conta["id"], "despesa", "50.00", data, status)

    assert api.get(f"/contas/{conta['id']}").json()["saldo_atual"] == "1000.00"


def test_saldo_de_uma_conta_nao_mistura_transacoes_de_outra(api, sessao):
    principal = _criar(api, _corrente(saldo_inicial="1000.00"))
    carteira = _criar(api, _carteira(saldo_inicial="100.00"))
    _transacao(sessao, principal["id"], "despesa", "300.00", HOJE)
    _transacao(sessao, carteira["id"], "receita", "20.00", HOJE)

    saldos = {c["nome"]: c["saldo_atual"] for c in api.get("/contas").json()["contas"]}

    assert saldos == {"Conta principal": "700.00", "Carteira": "120.00"}


# --- autenticação ------------------------------------------------------------


@pytest.mark.parametrize(
    ("metodo", "caminho"),
    [("get", "/contas"), ("post", "/contas"), ("get", f"/contas/{uuid.uuid4()}")],
)
def test_rotas_exigem_token(client, metodo, caminho):
    resposta = client.request(metodo, caminho, json=_corrente())

    assert resposta.status_code == 401
    assert resposta.json() == {"detail": "Não autenticado."}
