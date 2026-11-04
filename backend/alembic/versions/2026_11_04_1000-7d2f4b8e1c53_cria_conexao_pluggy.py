"""cria conexao_pluggy e os vínculos com a Pluggy

Revision ID: 7d2f4b8e1c53
Revises: 3e8a6f2b9c41
Create Date: 2026-11-04 10:00:00

`conexao_pluggy` guarda o item MeuPluggy de cada banco e o estado do sync
(spec `2026-10-20-conexoes-pluggy-design`). `conta` ganha o vínculo com a conta
da Pluggy e `fatura`, o id da fatura em `/bills`. Só acrescenta tabela e
colunas nulas.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "7d2f4b8e1c53"
down_revision: str | Sequence[str] | None = "3e8a6f2b9c41"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Aplica a migration."""
    op.create_table(
        "conexao_pluggy",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("item_id", sa.Text(), nullable=False),
        sa.Column("instituicao_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.Text(), nullable=True),
        sa.Column("ativa", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("consentimento_expira_em", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ultimo_sync_em", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ultima_tentativa_em", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ultimo_erro", sa.Text(), nullable=True),
        sa.Column(
            "criado_em", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column(
            "atualizado_em",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["instituicao_id"],
            ["instituicao.id"],
            name=op.f("fk_conexao_pluggy_instituicao_id_instituicao"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_conexao_pluggy")),
        sa.UniqueConstraint("item_id", name=op.f("uq_conexao_pluggy_item_id")),
    )
    op.create_index(op.f("ix_conexao_pluggy_instituicao_id"), "conexao_pluggy", ["instituicao_id"])

    op.add_column("conta", sa.Column("pluggy_account_id", sa.Text(), nullable=True))
    op.add_column("conta", sa.Column("conexao_pluggy_id", sa.Uuid(), nullable=True))
    op.add_column("conta", sa.Column("pluggy_numero_final", sa.Text(), nullable=True))
    op.create_unique_constraint(op.f("uq_conta_pluggy_account_id"), "conta", ["pluggy_account_id"])
    op.create_foreign_key(
        op.f("fk_conta_conexao_pluggy_id_conexao_pluggy"),
        "conta",
        "conexao_pluggy",
        ["conexao_pluggy_id"],
        ["id"],
    )
    op.create_index(op.f("ix_conta_conexao_pluggy_id"), "conta", ["conexao_pluggy_id"])

    op.add_column("fatura", sa.Column("pluggy_bill_id", sa.Text(), nullable=True))
    op.create_unique_constraint(op.f("uq_fatura_pluggy_bill_id"), "fatura", ["pluggy_bill_id"])


def downgrade() -> None:
    """Desfaz a migration."""
    op.drop_constraint(op.f("uq_fatura_pluggy_bill_id"), "fatura", type_="unique")
    op.drop_column("fatura", "pluggy_bill_id")
    op.drop_index(op.f("ix_conta_conexao_pluggy_id"), table_name="conta")
    op.drop_constraint(
        op.f("fk_conta_conexao_pluggy_id_conexao_pluggy"), "conta", type_="foreignkey"
    )
    op.drop_constraint(op.f("uq_conta_pluggy_account_id"), "conta", type_="unique")
    op.drop_column("conta", "pluggy_numero_final")
    op.drop_column("conta", "conexao_pluggy_id")
    op.drop_column("conta", "pluggy_account_id")
    op.drop_index(op.f("ix_conexao_pluggy_instituicao_id"), table_name="conexao_pluggy")
    op.drop_table("conexao_pluggy")
