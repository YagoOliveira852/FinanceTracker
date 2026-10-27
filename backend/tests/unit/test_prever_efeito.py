"""O efeito que a confirmação de uma categoria terá nas regras (função pura,
a mesma que `aprender` usa)."""

import uuid
from dataclasses import dataclass

import pytest

from app.modulos.categorias.regras import EfeitoAprendizado, prever_efeito


@dataclass(frozen=True)
class Regra:
    padrao: str
    origem: str = "aprendida"
    conta_id: uuid.UUID | None = None


@pytest.mark.parametrize(
    ("sugerida", "padrao", "mesma_categoria", "efeito"),
    [
        (None, "posto ficticio", False, EfeitoAprendizado.criada),
        (None, "", False, EfeitoAprendizado.nenhuma),
        (Regra("padaria"), "padaria pao quente", True, EfeitoAprendizado.reforcada),
        (Regra("padaria", "manual"), "padaria pao quente", True, EfeitoAprendizado.reforcada),
        (Regra("lanchonete exemplo"), "lanchonete exemplo", False, EfeitoAprendizado.corrigida),
        (Regra("lanchonete"), "lanchonete exemplo", False, EfeitoAprendizado.especializada),
        (
            Regra("lanchonete", "manual"),
            "lanchonete exemplo",
            False,
            EfeitoAprendizado.manual_mantida,
        ),
    ],
)
def test_efeito(sugerida, padrao, mesma_categoria, efeito):
    assert prever_efeito(sugerida, padrao, mesma_categoria) == efeito
