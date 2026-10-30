"""Rendas previstas pela API: cadastro, lista com a próxima data, edição e
desativação (renda nunca é excluída).

Hoje = 2026-10-20 (terça). Feriados da tabela: 02/11 (segunda) e 15/11
(domingo); 20/11 (sexta).
"""

from datetime import date

import pytest

from app.core.deps import get_hoje
from app.main import app
from tests.utils import criar_conta


@pytest.fixture
def corrente(sessao):
    return criar_conta(sessao, "Conta principal")


def _dados(conta_id, **mudancas) -> dict:
    return {
        "descricao": "Salário",
        "valor": "4200.00",
        "dia_previsto": 10,
        "conta_id": str(conta_id),
        **mudancas,
    }


def _criar(api, conta_id, **mudancas) -> dict:
    resposta = api.post("/planejamento/rendas", json=_dados(conta_id, **mudancas))
    assert resposta.status_code == 201, resposta.json()
    return resposta.json()


def test_cria_renda_e_lista(api, corrente):
    criada = _criar(api, corrente.id)

    assert criada["descricao"] == "Salário"
    assert criada["valor"] == "4200.00"
    assert criada["dia_previsto"] == 10
    assert criada["conta_id"] == str(corrente.id)
    assert criada["ativa"] is True
    resposta = api.get("/planejamento/rendas")
    assert resposta.status_code == 200
    assert resposta.json() == [criada]


def _campos(resposta) -> dict:
    assert resposta.status_code == 422, resposta.json()
    return {erro["campo"]: erro["mensagem"] for erro in resposta.json()["campos"]}


@pytest.mark.parametrize(
    ("mudanca", "campo", "mensagem"),
    [
        ({"descricao": "   "}, "descricao", "Dê um nome à renda, por exemplo: Salário."),
        ({"valor": "0.00"}, "valor", "O valor precisa ser maior que zero."),
        ({"valor": "-10.00"}, "valor", "O valor precisa ser maior que zero."),
        ({"dia_previsto": 0}, "dia_previsto", "Use um dia de 1 a 31."),
        ({"dia_previsto": 32}, "dia_previsto", "Use um dia de 1 a 31."),
    ],
)
def test_valida_os_campos(api, corrente, mudanca, campo, mensagem):
    resposta = api.post("/planejamento/rendas", json=_dados(corrente.id, **mudanca))

    assert _campos(resposta) == {f"body.{campo}": mensagem}


@pytest.mark.parametrize("tipo", ["corrente", "carteira"])
def test_aceita_corrente_e_carteira(api, sessao, tipo):
    conta = criar_conta(sessao, "Conta da renda", tipo=tipo)

    _criar(api, conta.id)


def test_conta_precisa_ser_corrente_ou_carteira_ativa(api, sessao, corrente):
    cartao = criar_conta(sessao, "Cartão", tipo="cartao_credito")
    inativa = criar_conta(sessao, "Conta antiga")
    inativa.ativa = False
    sessao.flush()
    mensagem = {"body.conta_id": "Escolha a conta corrente ou a carteira onde a renda cai."}

    for conta_id in (cartao.id, inativa.id, "6f1d1f86-3c0e-4c3a-9a51-0d6d7c0b9e11"):
        resposta = api.post("/planejamento/rendas", json=_dados(conta_id))
        assert _campos(resposta) == mensagem


@pytest.mark.parametrize(
    ("dia", "proxima"),
    [
        # Dia útil: a própria data; o dia 10 de outubro já passou.
        (10, {"data": "2026-11-10", "data_prevista": "2026-11-10", "feriados": []}),
        # Hoje conta como próxima.
        (20, {"data": "2026-10-20", "data_prevista": "2026-10-20", "feriados": []}),
        # Domingo e feriado: segunda.
        (
            15,
            {
                "data": "2026-11-16",
                "data_prevista": "2026-11-15",
                "feriados": [{"data": "2026-11-15", "descricao": "Proclamação da República"}],
            },
        ),
        # Sábado, e a segunda é Finados: terça.
        (
            31,
            {
                "data": "2026-11-03",
                "data_prevista": "2026-10-31",
                "feriados": [{"data": "2026-11-02", "descricao": "Finados"}],
            },
        ),
    ],
)
def test_lista_traz_a_proxima_data_ajustada(api, corrente, dia, proxima):
    _criar(api, corrente.id, dia_previsto=dia)

    [renda] = api.get("/planejamento/rendas").json()

    assert renda["proxima"] == proxima


@pytest.fixture
def hoje():
    """Muda o "hoje" da API dentro do teste."""

    def mudar(dia: date) -> None:
        app.dependency_overrides[get_hoje] = lambda: dia

    return mudar


def test_dia_31_em_mes_de_30_dias_vira_o_ultimo(api, corrente, hoje):
    hoje(date(2026, 11, 5))

    criada = _criar(api, corrente.id, dia_previsto=31)

    assert criada["proxima"] == {
        "data": "2026-11-30",
        "data_prevista": "2026-11-30",
        "feriados": [],
    }


def test_data_do_mes_anterior_empurrada_para_este_mes_vem_antes(api, corrente, hoje):
    # 31/10 é sábado e vira 03/11, antes do 30/11 deste mês.
    hoje(date(2026, 11, 1))

    criada = _criar(api, corrente.id, dia_previsto=31)

    assert criada["proxima"]["data"] == "2026-11-03"


def test_previa_da_proxima_data_para_um_dia_ainda_nao_salvo(api):
    resposta = api.get("/planejamento/rendas/previa", params={"dia_previsto": 15})

    assert resposta.status_code == 200
    assert resposta.json()["data"] == "2026-11-16"
    assert resposta.json()["data_prevista"] == "2026-11-15"


@pytest.mark.parametrize("dia", [0, 32])
def test_previa_recusa_dia_fora_do_mes(api, dia):
    resposta = api.get("/planejamento/rendas/previa", params={"dia_previsto": dia})

    assert resposta.status_code == 422


def _editar(api, renda: dict, **mudancas):
    dados = {
        "descricao": renda["descricao"],
        "valor": renda["valor"],
        "dia_previsto": renda["dia_previsto"],
        "conta_id": renda["conta_id"],
        "ativa": renda["ativa"],
        **mudancas,
    }
    return api.put(f"/planejamento/rendas/{renda['id']}", json=dados)


def test_edita_a_renda(api, sessao, corrente):
    renda = _criar(api, corrente.id)
    carteira = criar_conta(sessao, "Carteira", tipo="carteira")

    resposta = _editar(
        api,
        renda,
        descricao="Salário líquido",
        valor="4350.50",
        dia_previsto=15,
        conta_id=str(carteira.id),
    )

    assert resposta.status_code == 200, resposta.json()
    editada = resposta.json()
    assert editada["id"] == renda["id"]
    assert editada["descricao"] == "Salário líquido"
    assert editada["valor"] == "4350.50"
    assert editada["dia_previsto"] == 15
    assert editada["conta_id"] == str(carteira.id)
    assert editada["proxima"]["data"] == "2026-11-16"
    assert api.get("/planejamento/rendas").json() == [editada]


def test_desativa_e_reativa_sem_excluir(api, corrente):
    renda = _criar(api, corrente.id)

    desativada = _editar(api, renda, ativa=False)
    assert desativada.status_code == 200
    assert desativada.json()["ativa"] is False
    assert [r["ativa"] for r in api.get("/planejamento/rendas").json()] == [False]

    reativada = _editar(api, desativada.json(), ativa=True)
    assert reativada.json()["ativa"] is True


def test_ativas_pela_proxima_data_e_inativas_no_fim(api, corrente):
    aulas = _criar(api, corrente.id, descricao="Aulas", dia_previsto=5)
    _criar(api, corrente.id, descricao="Freela", dia_previsto=15)
    _criar(api, corrente.id, descricao="Salário", dia_previsto=10)
    _editar(api, aulas, ativa=False)

    lista = api.get("/planejamento/rendas").json()

    assert [r["descricao"] for r in lista] == ["Salário", "Freela", "Aulas"]


def test_editar_valida_como_o_cadastro(api, corrente):
    renda = _criar(api, corrente.id)

    resposta = _editar(api, renda, valor="0.00")

    assert _campos(resposta) == {"body.valor": "O valor precisa ser maior que zero."}


def test_conta_desativada_so_impede_a_renda_ativa(api, sessao, corrente):
    renda = _criar(api, corrente.id)
    corrente.ativa = False
    sessao.flush()
    mensagem = {"body.conta_id": "Escolha a conta corrente ou a carteira onde a renda cai."}

    assert _campos(_editar(api, renda)) == mensagem
    desativada = _editar(api, renda, ativa=False)
    assert desativada.status_code == 200, desativada.json()
    assert _campos(_editar(api, desativada.json(), ativa=True)) == mensagem


def test_editar_renda_que_nao_existe_e_404(api, corrente):
    renda = _criar(api, corrente.id)
    renda["id"] = "6f1d1f86-3c0e-4c3a-9a51-0d6d7c0b9e11"

    resposta = _editar(api, renda)

    assert resposta.status_code == 404
    assert resposta.json() == {"detail": "Renda não encontrada."}


def test_rotas_exigem_token(client):
    assert client.get("/planejamento/rendas").status_code == 401
    assert client.get("/planejamento/configuracao").status_code == 401
