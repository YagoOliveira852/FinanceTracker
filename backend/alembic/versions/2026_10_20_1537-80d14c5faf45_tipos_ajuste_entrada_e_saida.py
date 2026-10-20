"""tipos ajuste_entrada e ajuste_saida em transacao

Revision ID: 80d14c5faf45
Revises: cf34fc468d1f
Create Date: 2026-10-20 15:37:24.032376

Escrita à mão: o autogenerate não enxerga mudança em CHECK. Os valores ficam
copiados aqui (e não importados do enum) para a migration não mudar junto com
o código.
"""

from collections.abc import Sequence

from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "80d14c5faf45"
down_revision: str | Sequence[str] | None = "cf34fc468d1f"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_TIPOS_ANTES = (
    "'despesa', 'receita', 'transferencia_saida', 'transferencia_entrada', "
    "'pagamento_fatura', 'aporte', 'resgate', 'estorno'"
)
_TIPOS_DEPOIS = f"{_TIPOS_ANTES}, 'ajuste_entrada', 'ajuste_saida'"


def upgrade() -> None:
    """Aplica a migration."""
    op.drop_constraint(op.f("ck_transacao_tipo"), "transacao", type_="check")
    op.create_check_constraint(op.f("ck_transacao_tipo"), "transacao", f"tipo IN ({_TIPOS_DEPOIS})")


def downgrade() -> None:
    """Reverte a migration. Falha se já existir transação de ajuste."""
    op.drop_constraint(op.f("ck_transacao_tipo"), "transacao", type_="check")
    op.create_check_constraint(op.f("ck_transacao_tipo"), "transacao", f"tipo IN ({_TIPOS_ANTES})")
