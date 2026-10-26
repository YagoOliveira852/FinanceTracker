"""Tabelas de categorias e das regras que sugerem a categoria dos rascunhos."""

import uuid
from enum import StrEnum

from sqlalchemy import CheckConstraint, ForeignKey, Index, Text, func, true
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, ComTimestamps, check_enum
from app.modulos.contas.models import Conta


class GrupoCategoria(StrEnum):
    # Essencial e variável são gasto; renda e investimento não entram no gasto do mês.
    essencial = "essencial"
    variavel = "variavel"
    renda = "renda"
    investimento = "investimento"


class OrigemRegra(StrEnum):
    manual = "manual"
    # Criada pela revisão na 1ª confirmação de uma categoria.
    aprendida = "aprendida"


class Categoria(ComTimestamps, Base):
    """Categoria de gasto, renda ou investimento. Nunca é excluída: desativada,
    sai das opções e as transações antigas continuam com ela."""

    __tablename__ = "categoria"
    __table_args__ = (check_enum("grupo", GrupoCategoria),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    nome: Mapped[str] = mapped_column(Text)
    grupo: Mapped[str] = mapped_column(Text)
    ativa: Mapped[bool] = mapped_column(default=True, server_default=true())


# Nome único sem diferenciar maiúsculas ("mercado" = "Mercado").
Index("uq_categoria_nome_lower", func.lower(Categoria.nome), unique=True)


class RegraClassificacao(ComTimestamps, Base):
    """Sugere a categoria de um rascunho quando o `padrao` aparece na descrição
    original normalizada.

    Sem coluna de prioridade: entre as que casam, a ordem sai dos dados (ver
    `classificacao.escolher_regra`). Sem unique no padrão: a mesma palavra pode
    ter uma regra de renda e outra de gasto; o service recusa as demais
    repetições.
    """

    __tablename__ = "regra_classificacao"
    __table_args__ = (
        check_enum("origem", OrigemRegra),
        CheckConstraint("padrao <> ''", name="padrao_preenchido"),
        CheckConstraint("vezes_aplicada >= 0", name="vezes_aplicada_valida"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    # Já normalizado (minúsculas, sem acentos, números e termos genéricos).
    padrao: Mapped[str] = mapped_column(Text)
    # Nulo = vale para todas as contas.
    conta_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("conta.id"), index=True)
    categoria_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("categoria.id"), index=True)
    origem: Mapped[str] = mapped_column(Text)
    # Sugestões confirmadas como vieram; volta a zero quando uma correção troca a categoria.
    vezes_aplicada: Mapped[int] = mapped_column(default=0, server_default="0")

    categoria: Mapped[Categoria] = relationship(lazy="joined")
    conta: Mapped[Conta | None] = relationship(lazy="joined")
