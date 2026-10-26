"""Normalização da descrição e escolha da regra de classificação (funções puras)."""

import uuid
from dataclasses import dataclass

import pytest

from app.modulos.categorias.classificacao import (
    casa,
    escolher_regra,
    grupos_do_tipo,
    natureza,
    normalizar,
)
from app.modulos.categorias.models import GrupoCategoria, OrigemRegra
from app.modulos.transacoes.models import TipoTransacao

CONTA = uuid.uuid4()
OUTRA_CONTA = uuid.uuid4()


@pytest.mark.parametrize(
    ("descricao", "esperado"),
    [
        ("PIX ENVIADO 12/11 PADARIA SAO JOSE LTDA 0349", "padaria sao jose ltda"),
        ("Transferência enviada pelo Pix - Fulano de Tal", "fulano de tal"),
        ("Transferência recebida pelo Pix - Fulano de Tal", "fulano de tal"),
        ("Compra no débito - Mercado do Bairro", "mercado do bairro"),
        ("POSTO FICTICIO 0193 FORTALEZA BR", "posto ficticio fortaleza br"),
        ("Estorno - Padaria Pão Quente", "padaria pao quente"),
        ("NETFLIX.COM", "netflix com"),
        ("Farmácia São João", "farmacia sao joao"),
        # Datas, números e códigos com dígito somem inteiros.
        ("Loja Exemplo 12/11/2026", "loja exemplo"),
        ("Loja Exemplo 2026-11-12", "loja exemplo"),
        ("Saque 24h", "saque"),
        ("Streaming Exemplo *1234", "streaming exemplo"),
        # Termo genérico só sai como palavra inteira.
        ("Pixel Lanches", "pixel lanches"),
        ("Central de Compras", "central de compras"),
        # Só termos genéricos: nada sobra para aprender.
        ("Pagamento recebido", ""),
        ("Pagamento de fatura", ""),
        ("PIX ENVIADO 25/10", ""),
        ("", ""),
    ],
)
def test_normalizar(descricao, esperado):
    assert normalizar(descricao) == esperado


def test_normalizar_e_idempotente():
    uma_vez = normalizar("PIX ENVIADO 12/11 PADARIA SAO JOSE LTDA 0349")

    assert normalizar(uma_vez) == uma_vez


@pytest.mark.parametrize(
    ("padrao", "descricao", "esperado"),
    [
        ("posto", "posto ficticio", True),
        ("posto ficticio", "posto ficticio fortaleza", True),
        ("ficticio fortaleza", "posto ficticio fortaleza", True),
        ("padaria pao quente", "padaria pao quente", True),
        ("bar", "barbearia exemplo", False),
        ("exemplo", "lojaexemplo", False),
        ("posto ficticio", "posto exemplo ficticio", False),
        ("mercado do bairro", "mercado", False),
    ],
)
def test_casa_por_palavras_inteiras(padrao, descricao, esperado):
    assert casa(padrao, descricao) is esperado


@pytest.mark.parametrize(
    ("tipo", "grupos"),
    [
        (TipoTransacao.despesa, {GrupoCategoria.essencial, GrupoCategoria.variavel}),
        (TipoTransacao.estorno, {GrupoCategoria.essencial, GrupoCategoria.variavel}),
        (TipoTransacao.receita, {GrupoCategoria.renda}),
        (TipoTransacao.aporte, {GrupoCategoria.investimento}),
        (TipoTransacao.resgate, {GrupoCategoria.investimento}),
        (TipoTransacao.transferencia_saida, set()),
        (TipoTransacao.transferencia_entrada, set()),
        (TipoTransacao.pagamento_fatura, set()),
        (TipoTransacao.ajuste_entrada, set()),
        (TipoTransacao.ajuste_saida, set()),
    ],
)
def test_grupos_do_tipo(tipo, grupos):
    assert grupos_do_tipo(tipo) == grupos


def test_todo_grupo_combina_com_algum_tipo():
    combinados = set().union(*(grupos_do_tipo(tipo) for tipo in TipoTransacao))

    assert combinados == set(GrupoCategoria)


def test_essencial_e_variavel_tem_a_mesma_natureza():
    assert natureza(GrupoCategoria.essencial) == natureza(GrupoCategoria.variavel)
    assert len({natureza(g) for g in GrupoCategoria}) == 3


@dataclass
class Regra:
    padrao: str
    origem: str = OrigemRegra.aprendida
    conta_id: uuid.UUID | None = None


@pytest.mark.parametrize(
    ("regras", "vencedora"),
    [
        # Manual vence aprendida, mesmo mais curta.
        ([Regra("padaria pao quente"), Regra("padaria", OrigemRegra.manual)], 1),
        # Restrita à conta vence a geral, mesmo mais curta.
        ([Regra("padaria pao quente"), Regra("padaria", conta_id=CONTA)], 1),
        # Manual geral vence aprendida restrita.
        ([Regra("padaria", conta_id=CONTA), Regra("padaria", OrigemRegra.manual)], 1),
        # Mesma origem e conta: o padrão mais longo vence.
        ([Regra("padaria"), Regra("padaria pao quente")], 1),
    ],
)
def test_escolher_regra_ordem(regras, vencedora):
    descricao = "padaria pao quente"

    assert escolher_regra(descricao, CONTA, regras) is regras[vencedora]
    assert escolher_regra(descricao, CONTA, list(reversed(regras))) is regras[vencedora]


def test_empate_total_vai_pela_ordem_alfabetica():
    regras = [Regra("loja"), Regra("azul")]

    assert escolher_regra("loja azul", CONTA, regras) is regras[1]
    assert escolher_regra("loja azul", CONTA, list(reversed(regras))) is regras[1]


def test_regra_de_outra_conta_nao_casa():
    restrita = Regra("padaria", OrigemRegra.manual, conta_id=OUTRA_CONTA)
    geral = Regra("padaria")

    assert escolher_regra("padaria pao quente", CONTA, [restrita, geral]) is geral
    assert escolher_regra("padaria pao quente", CONTA, [restrita]) is None


def test_sem_regra_que_case():
    assert escolher_regra("padaria pao quente", CONTA, [Regra("mercado")]) is None
    assert escolher_regra("padaria pao quente", CONTA, []) is None
    assert escolher_regra("", CONTA, [Regra("padaria")]) is None
