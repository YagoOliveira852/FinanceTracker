"""Tabelas do planejamento: a configuração do cálculo e as rendas previstas.

O cálculo em si (aporte, alerta, meses de reserva) não é tabela: são as
funções puras de `planejamento/calculo.py`.
"""

import uuid
from decimal import Decimal

from sqlalchemy import CheckConstraint, ForeignKey, Numeric, SmallInteger, Text, true
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, ComTimestamps

ID_CONFIGURACAO = 1


class Configuracao(ComTimestamps, Base):
    """Linha única (`id = 1`), criada no primeiro salvamento: sem ela, o aporte
    não é calculado (spec `2026-10-19-calculo-aporte-alerta-design`, "sem
    valores iniciais")."""

    __tablename__ = "configuracao"
    __table_args__ = (
        CheckConstraint(f"id = {ID_CONFIGURACAO}", name="linha_unica"),
        CheckConstraint("colchao >= 0", name="colchao_nao_negativo"),
        CheckConstraint("meta_reserva_meses > 0", name="meta_reserva_positiva"),
        CheckConstraint("gasto_semanal_estimado >= 0", name="gasto_semanal_nao_negativo"),
        CheckConstraint("gasto_mensal_referencia > 0", name="gasto_mensal_positivo"),
    )

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True, autoincrement=False)
    # Fica na conta depois do aporte.
    colchao: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    # Meta da reserva, em meses de gasto.
    meta_reserva_meses: Mapped[Decimal] = mapped_column(Numeric(4, 1))
    # Piso dos gastos previstos.
    gasto_semanal_estimado: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    # Nulo = automático: média dos 3 últimos meses fechados.
    gasto_mensal_referencia: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))


class RendaPrevista(ComTimestamps, Base):
    """Renda que cai todo mês num dia previsto. Nunca é excluída, só
    desativada (`ativa = false`): inativa, sai do aporte, do alerta e do
    lembrete."""

    __tablename__ = "renda_prevista"
    __table_args__ = (
        CheckConstraint("valor > 0", name="valor_positivo"),
        CheckConstraint("dia_previsto BETWEEN 1 AND 31", name="dia_previsto_valido"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    descricao: Mapped[str] = mapped_column(Text)
    # O líquido que cai na conta: o crédito de 80% a 120% dele é o salário.
    valor: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    # Em mês mais curto, o último dia; depois, o dia útil seguinte.
    dia_previsto: Mapped[int] = mapped_column(SmallInteger)
    # Onde o crédito aparece primeiro (corrente ou carteira).
    conta_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("conta.id"), index=True)
    ativa: Mapped[bool] = mapped_column(default=True, server_default=true())
