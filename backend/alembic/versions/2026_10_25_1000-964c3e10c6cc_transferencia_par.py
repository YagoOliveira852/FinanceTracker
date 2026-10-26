"""liga os dois lados de uma transferência em transacao

Revision ID: 964c3e10c6cc
Revises: c50e7388d2b1
Create Date: 2026-10-25 10:00:00

Só acrescenta: uma coluna nula em `transacao`, com unique e dois CHECK, para o
código da versão anterior continuar funcionando durante o deploy. Os tipos de
transferência já estão no CHECK de `tipo`. Os CHECK da coluna acrescentada são
escritos à mão (o autogenerate não os põe no `add_column`).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "964c3e10c6cc"
down_revision: str | Sequence[str] | None = "c50e7388d2b1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Aplica a migration."""
    op.add_column("transacao", sa.Column("transferencia_par_id", sa.Uuid(), nullable=True))
    op.create_unique_constraint(
        op.f("uq_transacao_transferencia_par_id"), "transacao", ["transferencia_par_id"]
    )
    op.create_foreign_key(
        op.f("fk_transacao_transferencia_par_id_transacao"),
        "transacao",
        "transacao",
        ["transferencia_par_id"],
        ["id"],
    )
    op.create_check_constraint(
        op.f("ck_transacao_par_so_em_transferencia"),
        "transacao",
        "transferencia_par_id IS NULL OR tipo IN ('transferencia_saida', 'transferencia_entrada')",
    )
    op.create_check_constraint(
        op.f("ck_transacao_par_nao_e_ela_mesma"), "transacao", "transferencia_par_id <> id"
    )


def downgrade() -> None:
    """Reverte a migration."""
    op.drop_constraint(op.f("ck_transacao_par_nao_e_ela_mesma"), "transacao", type_="check")
    op.drop_constraint(op.f("ck_transacao_par_so_em_transferencia"), "transacao", type_="check")
    op.drop_constraint(
        op.f("fk_transacao_transferencia_par_id_transacao"), "transacao", type_="foreignkey"
    )
    op.drop_constraint(op.f("uq_transacao_transferencia_par_id"), "transacao", type_="unique")
    op.drop_column("transacao", "transferencia_par_id")
