"""Tabela de importações: um arquivo importado (ou, na S7, uma execução do
sync da Pluggy)."""

import uuid
from datetime import date
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import CheckConstraint, Date, ForeignKey, Numeric, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, ComTimestamps, check_enum
from app.modulos.cartoes.models import Fatura
from app.modulos.contas.models import Conta


class FonteImportacao(StrEnum):
    ofx = "ofx"
    csv_mercadopago = "csv_mercadopago"
    pluggy = "pluggy"


class StatusImportacao(StrEnum):
    ok = "ok"
    # Só o sync da Pluggy grava erro: importação de arquivo com erro não grava nada.
    erro = "erro"


class Importacao(ComTimestamps, Base):
    """Resumo de uma importação e o que é preciso para desfazê-la.

    As transações e o snapshot de saldo apontam para cá (`importacao_id`). Num
    OFX de fatura, guarda o valor e o fechamento que a fatura tinha antes e os
    que a importação gravou: o desfazer só restaura os anteriores se a fatura
    ainda estiver como a importação a deixou.
    """

    __tablename__ = "importacao"
    __table_args__ = (
        check_enum("fonte", FonteImportacao),
        check_enum("status", StatusImportacao),
        CheckConstraint(
            "qtd_novas >= 0 AND qtd_possiveis_duplicatas >= 0"
            " AND qtd_ja_importadas >= 0 AND qtd_parcelas >= 0",
            name="quantidades_nao_negativas",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    fonte: Mapped[str] = mapped_column(Text)
    conta_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("conta.id"), index=True)
    nome_arquivo: Mapped[str | None] = mapped_column(Text)
    # SHA-256 dos bytes: o mesmo arquivo não entra duas vezes, em nenhuma conta.
    hash_arquivo: Mapped[str | None] = mapped_column(Text, unique=True)
    periodo_inicio: Mapped[date | None] = mapped_column(Date)
    periodo_fim: Mapped[date | None] = mapped_column(Date)
    # Novas sem as possíveis duplicatas; as duas viram rascunho.
    qtd_novas: Mapped[int] = mapped_column(default=0)
    qtd_possiveis_duplicatas: Mapped[int] = mapped_column(default=0)
    # Mesmo (conta, fonte, id_externo) de antes: ficaram de fora.
    qtd_ja_importadas: Mapped[int] = mapped_column(default=0)
    qtd_parcelas: Mapped[int] = mapped_column(default=0)
    fatura_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("fatura.id"), index=True)
    fatura_valor_antes: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    fatura_fechamento_antes: Mapped[date | None] = mapped_column(Date)
    fatura_valor_gravado: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    fatura_fechamento_gravado: Mapped[date | None] = mapped_column(Date)
    status: Mapped[str] = mapped_column(Text)
    erro: Mapped[str | None] = mapped_column(Text)

    conta: Mapped[Conta | None] = relationship(lazy="joined")
    fatura: Mapped[Fatura | None] = relationship(lazy="joined")
