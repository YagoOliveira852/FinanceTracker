"""Entrada e saída HTTP de categorias e regras de classificação."""

import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.modulos.categorias.models import GrupoCategoria, OrigemRegra


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


class RegraEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    padrao: str = Field(
        min_length=1,
        max_length=200,
        description=(
            "Normalizado ao salvar: sem acentos, números, datas e termos genéricos "
            'como "pix enviado". Não pode ficar vazio depois disso.'
        ),
    )
    categoria_id: uuid.UUID = Field(description="Categoria ativa.")
    conta_id: uuid.UUID | None = Field(
        default=None, description="Restringe a regra a uma conta ativa; nulo = todas."
    )


class ContaDaRegra(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    nome: str


class RegraSaida(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    padrao: str
    categoria: CategoriaResumo
    conta: ContaDaRegra | None = Field(description="A conta a que a regra se restringe.")
    origem: OrigemRegra = Field(description="Aprendida na revisão ou manual (editar torna manual).")
    vezes_aplicada: int = Field(description="Sugestões confirmadas como vieram.")
    criado_em: datetime


class ExemploRascunho(BaseModel):
    descricao: str
    data: date


class RascunhosCasadosSaida(BaseModel):
    quantidade: int = Field(description="Rascunhos sem categoria para os quais ela é a sugestão.")
    exemplo: ExemploRascunho | None = Field(description="O mais recente deles.")


class RegraDetalheSaida(RegraSaida):
    rascunhos: RascunhosCasadosSaida
