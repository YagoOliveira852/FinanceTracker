"""Pluggy falsa para os testes: nenhum teste chama a API real. Dados fictícios."""

from datetime import UTC, date, datetime
from decimal import Decimal

from app.modulos.pluggy.client import ItemNaoEncontrado
from app.modulos.pluggy.tipos import ContaPluggy, FaturaPluggy, ItemPluggy, TransacaoPluggy

AGORA = datetime(2026, 10, 20, 10, 0, tzinfo=UTC)
CONSENTIMENTO = datetime(2027, 8, 15, 12, tzinfo=UTC)


class PluggyFalsa:
    def __init__(self):
        # Itens que existem; o padrão responde a qualquer id.
        self.itens: dict[str, ItemPluggy] | None = None
        self.contas: dict[str, list[ContaPluggy]] = {}
        self.transacoes: dict[str, list[TransacaoPluggy]] = {}
        self.faturas: dict[str, list[FaturaPluggy]] = {}
        self.erros: dict[str, Exception] = {}
        self.pedidos: list[tuple[str, date]] = []

    def obter_item(self, item_id: str) -> ItemPluggy:
        if item_id in self.erros:
            raise self.erros[item_id]
        if self.itens is not None:
            if item_id not in self.itens:
                raise ItemNaoEncontrado()
            return self.itens[item_id]
        return item(item_id)

    def listar_contas(self, item_id: str) -> list[ContaPluggy]:
        return list(self.contas.get(item_id, []))

    def listar_transacoes(self, account_id: str, *, desde: date) -> list[TransacaoPluggy]:
        self.pedidos.append((account_id, desde))
        return list(self.transacoes.get(account_id, []))

    def listar_faturas(self, account_id: str) -> list[FaturaPluggy]:
        return list(self.faturas.get(account_id, []))


def item(item_id: str = "item-1", **mudancas) -> ItemPluggy:
    dados = {
        "id": item_id,
        "instituicao": "Banco Exemplo",
        "status": "UPDATED",
        "consentimento_expira_em": CONSENTIMENTO,
        "atualizado_em": AGORA,
    }
    return ItemPluggy(**(dados | mudancas))


def conta_pluggy(id_: str = "conta-1", **mudancas) -> ContaPluggy:
    dados = {
        "id": id_,
        "tipo": "BANK",
        "subtipo": "CHECKING_ACCOUNT",
        "nome": "Conta corrente",
        "numero": "0001/12345-6",
        "saldo": Decimal("3180.10"),
    }
    return ContaPluggy(**(dados | mudancas))


def cartao_pluggy(id_: str = "cartao-1", **mudancas) -> ContaPluggy:
    dados = {
        "id": id_,
        "tipo": "CREDIT",
        "subtipo": "CREDIT_CARD",
        "nome": "Cartão Exemplo",
        "numero": "5678",
        "saldo": Decimal("1032.15"),
        "dia_fechamento": 3,
        "dia_vencimento": 10,
        "limite": Decimal("5000"),
    }
    return ContaPluggy(**(dados | mudancas))


def tx(id_: str, **mudancas) -> TransacaoPluggy:
    dados = {
        "id": id_,
        "descricao": "Padaria Exemplo",
        "descricao_bruta": "PADARIA EXEMPLO",
        "valor": Decimal("-18.50"),
        "momento": datetime(2026, 10, 19, 15, tzinfo=UTC),
        "sentido": "DEBIT",
        "status": "POSTED",
        "tipo_operacao": "PIX",
        "categoria": None,
    }
    return TransacaoPluggy(**(dados | mudancas))
