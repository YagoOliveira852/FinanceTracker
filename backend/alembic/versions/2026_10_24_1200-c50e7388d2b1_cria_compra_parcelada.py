"""cria compra_parcelada e a parcela em transacao

Revision ID: c50e7388d2b1
Revises: 7b71de313332
Create Date: 2026-10-24 12:00:00

Só acrescenta: tabela nova e duas colunas nulas em `transacao`, para o código
da versão anterior continuar funcionando durante o deploy. Os CHECK da coluna
acrescentada são escritos à mão (o autogenerate não os põe no `add_column`).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "c50e7388d2b1"
down_revision: str | Sequence[str] | None = "7b71de313332"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Aplica a migration."""
    op.create_table(
        "compra_parcelada",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("descricao", sa.Text(), nullable=False),
        sa.Column("valor_total", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("qtd_parcelas", sa.SmallInteger(), nullable=False),
        sa.Column("data_compra", sa.Date(), nullable=False),
        sa.Column("data_compra_estimada", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column(
            "criado_em", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column(
            "atualizado_em",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "valor_total > 0", name=op.f("ck_compra_parcelada_valor_total_positivo")
        ),
        sa.CheckConstraint(
            "qtd_parcelas >= 2", name=op.f("ck_compra_parcelada_qtd_parcelas_valida")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_compra_parcelada")),
    )
    op.add_column("transacao", sa.Column("compra_parcelada_id", sa.Uuid(), nullable=True))
    op.add_column("transacao", sa.Column("parcela_numero", sa.SmallInteger(), nullable=True))
    op.create_index(
        op.f("ix_transacao_compra_parcelada_id"),
        "transacao",
        ["compra_parcelada_id"],
        unique=False,
    )
    op.create_foreign_key(
        op.f("fk_transacao_compra_parcelada_id_compra_parcelada"),
        "transacao",
        "compra_parcelada",
        ["compra_parcelada_id"],
        ["id"],
    )
    op.create_check_constraint(
        op.f("ck_transacao_parcela_numero_valido"), "transacao", "parcela_numero >= 1"
    )
    op.create_check_constraint(
        op.f("ck_transacao_parcela_completa"),
        "transacao",
        "(compra_parcelada_id IS NULL) = (parcela_numero IS NULL)",
    )


def downgrade() -> None:
    """Reverte a migration."""
    op.drop_constraint(op.f("ck_transacao_parcela_completa"), "transacao", type_="check")
    op.drop_constraint(op.f("ck_transacao_parcela_numero_valido"), "transacao", type_="check")
    op.drop_constraint(
        op.f("fk_transacao_compra_parcelada_id_compra_parcelada"), "transacao", type_="foreignkey"
    )
    op.drop_index(op.f("ix_transacao_compra_parcelada_id"), table_name="transacao")
    op.drop_column("transacao", "parcela_numero")
    op.drop_column("transacao", "compra_parcelada_id")
    op.drop_table("compra_parcelada")
