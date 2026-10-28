"""cria importacao, snapshot_saldo e transacao.importacao_id

Revision ID: 5b0e3c9a1f27
Revises: 2716d2f6a543
Create Date: 2026-10-28 10:00:00

Só acrescenta (spec `2026-10-28-importacao-design`): a tabela `importacao`
(resumo e o que o desfazer precisa), `snapshot_saldo` (saldo do extrato, ligado
à importação) e a coluna nula `transacao.importacao_id`. Os CHECKs de enum são
escritos à mão, como nas outras migrations.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "5b0e3c9a1f27"
down_revision: str | Sequence[str] | None = "2716d2f6a543"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _timestamps() -> list[sa.Column]:
    return [
        sa.Column(
            "criado_em", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column(
            "atualizado_em",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    ]


def upgrade() -> None:
    """Aplica a migration."""
    op.create_table(
        "importacao",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("fonte", sa.Text(), nullable=False),
        sa.Column("conta_id", sa.Uuid(), nullable=True),
        sa.Column("nome_arquivo", sa.Text(), nullable=True),
        sa.Column("hash_arquivo", sa.Text(), nullable=True),
        sa.Column("periodo_inicio", sa.Date(), nullable=True),
        sa.Column("periodo_fim", sa.Date(), nullable=True),
        sa.Column("qtd_novas", sa.Integer(), nullable=False),
        sa.Column("qtd_possiveis_duplicatas", sa.Integer(), nullable=False),
        sa.Column("qtd_ja_importadas", sa.Integer(), nullable=False),
        sa.Column("qtd_parcelas", sa.Integer(), nullable=False),
        sa.Column("fatura_id", sa.Uuid(), nullable=True),
        sa.Column("fatura_valor_antes", sa.Numeric(14, 2), nullable=True),
        sa.Column("fatura_fechamento_antes", sa.Date(), nullable=True),
        sa.Column("fatura_valor_gravado", sa.Numeric(14, 2), nullable=True),
        sa.Column("fatura_fechamento_gravado", sa.Date(), nullable=True),
        sa.Column("status", sa.Text(), nullable=False),
        sa.Column("erro", sa.Text(), nullable=True),
        *_timestamps(),
        sa.CheckConstraint(
            "fonte IN ('ofx', 'csv_mercadopago', 'pluggy')", name=op.f("ck_importacao_fonte")
        ),
        sa.CheckConstraint("status IN ('ok', 'erro')", name=op.f("ck_importacao_status")),
        sa.CheckConstraint(
            "qtd_novas >= 0 AND qtd_possiveis_duplicatas >= 0"
            " AND qtd_ja_importadas >= 0 AND qtd_parcelas >= 0",
            name=op.f("ck_importacao_quantidades_nao_negativas"),
        ),
        sa.ForeignKeyConstraint(
            ["conta_id"], ["conta.id"], name=op.f("fk_importacao_conta_id_conta")
        ),
        sa.ForeignKeyConstraint(
            ["fatura_id"], ["fatura.id"], name=op.f("fk_importacao_fatura_id_fatura")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_importacao")),
        sa.UniqueConstraint("hash_arquivo", name=op.f("uq_importacao_hash_arquivo")),
    )
    op.create_index(op.f("ix_importacao_conta_id"), "importacao", ["conta_id"], unique=False)
    op.create_index(op.f("ix_importacao_fatura_id"), "importacao", ["fatura_id"], unique=False)

    op.create_table(
        "snapshot_saldo",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("conta_id", sa.Uuid(), nullable=False),
        sa.Column("data", sa.Date(), nullable=False),
        sa.Column("saldo", sa.Numeric(14, 2), nullable=False),
        sa.Column("fonte", sa.Text(), nullable=False),
        sa.Column("importacao_id", sa.Uuid(), nullable=True),
        *_timestamps(),
        sa.CheckConstraint(
            "fonte IN ('manual', 'ofx', 'pluggy')", name=op.f("ck_snapshot_saldo_fonte")
        ),
        sa.ForeignKeyConstraint(
            ["conta_id"], ["conta.id"], name=op.f("fk_snapshot_saldo_conta_id_conta")
        ),
        sa.ForeignKeyConstraint(
            ["importacao_id"],
            ["importacao.id"],
            name=op.f("fk_snapshot_saldo_importacao_id_importacao"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_snapshot_saldo")),
        sa.UniqueConstraint("conta_id", "data", name="uq_snapshot_saldo_conta_id_data"),
    )
    op.create_index(
        op.f("ix_snapshot_saldo_importacao_id"), "snapshot_saldo", ["importacao_id"], unique=False
    )

    op.add_column("transacao", sa.Column("importacao_id", sa.Uuid(), nullable=True))
    op.create_index(
        op.f("ix_transacao_importacao_id"), "transacao", ["importacao_id"], unique=False
    )
    op.create_foreign_key(
        op.f("fk_transacao_importacao_id_importacao"),
        "transacao",
        "importacao",
        ["importacao_id"],
        ["id"],
    )


def downgrade() -> None:
    """Reverte a migration."""
    op.drop_constraint(
        op.f("fk_transacao_importacao_id_importacao"), "transacao", type_="foreignkey"
    )
    op.drop_index(op.f("ix_transacao_importacao_id"), table_name="transacao")
    op.drop_column("transacao", "importacao_id")
    op.drop_index(op.f("ix_snapshot_saldo_importacao_id"), table_name="snapshot_saldo")
    op.drop_table("snapshot_saldo")
    op.drop_index(op.f("ix_importacao_fatura_id"), table_name="importacao")
    op.drop_index(op.f("ix_importacao_conta_id"), table_name="importacao")
    op.drop_table("importacao")
