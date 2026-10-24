"""cria cartao e fatura e fatura_id em transacao

Revision ID: 7b71de313332
Revises: ee51e36d4809
Create Date: 2026-10-24 11:00:00

Só acrescenta: tabelas novas e uma coluna nula em `transacao`, para o código
da versão anterior continuar funcionando durante o deploy. Não há transação de
cartão no banco (o cadastro de cartão não existia), então nenhuma fica sem
fatura.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "7b71de313332"
down_revision: str | Sequence[str] | None = "ee51e36d4809"
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
        "cartao",
        sa.Column("conta_id", sa.Uuid(), nullable=False),
        sa.Column("conta_pagamento_id", sa.Uuid(), nullable=False),
        sa.Column("dia_fechamento", sa.SmallInteger(), nullable=False),
        sa.Column("dia_vencimento", sa.SmallInteger(), nullable=False),
        sa.Column("limite", sa.Numeric(precision=14, scale=2), nullable=True),
        *_timestamps(),
        sa.CheckConstraint(
            "dia_fechamento BETWEEN 1 AND 31", name=op.f("ck_cartao_dia_fechamento_valido")
        ),
        sa.CheckConstraint(
            "dia_vencimento BETWEEN 1 AND 31", name=op.f("ck_cartao_dia_vencimento_valido")
        ),
        sa.CheckConstraint(
            "dia_fechamento <> dia_vencimento", name=op.f("ck_cartao_dias_diferentes")
        ),
        sa.CheckConstraint("limite > 0", name=op.f("ck_cartao_limite_positivo")),
        sa.ForeignKeyConstraint(["conta_id"], ["conta.id"], name=op.f("fk_cartao_conta_id_conta")),
        sa.ForeignKeyConstraint(
            ["conta_pagamento_id"], ["conta.id"], name=op.f("fk_cartao_conta_pagamento_id_conta")
        ),
        sa.PrimaryKeyConstraint("conta_id", name=op.f("pk_cartao")),
    )
    op.create_index(
        op.f("ix_cartao_conta_pagamento_id"), "cartao", ["conta_pagamento_id"], unique=False
    )
    op.create_table(
        "fatura",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("cartao_id", sa.Uuid(), nullable=False),
        sa.Column("competencia", sa.Date(), nullable=False),
        sa.Column("data_fechamento", sa.Date(), nullable=False),
        sa.Column("data_vencimento", sa.Date(), nullable=False),
        sa.Column("valor_informado", sa.Numeric(precision=14, scale=2), nullable=True),
        *_timestamps(),
        sa.CheckConstraint(
            "EXTRACT(DAY FROM competencia) = 1", name=op.f("ck_fatura_competencia_primeiro_dia")
        ),
        sa.CheckConstraint(
            "data_vencimento > data_fechamento",
            name=op.f("ck_fatura_vencimento_depois_do_fechamento"),
        ),
        sa.CheckConstraint(
            "valor_informado >= 0", name=op.f("ck_fatura_valor_informado_nao_negativo")
        ),
        sa.ForeignKeyConstraint(
            ["cartao_id"], ["cartao.conta_id"], name=op.f("fk_fatura_cartao_id_cartao")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_fatura")),
        sa.UniqueConstraint("cartao_id", "competencia", name="uq_fatura_cartao_id_competencia"),
    )
    op.create_index(op.f("ix_fatura_cartao_id"), "fatura", ["cartao_id"], unique=False)
    op.add_column("transacao", sa.Column("fatura_id", sa.Uuid(), nullable=True))
    op.create_index(op.f("ix_transacao_fatura_id"), "transacao", ["fatura_id"], unique=False)
    op.create_foreign_key(
        op.f("fk_transacao_fatura_id_fatura"), "transacao", "fatura", ["fatura_id"], ["id"]
    )


def downgrade() -> None:
    """Reverte a migration."""
    op.drop_constraint(op.f("fk_transacao_fatura_id_fatura"), "transacao", type_="foreignkey")
    op.drop_index(op.f("ix_transacao_fatura_id"), table_name="transacao")
    op.drop_column("transacao", "fatura_id")
    op.drop_index(op.f("ix_fatura_cartao_id"), table_name="fatura")
    op.drop_table("fatura")
    op.drop_index(op.f("ix_cartao_conta_pagamento_id"), table_name="cartao")
    op.drop_table("cartao")
