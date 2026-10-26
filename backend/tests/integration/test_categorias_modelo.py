"""Categoria e regra de classificação: seed e o que o banco recusa."""

from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.modulos.categorias.models import Categoria, RegraClassificacao
from app.modulos.contas.models import Conta, Instituicao
from app.modulos.transacoes.models import Transacao


def _categoria(sessao, nome: str) -> Categoria:
    return sessao.scalars(select(Categoria).where(Categoria.nome == nome)).one()


def test_seed_tem_as_categorias_genericas_por_grupo(sessao):
    grupos = {c.nome: c.grupo for c in sessao.scalars(select(Categoria))}

    assert grupos == {
        "Mercado": "essencial",
        "Moradia": "essencial",
        "Saúde": "essencial",
        "Transporte": "essencial",
        "Alimentação": "variavel",
        "Assinaturas": "variavel",
        "Compras": "variavel",
        "Educação": "variavel",
        "Lazer": "variavel",
        "Salário": "renda",
        "Outras receitas": "renda",
        "Investimento": "investimento",
    }
    assert all(c.ativa for c in sessao.scalars(select(Categoria)))


def test_nome_repetido_com_outra_caixa_e_recusado(sessao):
    sessao.add(Categoria(nome="MERCADO", grupo="essencial"))

    with pytest.raises(IntegrityError, match="uq_categoria_nome_lower"):
        sessao.flush()


def test_grupo_invalido_e_recusado(sessao):
    sessao.add(Categoria(nome="Pets", grupo="outro"))

    with pytest.raises(IntegrityError, match="ck_categoria_grupo"):
        sessao.flush()


@pytest.mark.parametrize(
    ("campos", "constraint"),
    [
        ({"padrao": ""}, "ck_regra_classificacao_padrao_preenchido"),
        ({"vezes_aplicada": -1}, "ck_regra_classificacao_vezes_aplicada_valida"),
        ({"origem": "outra"}, "ck_regra_classificacao_origem"),
    ],
)
def test_regra_invalida_e_recusada(sessao, campos, constraint):
    dados = {
        "padrao": "padaria pao quente",
        "categoria_id": _categoria(sessao, "Alimentação").id,
        "origem": "manual",
    }
    sessao.add(RegraClassificacao(**(dados | campos)))

    with pytest.raises(IntegrityError, match=constraint):
        sessao.flush()


def test_regra_carrega_categoria_e_comeca_sem_uso(sessao):
    regra = RegraClassificacao(
        padrao="padaria pao quente",
        categoria_id=_categoria(sessao, "Alimentação").id,
        origem="aprendida",
    )
    sessao.add(regra)
    sessao.flush()
    sessao.expire_all()

    relida = sessao.get(RegraClassificacao, regra.id)
    assert relida.categoria.nome == "Alimentação"
    assert relida.conta is None
    assert relida.vezes_aplicada == 0


def test_transacao_guarda_a_categoria(sessao):
    conta = Conta(
        nome="Conta principal",
        tipo="corrente",
        instituicao=Instituicao(nome="Banco Exemplo"),
        saldo_inicial=Decimal("0.00"),
        data_saldo_inicial=date(2026, 10, 1),
    )
    sessao.add(conta)
    sessao.flush()
    transacao = Transacao(
        conta_id=conta.id,
        tipo="despesa",
        valor=Decimal("18.50"),
        data=date(2026, 10, 19),
        descricao_original="Padaria Pão Quente",
        descricao="Padaria Pão Quente",
        status="confirmada",
        fonte="manual",
        categoria_id=_categoria(sessao, "Alimentação").id,
    )
    sessao.add(transacao)
    sessao.flush()
    sessao.expire_all()

    assert sessao.get(Transacao, transacao.id).categoria.nome == "Alimentação"
