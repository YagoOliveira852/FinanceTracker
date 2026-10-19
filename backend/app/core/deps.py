"""Dependências compartilhadas pelas rotas (`Depends`)."""

from typing import Annotated

from fastapi import Depends
from sqlalchemy.orm import Session

from app.core.db import get_sessao

SessaoDep = Annotated[Session, Depends(get_sessao)]
