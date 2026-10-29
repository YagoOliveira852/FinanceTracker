"""fonte csv_mercadopago em snapshot_saldo

Revision ID: 9c4d2e7f1a36
Revises: 5b0e3c9a1f27
Create Date: 2026-10-29 10:00:00

O saldo do CSV do extrato do Mercado Pago também vira snapshot (spec
`2026-10-28-importacao-design`, adendo de 2026-10-29). Escrita à mão: o
autogenerate não enxerga mudança em CHECK. Os valores ficam copiados aqui (e
não importados do enum) para a migration não mudar junto com o código.
"""

from collections.abc import Sequence

from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "9c4d2e7f1a36"
down_revision: str | Sequence[str] | None = "5b0e3c9a1f27"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_FONTES_ANTES = "'manual', 'ofx', 'pluggy'"
_FONTES_DEPOIS = "'manual', 'ofx', 'csv_mercadopago', 'pluggy'"


def upgrade() -> None:
    """Aplica a migration."""
    op.drop_constraint(op.f("ck_snapshot_saldo_fonte"), "snapshot_saldo", type_="check")
    op.create_check_constraint(
        op.f("ck_snapshot_saldo_fonte"), "snapshot_saldo", f"fonte IN ({_FONTES_DEPOIS})"
    )


def downgrade() -> None:
    """Reverte a migration. Falha se já existir snapshot vindo do CSV."""
    op.drop_constraint(op.f("ck_snapshot_saldo_fonte"), "snapshot_saldo", type_="check")
    op.create_check_constraint(
        op.f("ck_snapshot_saldo_fonte"), "snapshot_saldo", f"fonte IN ({_FONTES_ANTES})"
    )
