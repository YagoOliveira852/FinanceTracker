"""`par_recusado` e as marcas de duplicata e origem na `transacao`: o banco
recusa o que as regras não permitem e acompanha a exclusão de rascunhos."""

from datetime import UTC, datetime

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.modulos.revisao.models import ParRecusado
from tests.utils import criar_conta, criar_transacao


@pytest.fixture
def par(sessao):
    saida = criar_transacao(sessao, criar_conta(sessao), "PIX ENVIADO CONTA DIA A DIA")
    entrada = criar_transacao(
        sessao,
        criar_conta(sessao, "Conta do dia a dia"),
        "PIX RECEBIDO CONTA PRINCIPAL",
        tipo="receita",
    )
    return saida, entrada


def test_par_recusado_grava(sessao, par):
    saida, entrada = par
    sessao.add(ParRecusado(saida_id=saida.id, entrada_id=entrada.id))
    sessao.flush()

    assert sessao.scalars(select(ParRecusado)).one().entrada_id == entrada.id


def test_par_recusado_repetido_e_recusado(sessao, par):
    saida, entrada = par
    sessao.add(ParRecusado(saida_id=saida.id, entrada_id=entrada.id))
    sessao.flush()
    sessao.add(ParRecusado(saida_id=saida.id, entrada_id=entrada.id))

    with pytest.raises(IntegrityError):
        sessao.flush()


def test_par_recusado_consigo_mesmo_e_recusado(sessao, par):
    saida, _ = par
    sessao.add(ParRecusado(saida_id=saida.id, entrada_id=saida.id))

    with pytest.raises(IntegrityError):
        sessao.flush()


def test_apagar_transacao_apaga_a_recusa_e_a_marca_de_duplicata(sessao, par):
    saida, entrada = par
    sessao.add(ParRecusado(saida_id=saida.id, entrada_id=entrada.id))
    copia = criar_transacao(
        sessao, criar_conta(sessao, "Conta extra"), possivel_duplicata_de=saida.id
    )
    sessao.flush()

    sessao.delete(saida)
    sessao.flush()
    sessao.expire_all()

    assert sessao.scalars(select(ParRecusado)).all() == []
    assert sessao.get(type(copia), copia.id).possivel_duplicata_de is None


def test_duplicata_de_si_mesma_e_recusada(sessao, par):
    saida, _ = par
    saida.possivel_duplicata_de = saida.id

    with pytest.raises(IntegrityError):
        sessao.flush()


def test_removida_na_origem_guarda_o_momento(sessao, par):
    saida, _ = par
    momento = datetime(2026, 10, 21, 10, 0, tzinfo=UTC)
    saida.removida_na_origem_em = momento
    sessao.flush()
    sessao.expire_all()

    assert sessao.get(type(saida), saida.id).removida_na_origem_em == momento
