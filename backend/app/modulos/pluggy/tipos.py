"""O que o cliente da Pluggy devolve: dataclasses próprias, nunca o JSON cru.

Valores monetários vêm como `Decimal` lido da string do JSON (nunca `float`)
e ainda com o sinal da Pluggy; datas com horário, em UTC.
"""

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass(frozen=True)
class ItemPluggy:
    id: str
    # Nome do banco, do conector.
    instituicao: str
    status: str
    consentimento_expira_em: datetime | None
    atualizado_em: datetime | None


@dataclass(frozen=True)
class ContaPluggy:
    id: str
    # `BANK` ou `CREDIT`.
    tipo: str
    # `CHECKING_ACCOUNT`, `SAVINGS_ACCOUNT` ou `CREDIT_CARD`.
    subtipo: str
    nome: str
    numero: str | None
    saldo: Decimal | None
    # Cartão (`creditData`): dias de fechamento e vencimento da fatura atual e limite.
    dia_fechamento: int | None = None
    dia_vencimento: int | None = None
    limite: Decimal | None = None

    @property
    def cartao(self) -> bool:
        return self.tipo == "CREDIT"

    @property
    def numero_final(self) -> str | None:
        """Os 4 últimos dígitos do número, para sugerir o vínculo."""
        digitos = "".join(c for c in self.numero or "" if c.isdigit())
        return digitos[-4:] or None


@dataclass(frozen=True)
class TransacaoPluggy:
    id: str
    descricao: str
    # Como a instituição mandou, antes da limpeza da Pluggy.
    descricao_bruta: str | None
    # Com o sinal da Pluggy; o sentido vem de `sentido`.
    valor: Decimal
    # `date` da Pluggy, em UTC.
    momento: datetime
    # `DEBIT` ou `CREDIT`.
    sentido: str
    # `POSTED` ou `PENDING`.
    status: str
    tipo_operacao: str | None
    categoria: str | None
    # Cartão: parcela, data real da compra e fatura.
    parcela_numero: int | None = None
    total_parcelas: int | None = None
    data_compra: datetime | None = None
    bill_id: str | None = None


@dataclass(frozen=True)
class FaturaPluggy:
    id: str
    vencimento: date
    fechamento: date | None
    total: Decimal
