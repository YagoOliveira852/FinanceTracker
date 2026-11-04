"""conexao_pluggy.renovada_em

Revision ID: 4a9c1e6d2b78
Revises: 7d2f4b8e1c53
Create Date: 2026-11-04 11:00:00

Marca a renovação com item novo: até o próximo sync bem-sucedido, transação
nova que casa com uma da conta só troca o id externo (spec
`2026-10-20-conexoes-pluggy-design`, decisões do código).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "4a9c1e6d2b78"
down_revision: str | Sequence[str] | None = "7d2f4b8e1c53"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Aplica a migration."""
    op.add_column(
        "conexao_pluggy", sa.Column("renovada_em", sa.DateTime(timezone=True), nullable=True)
    )


def downgrade() -> None:
    """Desfaz a migration."""
    op.drop_column("conexao_pluggy", "renovada_em")
