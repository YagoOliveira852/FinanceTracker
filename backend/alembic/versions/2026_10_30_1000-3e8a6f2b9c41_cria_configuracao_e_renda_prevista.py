"""cria configuracao e renda_prevista

Revision ID: 3e8a6f2b9c41
Revises: 9c4d2e7f1a36
Create Date: 2026-10-30 10:00:00

Só acrescenta tabelas. `configuracao` nasce vazia: a linha única (`id = 1`)
é criada no primeiro salvamento (spec `2026-10-19-calculo-aporte-alerta-design`,
"sem valores iniciais"). Os CHECK estão escritos à mão: o autogenerate não os
enxerga.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "3e8a6f2b9c41"
down_revision: str | Sequence[str] | None = "9c4d2e7f1a36"
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
        "configuracao",
        sa.Column("id", sa.SmallInteger(), autoincrement=False, nullable=False),
        sa.Column("colchao", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("meta_reserva_meses", sa.Numeric(precision=4, scale=1), nullable=False),
        sa.Column("gasto_semanal_estimado", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("gasto_mensal_referencia", sa.Numeric(precision=14, scale=2), nullable=True),
        *_timestamps(),
        sa.CheckConstraint("id = 1", name=op.f("ck_configuracao_linha_unica")),
        sa.CheckConstraint("colchao >= 0", name=op.f("ck_configuracao_colchao_nao_negativo")),
        sa.CheckConstraint(
            "meta_reserva_meses > 0", name=op.f("ck_configuracao_meta_reserva_positiva")
        ),
        sa.CheckConstraint(
            "gasto_semanal_estimado >= 0", name=op.f("ck_configuracao_gasto_semanal_nao_negativo")
        ),
        sa.CheckConstraint(
            "gasto_mensal_referencia > 0", name=op.f("ck_configuracao_gasto_mensal_positivo")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_configuracao")),
    )
    op.create_table(
        "renda_prevista",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("descricao", sa.Text(), nullable=False),
        sa.Column("valor", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("dia_previsto", sa.SmallInteger(), nullable=False),
        sa.Column("conta_id", sa.Uuid(), nullable=False),
        sa.Column("ativa", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        *_timestamps(),
        sa.CheckConstraint("valor > 0", name=op.f("ck_renda_prevista_valor_positivo")),
        sa.CheckConstraint(
            "dia_previsto BETWEEN 1 AND 31", name=op.f("ck_renda_prevista_dia_previsto_valido")
        ),
        sa.ForeignKeyConstraint(
            ["conta_id"], ["conta.id"], name=op.f("fk_renda_prevista_conta_id_conta")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_renda_prevista")),
    )
    op.create_index(
        op.f("ix_renda_prevista_conta_id"), "renda_prevista", ["conta_id"], unique=False
    )


def downgrade() -> None:
    """Reverte a migration."""
    op.drop_index(op.f("ix_renda_prevista_conta_id"), table_name="renda_prevista")
    op.drop_table("renda_prevista")
    op.drop_table("configuracao")
