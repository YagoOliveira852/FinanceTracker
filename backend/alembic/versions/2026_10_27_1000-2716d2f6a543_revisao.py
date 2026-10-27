"""par recusado e marcas de duplicata e origem na transacao

Revision ID: 2716d2f6a543
Revises: 82e28d8bd72c
Create Date: 2026-10-27 10:00:00

Só acrescenta: a tabela `par_recusado` e duas colunas nulas em `transacao`
(`possivel_duplicata_de`, `removida_na_origem_em`), que a importação e o
sync da Pluggy vão preencher. As FKs para `transacao` acompanham a exclusão
de rascunho que o sync fará (CASCADE na recusa, SET NULL na marca). O CHECK da
coluna acrescentada é escrito à mão (o autogenerate não o põe no `add_column`).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "2716d2f6a543"
down_revision: str | Sequence[str] | None = "82e28d8bd72c"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Aplica a migration."""
    op.create_table(
        "par_recusado",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("saida_id", sa.Uuid(), nullable=False),
        sa.Column("entrada_id", sa.Uuid(), nullable=False),
        sa.Column(
            "criado_em", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column(
            "atualizado_em",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint("saida_id <> entrada_id", name=op.f("ck_par_recusado_lados_diferentes")),
        sa.ForeignKeyConstraint(
            ["entrada_id"],
            ["transacao.id"],
            name=op.f("fk_par_recusado_entrada_id_transacao"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["saida_id"],
            ["transacao.id"],
            name=op.f("fk_par_recusado_saida_id_transacao"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_par_recusado")),
        sa.UniqueConstraint("saida_id", "entrada_id", name="uq_par_recusado_saida_id_entrada_id"),
    )
    op.create_index(
        op.f("ix_par_recusado_entrada_id"), "par_recusado", ["entrada_id"], unique=False
    )
    op.create_index(op.f("ix_par_recusado_saida_id"), "par_recusado", ["saida_id"], unique=False)

    op.add_column("transacao", sa.Column("possivel_duplicata_de", sa.Uuid(), nullable=True))
    op.add_column(
        "transacao", sa.Column("removida_na_origem_em", sa.DateTime(timezone=True), nullable=True)
    )
    op.create_index(
        op.f("ix_transacao_possivel_duplicata_de"),
        "transacao",
        ["possivel_duplicata_de"],
        unique=False,
    )
    op.create_foreign_key(
        op.f("fk_transacao_possivel_duplicata_de_transacao"),
        "transacao",
        "transacao",
        ["possivel_duplicata_de"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_check_constraint(
        op.f("ck_transacao_duplicata_nao_e_ela_mesma"), "transacao", "possivel_duplicata_de <> id"
    )


def downgrade() -> None:
    """Reverte a migration."""
    op.drop_constraint(op.f("ck_transacao_duplicata_nao_e_ela_mesma"), "transacao", type_="check")
    op.drop_constraint(
        op.f("fk_transacao_possivel_duplicata_de_transacao"), "transacao", type_="foreignkey"
    )
    op.drop_index(op.f("ix_transacao_possivel_duplicata_de"), table_name="transacao")
    op.drop_column("transacao", "removida_na_origem_em")
    op.drop_column("transacao", "possivel_duplicata_de")
    op.drop_index(op.f("ix_par_recusado_saida_id"), table_name="par_recusado")
    op.drop_index(op.f("ix_par_recusado_entrada_id"), table_name="par_recusado")
    op.drop_table("par_recusado")
