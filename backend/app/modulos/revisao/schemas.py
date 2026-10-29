"""Entrada e saída HTTP da revisão."""

import uuid
from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.dinheiro import Dinheiro
from app.modulos.cartoes.datas import StatusFatura
from app.modulos.categorias.models import OrigemRegra
from app.modulos.categorias.regras import EfeitoAprendizado
from app.modulos.categorias.schemas import CategoriaResumo
from app.modulos.contas.models import TipoConta
from app.modulos.revisao.service import ManterDuplicata
from app.modulos.transacoes.models import (
    FonteTransacao,
    StatusTransacao,
    TipoTransacao,
    Transacao,
)


class ContaNaRevisao(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    nome: str
    tipo: TipoConta


class TransacaoRevisao(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    conta: ContaNaRevisao
    tipo: TipoTransacao
    valor: Dinheiro
    data: date
    descricao: str
    descricao_original: str = Field(description="Como veio do banco.")
    fonte: FonteTransacao
    status: StatusTransacao
    categoria: CategoriaResumo | None = Field(description="Só a confirmada tem.")
    fatura_competencia: date | None = Field(
        description="Fatura em que a compra entra (cartão), ou a paga (pagamento de fatura)."
    )
    removida_na_origem_em: datetime | None = Field(
        description="A confirmada que sumiu do Open Finance."
    )

    @model_validator(mode="before")
    @classmethod
    def _montar_da_transacao(cls, dados: Any) -> Any:
        if not isinstance(dados, Transacao):
            return dados
        campos = {
            campo: getattr(dados, campo)
            for campo in cls.model_fields
            if campo != "fatura_competencia"
        }
        competencia = None if dados.fatura is None else dados.fatura.competencia
        return campos | {"fatura_competencia": competencia}


class SugestaoSaida(BaseModel):
    regra_id: uuid.UUID
    padrao: str
    origem: OrigemRegra
    categoria: CategoriaResumo


class PrevisaoDoTipoSaida(BaseModel):
    tipo: TipoTransacao
    sugestao: SugestaoSaida | None = Field(
        description="A sugestão como se o rascunho tivesse este tipo."
    )
    efeito_confirmando: EfeitoAprendizado
    efeito_corrigindo: EfeitoAprendizado


class RascunhoSaida(TransacaoRevisao):
    padrao: str = Field(
        description="A descrição original normalizada (vazia: só termos genéricos)."
    )
    sugestao: SugestaoSaida | None = Field(
        description="Calculada agora pelas regras; não é gravada."
    )
    efeito_confirmando: EfeitoAprendizado = Field(
        description="O que acontece com as regras se confirmar a sugestão (ou, sem sugestão, "
        "qualquer categoria)."
    )
    efeito_corrigindo: EfeitoAprendizado = Field(
        description="O que acontece com as regras se escolher outra categoria."
    )
    outros_tipos: list[PrevisaoDoTipoSaida] = Field(
        description="Sugestão e efeitos se confirmar com outro tipo (entrada como receita ou "
        "estorno): a sugestão depende do tipo."
    )


class ParSaida(BaseModel):
    saida: TransacaoRevisao
    entrada: TransacaoRevisao
    dias: int = Field(description="Diferença de dias entre as duas (até 2).")


class DuplicataSaida(BaseModel):
    rascunho: TransacaoRevisao = Field(description="O que chegou por último, marcado.")
    outra: TransacaoRevisao = Field(description="A que já estava (confirmada ou rascunho).")


class RevisaoSaida(BaseModel):
    total: int = Field(description="Linhas para revisar (um par conta 1): o contador da aba.")
    qtd_sugeridos: int = Field(description="Rascunhos comuns com categoria sugerida (o lote).")
    pares: list[ParSaida]
    pagamentos: list[TransacaoRevisao] = Field(description="Pagamentos de fatura das fontes.")
    duplicatas: list[DuplicataSaida]
    sumidas: list[TransacaoRevisao] = Field(description="Confirmadas que sumiram da origem.")
    rascunhos: list[RascunhoSaida] = Field(description="Os comuns, da data mais recente.")


class ConfirmacaoEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    descricao: str = Field(min_length=1, max_length=200)
    categoria_id: uuid.UUID = Field(description="Ativa e do grupo que combina com o tipo.")
    tipo: Literal[TipoTransacao.despesa, TipoTransacao.receita, TipoTransacao.estorno] | None = (
        Field(
            default=None,
            description="Troca o tipo no mesmo sentido (saída: despesa; entrada: receita ou "
            "estorno); nulo mantém.",
        )
    )


class ConfirmacaoSaida(BaseModel):
    efeito: EfeitoAprendizado = Field(description="O que a confirmação fez com as regras.")
    regra_padrao: str | None = Field(description="O padrão da regra criada, reforçada ou mantida.")


class LoteEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    ids: list[uuid.UUID] = Field(
        min_length=1, max_length=500, description="Os rascunhos com sugestão que o app mostrou."
    )


class LoteSaida(BaseModel):
    confirmados: int = Field(description="Os que ainda tinham sugestão e foram confirmados.")


class ParEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    saida_id: uuid.UUID
    entrada_id: uuid.UUID
    descricao: str | None = Field(
        default=None, max_length=200, description="Vale para os dois lados; vazia mantém."
    )


class ParRecusaEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    saida_id: uuid.UUID
    entrada_id: uuid.UUID


class TransferenciaRevisaoEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    conta_id: uuid.UUID = Field(
        description='A outra conta: "Para" numa saída, "De" numa entrada. Corrente ou '
        "carteira ativa."
    )
    descricao: str = Field(min_length=1, max_length=200, description="Vale para os dois lados.")


class FaturaCandidataSaida(BaseModel):
    cartao_id: uuid.UUID
    cartao_nome: str
    competencia: date = Field(description="Primeiro dia do mês do vencimento.")
    status: StatusFatura = Field(description="Como está hoje, sem este pagamento.")
    data_vencimento: date
    valor: Dinheiro
    valor_pago: Dinheiro = Field(description="Já pago, sem este pagamento.")
    fica_paga: bool = Field(description="Com este pagamento, a fatura fica paga.")
    sugerida: bool = Field(description="A pré-selecionada (no máximo uma).")


class PagamentoRevisaoEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cartao_id: uuid.UUID
    competencia: str = Field(
        pattern=r"^\d{4}-(0[1-9]|1[0-2])$", description="Mês da fatura, `AAAA-MM`."
    )


class DuplicataEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    manter: ManterDuplicata = Field(
        description="`rascunho`: fica o que chegou por último, confirmado no lugar da outra se "
        "ela estava confirmada; `outra`: fica a que já estava; `as_duas`: não é duplicata."
    )
