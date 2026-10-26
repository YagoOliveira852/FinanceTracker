"""Entrada e saída HTTP de categorias e regras de classificação."""

import uuid

from pydantic import BaseModel, ConfigDict, Field

from app.modulos.categorias.models import GrupoCategoria


class CategoriaEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nome: str = Field(min_length=1, max_length=60, description="Único, sem diferenciar maiúsculas.")
    grupo: GrupoCategoria = Field(
        description=(
            "Essencial e variável são gasto (despesa e estorno); renda vale para "
            "receita; investimento, para aporte e resgate."
        )
    )


class CategoriaEdicao(CategoriaEntrada):
    """Os mesmos campos do cadastro, mais `ativa` (desativar ou reativar).

    O grupo só troca de natureza (gasto, renda, investimento) enquanto nenhuma
    transação usa a categoria."""

    ativa: bool


class CategoriaResumo(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    nome: str
    grupo: GrupoCategoria


class CategoriaSaida(CategoriaResumo):
    ativa: bool = Field(description="Desativada sai das opções; as regras dela não sugerem.")
    qtd_regras: int
    qtd_transacoes: int
