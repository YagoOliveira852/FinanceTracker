"""Tabela das conexões com a Pluggy: um item MeuPluggy cadastrado pelo app.

O item é só lido (a Pluggy atualiza o proxy uma vez por dia); o sync diário
grava aqui o estado de cada execução. Specs `2026-10-19-pluggy-spike-design` e
`2026-10-20-conexoes-pluggy-design`.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Text, true
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, ComTimestamps
from app.modulos.contas.models import Instituicao


class ConexaoPluggy(ComTimestamps, Base):
    """Item MeuPluggy de um banco. Desativada, o sync não a lê; nunca é
    excluída, e as contas vinculadas continuam ativas, só sem sync."""

    __tablename__ = "conexao_pluggy"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    # Trocado na renovação anual, quando o item novo tem outro id.
    item_id: Mapped[str] = mapped_column(Text, unique=True)
    instituicao_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("instituicao.id"), index=True)
    # Como a Pluggy informa (`UPDATED`, `LOGIN_ERROR`...).
    status: Mapped[str | None] = mapped_column(Text)
    ativa: Mapped[bool] = mapped_column(default=True, server_default=true())
    consentimento_expira_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Último sync bem-sucedido.
    ultimo_sync_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Última execução, com ou sem sucesso: limita o "Buscar agora" e marca a
    # repescagem das 13:00.
    ultima_tentativa_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Em português, para a tela; nulo depois de um sync bem-sucedido.
    ultimo_erro: Mapped[str | None] = mapped_column(Text)
    # Renovação com item novo: até o próximo sync bem-sucedido, transação nova
    # que casa com uma da conta (data, valor, descrição) só troca o id externo.
    renovada_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    instituicao: Mapped[Instituicao] = relationship(lazy="joined")
