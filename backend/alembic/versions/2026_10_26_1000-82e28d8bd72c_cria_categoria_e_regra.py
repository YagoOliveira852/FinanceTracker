"""cria categoria e regra_classificacao; categoria na transacao

Revision ID: 82e28d8bd72c
Revises: 964c3e10c6cc
Create Date: 2026-10-26 10:00:00

Só acrescenta: duas tabelas novas e uma coluna nula em `transacao`, para o
código da versão anterior continuar funcionando durante o deploy. Seed com a
lista genérica da spec `2026-10-19-revisao-classificacao`, escrita por extenso
(nada pessoal; o usuário renomeia ou cria outras pelo app). Os CHECK e o índice
em `lower(nome)` são escritos à mão.
"""

import uuid
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# Identificadores da revisão, usados pelo Alembic.
revision: str = "82e28d8bd72c"
down_revision: str | Sequence[str] | None = "964c3e10c6cc"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_CATEGORIAS = [
    ("Mercado", "essencial"),
    ("Moradia", "essencial"),
    ("Saúde", "essencial"),
    ("Transporte", "essencial"),
    ("Alimentação", "variavel"),
    ("Assinaturas", "variavel"),
    ("Compras", "variavel"),
    ("Educação", "variavel"),
    ("Lazer", "variavel"),
    ("Salário", "renda"),
    ("Outras receitas", "renda"),
    ("Investimento", "investimento"),
]


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
    categoria = op.create_table(
        "categoria",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("nome", sa.Text(), nullable=False),
        sa.Column("grupo", sa.Text(), nullable=False),
        sa.Column("ativa", sa.Boolean(), server_default=sa.true(), nullable=False),
        *_timestamps(),
        sa.CheckConstraint(
            "grupo IN ('essencial', 'variavel', 'renda', 'investimento')",
            name=op.f("ck_categoria_grupo"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_categoria")),
    )
    op.create_index("uq_categoria_nome_lower", "categoria", [sa.text("lower(nome)")], unique=True)
    op.create_table(
        "regra_classificacao",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("padrao", sa.Text(), nullable=False),
        sa.Column("conta_id", sa.Uuid(), nullable=True),
        sa.Column("categoria_id", sa.Uuid(), nullable=False),
        sa.Column("origem", sa.Text(), nullable=False),
        sa.Column("vezes_aplicada", sa.Integer(), server_default="0", nullable=False),
        *_timestamps(),
        sa.CheckConstraint(
            "origem IN ('manual', 'aprendida')", name=op.f("ck_regra_classificacao_origem")
        ),
        sa.CheckConstraint("padrao <> ''", name=op.f("ck_regra_classificacao_padrao_preenchido")),
        sa.CheckConstraint(
            "vezes_aplicada >= 0", name=op.f("ck_regra_classificacao_vezes_aplicada_valida")
        ),
        sa.ForeignKeyConstraint(
            ["categoria_id"],
            ["categoria.id"],
            name=op.f("fk_regra_classificacao_categoria_id_categoria"),
        ),
        sa.ForeignKeyConstraint(
            ["conta_id"], ["conta.id"], name=op.f("fk_regra_classificacao_conta_id_conta")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_regra_classificacao")),
    )
    op.create_index(
        op.f("ix_regra_classificacao_categoria_id"),
        "regra_classificacao",
        ["categoria_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_regra_classificacao_conta_id"), "regra_classificacao", ["conta_id"], unique=False
    )
    op.add_column("transacao", sa.Column("categoria_id", sa.Uuid(), nullable=True))
    op.create_index(op.f("ix_transacao_categoria_id"), "transacao", ["categoria_id"], unique=False)
    op.create_foreign_key(
        op.f("fk_transacao_categoria_id_categoria"),
        "transacao",
        "categoria",
        ["categoria_id"],
        ["id"],
    )
    op.bulk_insert(
        categoria,
        [{"id": uuid.uuid4(), "nome": nome, "grupo": grupo} for nome, grupo in _CATEGORIAS],
    )


def downgrade() -> None:
    """Reverte a migration."""
    op.drop_constraint(op.f("fk_transacao_categoria_id_categoria"), "transacao", type_="foreignkey")
    op.drop_index(op.f("ix_transacao_categoria_id"), table_name="transacao")
    op.drop_column("transacao", "categoria_id")
    op.drop_index(op.f("ix_regra_classificacao_conta_id"), table_name="regra_classificacao")
    op.drop_index(op.f("ix_regra_classificacao_categoria_id"), table_name="regra_classificacao")
    op.drop_table("regra_classificacao")
    op.drop_index("uq_categoria_nome_lower", table_name="categoria")
    op.drop_table("categoria")
