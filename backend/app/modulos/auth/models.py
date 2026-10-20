"""Tabelas da autenticação: o usuário único e os refresh tokens dele."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, ComTimestamps


class Usuario(ComTimestamps, Base):
    """Só para autenticação: as tabelas do domínio não têm `usuario_id`."""

    __tablename__ = "usuario"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(Text, unique=True)
    senha_hash: Mapped[str] = mapped_column(Text)


class RefreshToken(ComTimestamps, Base):
    """Um refresh token emitido. O token em si nunca é guardado, só o hash.

    Rotação: cada uso grava `revogado_em` e emite um novo. Apresentar de novo
    um token já revogado é sinal de roubo e derruba todas as sessões.
    """

    __tablename__ = "refresh_token"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    usuario_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("usuario.id", ondelete="CASCADE"), index=True
    )
    token_hash: Mapped[str] = mapped_column(Text, unique=True)
    expira_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revogado_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
