"""Confirmar a categoria de um rascunho: a regra aprendida nasce, se reforça ou
é corrigida (spec `2026-10-19-revisao-classificacao`, casos 1 a 5)."""

import uuid
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.core.erros import CampoInvalido
from app.modulos.categorias.models import Categoria, RegraClassificacao
from app.modulos.categorias.regras import (
    EfeitoAprendizado,
    NaoEhRascunho,
    confirmar_categoria,
    regra_sugerida,
)
from app.modulos.contas.models import Conta, Instituicao
from app.modulos.transacoes.models import Transacao


@pytest.fixture
def conta(sessao) -> Conta:
    conta = Conta(
        nome="Conta principal",
        tipo="corrente",
        instituicao=Instituicao(nome="Banco Exemplo"),
        saldo_inicial=Decimal("0.00"),
        data_saldo_inicial=date(2026, 10, 1),
    )
    sessao.add(conta)
    sessao.flush()
    return conta


@pytest.fixture
def categoria(sessao):
    def _por_nome(nome: str) -> Categoria:
        return sessao.scalars(select(Categoria).where(Categoria.nome == nome)).one()

    return _por_nome


def _rascunho(sessao, conta, descricao, **mudancas) -> Transacao:
    dados = {
        "conta_id": conta.id,
        "tipo": "despesa",
        "valor": Decimal("32.00"),
        "data": date(2026, 10, 25),
        "descricao_original": descricao,
        "descricao": descricao,
        "status": "rascunho",
        "fonte": "pluggy",
        "id_externo": str(uuid.uuid4()),
    }
    transacao = Transacao(**(dados | mudancas))
    sessao.add(transacao)
    sessao.flush()
    return transacao


def _regra(sessao, padrao, categoria, origem="aprendida", vezes=0, **mudancas):
    regra = RegraClassificacao(
        padrao=padrao,
        categoria_id=categoria.id,
        origem=origem,
        vezes_aplicada=vezes,
        **mudancas,
    )
    sessao.add(regra)
    sessao.flush()
    return regra


def _regras(sessao) -> list[RegraClassificacao]:
    return list(sessao.scalars(select(RegraClassificacao).order_by(RegraClassificacao.padrao)))


def test_confirmar_grava_a_categoria_e_confirma(sessao, conta, categoria):
    transacao = _rascunho(sessao, conta, "PIX ENVIADO 25/10 LANCHONETE EXEMPLO LTDA")

    confirmar_categoria(sessao, transacao.id, categoria("Alimentação").id)

    sessao.refresh(transacao)
    assert transacao.status == "confirmada"
    assert transacao.categoria.nome == "Alimentação"


def test_sem_regra_nasce_uma_aprendida(sessao, conta, categoria):
    """Caso 1: nenhuma regra sugeria."""
    transacao = _rascunho(sessao, conta, "PIX ENVIADO 25/10 LANCHONETE EXEMPLO LTDA")

    aprendizado = confirmar_categoria(sessao, transacao.id, categoria("Lazer").id)

    assert aprendizado.efeito == EfeitoAprendizado.criada
    [regra] = _regras(sessao)
    assert aprendizado.regra is regra
    assert (regra.padrao, regra.categoria.nome, regra.conta_id) == (
        "lanchonete exemplo ltda",
        "Lazer",
        None,
    )
    assert (regra.origem, regra.vezes_aplicada) == ("aprendida", 0)
    proxima = _rascunho(sessao, conta, "PIX ENVIADO 30/10 LANCHONETE EXEMPLO LTDA")
    assert regra_sugerida(sessao, proxima) is regra


def test_sugestao_confirmada_soma_um(sessao, conta, categoria):
    """Caso 2: confirmou como veio."""
    regra = _regra(sessao, "lanchonete exemplo", categoria("Lazer"), vezes=4)
    transacao = _rascunho(sessao, conta, "LANCHONETE EXEMPLO")

    aprendizado = confirmar_categoria(sessao, transacao.id, categoria("Lazer").id)

    assert (aprendizado.efeito, aprendizado.regra) == (EfeitoAprendizado.reforcada, regra)
    assert regra.vezes_aplicada == 5
    assert len(_regras(sessao)) == 1


def test_sugestao_de_regra_manual_confirmada_tambem_soma(sessao, conta, categoria):
    regra = _regra(sessao, "posto", categoria("Transporte"), origem="manual")
    transacao = _rascunho(sessao, conta, "POSTO FICTICIO 0193")

    confirmar_categoria(sessao, transacao.id, categoria("Transporte").id)

    assert regra.vezes_aplicada == 1


def test_correcao_de_aprendida_com_o_mesmo_padrao_troca_e_zera(sessao, conta, categoria):
    """Caso 3: a regra de "lanchonete exemplo" muda de Lazer para Alimentação."""
    regra = _regra(sessao, "lanchonete exemplo", categoria("Lazer"), vezes=1)
    transacao = _rascunho(sessao, conta, "PIX ENVIADO 25/10 LANCHONETE EXEMPLO")

    aprendizado = confirmar_categoria(sessao, transacao.id, categoria("Alimentação").id)

    assert (aprendizado.efeito, aprendizado.regra) == (EfeitoAprendizado.corrigida, regra)
    assert (regra.categoria.nome, regra.vezes_aplicada) == ("Alimentação", 0)
    assert len(_regras(sessao)) == 1


def test_correcao_de_aprendida_mais_curta_cria_outra_mais_longa(sessao, conta, categoria):
    """Caso 3: a regra casou só parte da descrição; ela fica e nasce outra."""
    curta = _regra(sessao, "mercado", categoria("Mercado"), vezes=6)
    transacao = _rascunho(sessao, conta, "MERCADO DO BAIRRO LANCHES")

    aprendizado = confirmar_categoria(sessao, transacao.id, categoria("Alimentação").id)

    assert aprendizado.efeito == EfeitoAprendizado.especializada
    assert (curta.categoria.nome, curta.vezes_aplicada) == ("Mercado", 6)
    nova = aprendizado.regra
    assert (nova.padrao, nova.categoria.nome, nova.origem) == (
        "mercado do bairro lanches",
        "Alimentação",
        "aprendida",
    )
    assert regra_sugerida(sessao, _rascunho(sessao, conta, "MERCADO DO BAIRRO LANCHES")) is nova
    assert regra_sugerida(sessao, _rascunho(sessao, conta, "MERCADO CENTRAL")) is curta


def test_correcao_de_regra_manual_nao_muda_a_regra(sessao, conta, categoria):
    """Caso 4: regra manual é decisão explícita do usuário."""
    manual = _regra(sessao, "posto", categoria("Transporte"), origem="manual", vezes=2)
    transacao = _rascunho(sessao, conta, "POSTO FICTICIO CONVENIENCIA")

    aprendizado = confirmar_categoria(sessao, transacao.id, categoria("Alimentação").id)

    assert (aprendizado.efeito, aprendizado.regra) == (EfeitoAprendizado.manual_mantida, manual)
    assert (manual.categoria.nome, manual.vezes_aplicada) == ("Transporte", 2)
    assert len(_regras(sessao)) == 1
    sessao.refresh(transacao)
    assert transacao.categoria.nome == "Alimentação"


def test_descricao_so_com_termos_genericos_nao_aprende(sessao, conta, categoria):
    """Caso 5."""
    transacao = _rascunho(sessao, conta, "Pagamento recebido", tipo="receita")

    aprendizado = confirmar_categoria(sessao, transacao.id, categoria("Outras receitas").id)

    assert (aprendizado.efeito, aprendizado.regra) == (EfeitoAprendizado.nenhuma, None)
    assert _regras(sessao) == []


def test_renda_e_gasto_com_o_mesmo_padrao_convivem(sessao, conta, categoria):
    recebido = _rascunho(sessao, conta, "PIX RECEBIDO FULANO DE TAL", tipo="receita")
    enviado = _rascunho(sessao, conta, "PIX ENVIADO FULANO DE TAL")

    confirmar_categoria(sessao, recebido.id, categoria("Outras receitas").id)
    aprendizado = confirmar_categoria(sessao, enviado.id, categoria("Lazer").id)

    assert aprendizado.efeito == EfeitoAprendizado.criada
    assert {(r.padrao, r.categoria.nome) for r in _regras(sessao)} == {
        ("fulano de tal", "Outras receitas"),
        ("fulano de tal", "Lazer"),
    }
    proximo = _rascunho(sessao, conta, "PIX RECEBIDO FULANO DE TAL", tipo="receita")
    assert regra_sugerida(sessao, proximo).categoria.nome == "Outras receitas"


def test_regra_de_categoria_desativada_e_reaproveitada(sessao, conta, categoria):
    """A regra antiga (de categoria desativada) não sugere; confirmar outra
    categoria do mesmo tipo a reaproveita em vez de duplicar o padrão."""
    educacao = categoria("Educação")
    antiga = _regra(sessao, "curso exemplo", educacao, vezes=3)
    educacao.ativa = False
    sessao.flush()
    transacao = _rascunho(sessao, conta, "CURSO EXEMPLO")
    assert regra_sugerida(sessao, transacao) is None

    aprendizado = confirmar_categoria(sessao, transacao.id, categoria("Compras").id)

    assert aprendizado.regra is antiga
    assert (antiga.categoria.nome, antiga.vezes_aplicada) == ("Compras", 0)
    assert len(_regras(sessao)) == 1


def test_regra_manual_de_categoria_desativada_nao_e_reaproveitada(sessao, conta, categoria):
    educacao = categoria("Educação")
    manual = _regra(sessao, "curso exemplo", educacao, origem="manual", vezes=3)
    educacao.ativa = False
    sessao.flush()
    transacao = _rascunho(sessao, conta, "CURSO EXEMPLO")

    aprendizado = confirmar_categoria(sessao, transacao.id, categoria("Compras").id)

    assert aprendizado.efeito == EfeitoAprendizado.criada
    assert aprendizado.regra is not manual
    assert (manual.categoria.nome, manual.vezes_aplicada) == ("Educação", 3)
    assert regra_sugerida(sessao, _rascunho(sessao, conta, "CURSO EXEMPLO")) is aprendizado.regra


def test_categoria_incompativel_e_recusada(sessao, conta, categoria):
    transacao = _rascunho(sessao, conta, "LANCHONETE EXEMPLO")

    with pytest.raises(CampoInvalido) as erro:
        confirmar_categoria(sessao, transacao.id, categoria("Salário").id)

    assert erro.value.campo == "categoria_id"
    assert _regras(sessao) == []


def test_so_rascunho_e_confirmado(sessao, conta, categoria):
    transacao = _rascunho(sessao, conta, "LANCHONETE EXEMPLO", status="confirmada")

    with pytest.raises(NaoEhRascunho):
        confirmar_categoria(sessao, transacao.id, categoria("Lazer").id)
