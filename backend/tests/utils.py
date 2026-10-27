"""Funções de apoio aos testes (as fixtures ficam no conftest.py)."""

import uuid
from datetime import date
from decimal import Decimal
from pathlib import Path

from alembic.config import Config

ALEMBIC_INI = Path(__file__).resolve().parents[1] / "alembic.ini"

# "Hoje" fixo nos testes de API (a fixture `client` sobrescreve `get_hoje`).
HOJE = date(2026, 10, 20)


def alembic_config(url: str) -> Config:
    """Config do Alembic apontando para o banco de teste, sem ler a DATABASE_URL."""
    config = Config(ALEMBIC_INI)
    config.set_main_option("sqlalchemy.url", url.replace("%", "%%"))
    return config


def criar_conta(sessao, nome: str = "Conta principal", tipo: str = "corrente"):
    """Conta fictícia gravada direto no banco (corrente e cartão com instituição)."""
    from app.modulos.contas.models import Conta, Instituicao

    conta = Conta(
        nome=nome,
        tipo=tipo,
        instituicao=None if tipo == "carteira" else Instituicao(nome=f"Banco de {nome}"),
        saldo_inicial=Decimal("0.00"),
        data_saldo_inicial=date(2026, 10, 1),
    )
    sessao.add(conta)
    sessao.flush()
    return conta


def criar_transacao(sessao, conta, descricao_original: str = "PADARIA PAO QUENTE", **mudancas):
    """Transação gravada direto no banco; por padrão, um rascunho de despesa
    vindo da Pluggy, como as fontes vão criar (importação e sync ainda não
    existem)."""
    from app.modulos.transacoes.models import Transacao

    dados = {
        "conta_id": conta.id,
        "tipo": "despesa",
        "valor": Decimal("18.50"),
        "data": date(2026, 10, 19),
        "descricao_original": descricao_original,
        "descricao": descricao_original,
        "status": "rascunho",
        "fonte": "pluggy",
        "id_externo": str(uuid.uuid4()),
    }
    transacao = Transacao(**(dados | mudancas))
    sessao.add(transacao)
    sessao.flush()
    return transacao
