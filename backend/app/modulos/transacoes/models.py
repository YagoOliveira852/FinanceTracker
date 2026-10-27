"""Tabela de transações: cada entrada ou saída de dinheiro de uma conta."""

import uuid
from datetime import date, datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Numeric,
    SmallInteger,
    Text,
    UniqueConstraint,
    false,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, ComTimestamps, check_enum
from app.modulos.categorias.models import Categoria


class TipoTransacao(StrEnum):
    despesa = "despesa"
    receita = "receita"
    transferencia_saida = "transferencia_saida"
    transferencia_entrada = "transferencia_entrada"
    pagamento_fatura = "pagamento_fatura"
    aporte = "aporte"
    resgate = "resgate"
    estorno = "estorno"
    # Correção de saldo na conferência com o banco (sobrou ou faltou dinheiro).
    ajuste_entrada = "ajuste_entrada"
    ajuste_saida = "ajuste_saida"


# O valor é sempre positivo; o sentido vem do tipo. Todo tipo está em exatamente
# um dos dois conjuntos (há teste garantindo).
TIPOS_ENTRADA = frozenset(
    {
        TipoTransacao.receita,
        TipoTransacao.transferencia_entrada,
        TipoTransacao.resgate,
        TipoTransacao.estorno,
        TipoTransacao.ajuste_entrada,
    }
)
TIPOS_SAIDA = frozenset(
    {
        TipoTransacao.despesa,
        TipoTransacao.transferencia_saida,
        TipoTransacao.pagamento_fatura,
        TipoTransacao.aporte,
        TipoTransacao.ajuste_saida,
    }
)


class StatusTransacao(StrEnum):
    rascunho = "rascunho"
    confirmada = "confirmada"
    ignorada = "ignorada"


class FonteTransacao(StrEnum):
    manual = "manual"
    ofx = "ofx"
    csv_mercadopago = "csv_mercadopago"
    pluggy = "pluggy"


class CompraParcelada(ComTimestamps, Base):
    """Agrupa as parcelas de uma compra: uma transação por parcela, cada uma na
    sua fatura.

    No lançamento manual, `data_compra` é a data digitada; das fontes, vem da
    Pluggy (`purchaseDate`) ou é estimada a partir do OFX
    (`data_compra_estimada`).
    """

    __tablename__ = "compra_parcelada"
    __table_args__ = (
        CheckConstraint("valor_total > 0", name="valor_total_positivo"),
        # O máximo (24 no lançamento manual) fica na API: as fontes podem trazer mais.
        CheckConstraint("qtd_parcelas >= 2", name="qtd_parcelas_valida"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    descricao: Mapped[str] = mapped_column(Text)
    valor_total: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    qtd_parcelas: Mapped[int] = mapped_column(SmallInteger)
    data_compra: Mapped[date] = mapped_column(Date)
    data_compra_estimada: Mapped[bool] = mapped_column(default=False, server_default=false())

    parcelas: Mapped[list["Transacao"]] = relationship(
        back_populates="compra_parcelada", order_by="Transacao.parcela_numero"
    )


class Transacao(ComTimestamps, Base):
    __tablename__ = "transacao"
    __table_args__ = (
        check_enum("tipo", TipoTransacao),
        check_enum("status", StatusTransacao),
        check_enum("fonte", FonteTransacao),
        CheckConstraint("valor > 0", name="valor_positivo"),
        CheckConstraint("parcela_numero >= 1", name="parcela_numero_valido"),
        # Parcela tem compra e número, ou nenhum dos dois.
        CheckConstraint(
            "(compra_parcelada_id IS NULL) = (parcela_numero IS NULL)", name="parcela_completa"
        ),
        # Só transferência tem par, e ninguém é par de si mesmo. Que os dois
        # lados apontem um para o outro é regra do service.
        CheckConstraint(
            "transferencia_par_id IS NULL"
            " OR tipo IN ('transferencia_saida', 'transferencia_entrada')",
            name="par_so_em_transferencia",
        ),
        CheckConstraint("transferencia_par_id <> id", name="par_nao_e_ela_mesma"),
        CheckConstraint("possivel_duplicata_de <> id", name="duplicata_nao_e_ela_mesma"),
        # Coração da idempotência: a mesma transação da mesma fonte não entra
        # duas vezes. Lançamento manual tem id_externo nulo e não colide.
        UniqueConstraint(
            "conta_id", "fonte", "id_externo", name="uq_transacao_conta_id_fonte_id_externo"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    conta_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("conta.id"), index=True)
    tipo: Mapped[str] = mapped_column(Text)
    valor: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    # Data da operação (compra, Pix), no fuso do negócio.
    data: Mapped[date] = mapped_column(Date, index=True)
    # Como veio do banco, nunca editada; `descricao` é a que o usuário edita.
    descricao_original: Mapped[str] = mapped_column(Text)
    descricao: Mapped[str] = mapped_column(Text)
    # Gravada ao confirmar na revisão ou no lançamento manual; a sugestão das
    # regras é calculada na leitura, não fica aqui.
    categoria_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("categoria.id"), index=True)
    status: Mapped[str] = mapped_column(Text)
    fonte: Mapped[str] = mapped_column(Text)
    # FITID do OFX, id da Pluggy ou hash do CSV; nulo no lançamento manual.
    id_externo: Mapped[str | None] = mapped_column(Text)
    # Obrigatório em transação de conta `cartao_credito` (regra no service: um
    # CHECK não enxerga o tipo da conta).
    fatura_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("fatura.id"), index=True)
    compra_parcelada_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("compra_parcelada.id"), index=True
    )
    # Até `compra_parcelada.qtd_parcelas` (regra no service).
    parcela_numero: Mapped[int | None] = mapped_column(SmallInteger)
    # Liga saída e entrada de uma transferência entre contas próprias; cada
    # lado aponta para o outro (no máximo um par por transação).
    transferencia_par_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("transacao.id"), unique=True
    )

    # Outra fonte trouxe algo igual: a revisão decide qual fica. `SET NULL`
    # porque o sync da Pluggy apaga rascunho que sumiu da origem.
    possivel_duplicata_de: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("transacao.id", ondelete="SET NULL"), index=True
    )
    # Confirmada que sumiu da Pluggy na janela de reconciliação: alerta na revisão.
    removida_na_origem_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    categoria: Mapped[Categoria | None] = relationship(lazy="joined")
    compra_parcelada: Mapped[CompraParcelada | None] = relationship(
        back_populates="parcelas", lazy="joined"
    )
    # As duas FKs se cruzam: `post_update` grava as linhas primeiro e liga os
    # pares num UPDATE depois. Auto-referência só faz o JOIN com `join_depth`;
    # 1 basta (o par do par é a própria transação).
    transferencia_par: Mapped["Transacao | None"] = relationship(
        remote_side=[id],
        foreign_keys=[transferencia_par_id],
        post_update=True,
        lazy="joined",
        join_depth=1,
    )
