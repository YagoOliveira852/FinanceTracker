"""Entrada e saída HTTP de cartões e faturas."""

import uuid
from datetime import date

from pydantic import BaseModel, ConfigDict, Field

from app.core.dinheiro import Dinheiro, DinheiroPositivo
from app.modulos.cartoes.datas import StatusFatura
from app.modulos.cartoes.faturas import AjusteData, DetalheFatura, ListaFaturas, ResumoFatura
from app.modulos.transacoes.schemas import TransacaoSaida


class CartaoEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nome: str = Field(min_length=1, max_length=100)
    instituicao: str = Field(
        min_length=1,
        max_length=100,
        description=(
            "Nome da instituição. Se nenhuma tiver esse nome (sem diferenciar "
            "maiúsculas), uma nova é criada."
        ),
    )
    conta_pagamento_id: uuid.UUID = Field(description="Conta corrente ativa que paga a fatura.")
    dia_fechamento: int = Field(ge=1, le=31, description="31 vira o último dia do mês.")
    dia_vencimento: int = Field(
        ge=1, le=31, description="Diferente do fechamento; 31 vira o último dia do mês."
    )
    limite: DinheiroPositivo | None = None


class CartaoEdicao(CartaoEntrada):
    """Os mesmos campos do cadastro, mais `ativa` (desativar ou reativar)."""

    ativa: bool


class DatasFaturaSaida(BaseModel):
    """Competência e datas efetivas de uma fatura (ajustadas para dia útil)."""

    competencia: date = Field(description="Primeiro dia do mês do vencimento.")
    data_fechamento: date
    data_vencimento: date


class FaturaResumo(BaseModel):
    """Uma fatura: gravada ou, enquanto não recebeu transação nem foi editada,
    calculada pela regra do cartão."""

    competencia: date = Field(description="Primeiro dia do mês do vencimento.")
    data_fechamento: date
    data_vencimento: date
    status: StatusFatura = Field(description="Aberta antes do fechamento; fechada a partir dele.")
    valor: Dinheiro = Field(description="O maior entre o informado e o calculado.")
    valor_calculado: Dinheiro = Field(
        description="Compras menos estornos da fatura, com rascunhos e sem as ignoradas."
    )
    valor_informado: Dinheiro | None = Field(description="O total que o banco mostra.")


class CartaoSaida(BaseModel):
    conta_pagamento_id: uuid.UUID
    dia_fechamento: int
    dia_vencimento: int
    limite: Dinheiro | None
    fatura_atual: FaturaResumo = Field(description="A fatura de uma compra feita hoje.")


class ListaFaturasSaida(BaseModel):
    atual: FaturaResumo = Field(description="A fatura de uma compra feita hoje.")
    proximas: list[FaturaResumo] = Field(description="Gravadas depois da atual, em ordem.")
    anteriores: list[FaturaResumo] = Field(description="Gravadas antes da atual, da mais recente.")


class FaturaEdicao(BaseModel):
    """Os três campos vão sempre (o formulário manda tudo): `valor_informado`
    nulo apaga o valor informado."""

    model_config = ConfigDict(extra="forbid")

    data_fechamento: date
    data_vencimento: date
    valor_informado: Dinheiro | None


class AjusteEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    valor_real: Dinheiro = Field(description="O total que o banco cobra; não negativo.")
    descricao: str | None = Field(
        default=None,
        min_length=1,
        max_length=200,
        description='A causa da diferença; sem ela, "Ajuste da fatura".',
    )


class FeriadoSaida(BaseModel):
    data: date
    descricao: str


class AjusteDataSaida(BaseModel):
    """A data prevista (o dia do cartão) não era dia útil."""

    data_prevista: date
    feriados: list[FeriadoSaida] = Field(
        description="Feriados pulados até a data efetiva; vazia se só o fim de semana pesou."
    )


class FaturaDetalheSaida(FaturaResumo):
    fechamento_calculado: date = Field(description="Pela regra do cartão, ignorando edições.")
    vencimento_calculado: date = Field(description="Pela regra do cartão, ignorando edições.")
    ajuste_fechamento: AjusteDataSaida | None = Field(
        description="Por que o fechamento calculado não é o dia do cartão; nulo se é."
    )
    ajuste_vencimento: AjusteDataSaida | None = Field(
        description="Por que o vencimento calculado não é o dia do cartão; nulo se é."
    )
    transacoes: list[TransacaoSaida] = Field(description="Sem as ignoradas, das mais recentes.")


def lista_saida(lista: ListaFaturas) -> ListaFaturasSaida:
    return ListaFaturasSaida(
        atual=resumo_saida(lista.atual),
        proximas=[resumo_saida(r) for r in lista.proximas],
        anteriores=[resumo_saida(r) for r in lista.anteriores],
    )


def detalhe_saida(detalhe: DetalheFatura) -> FaturaDetalheSaida:
    return FaturaDetalheSaida(
        **resumo_saida(detalhe.resumo).model_dump(),
        fechamento_calculado=detalhe.datas_calculadas.fechamento,
        vencimento_calculado=detalhe.datas_calculadas.vencimento,
        ajuste_fechamento=_ajuste_saida(detalhe.ajuste_fechamento),
        ajuste_vencimento=_ajuste_saida(detalhe.ajuste_vencimento),
        transacoes=[TransacaoSaida.model_validate(t) for t in detalhe.transacoes],
    )


def _ajuste_saida(ajuste: AjusteData | None) -> AjusteDataSaida | None:
    if ajuste is None:
        return None
    return AjusteDataSaida(
        data_prevista=ajuste.data_prevista,
        feriados=[FeriadoSaida(data=d, descricao=n) for d, n in ajuste.feriados.items()],
    )


def resumo_saida(resumo: ResumoFatura) -> FaturaResumo:
    return FaturaResumo(
        competencia=resumo.competencia,
        data_fechamento=resumo.data_fechamento,
        data_vencimento=resumo.data_vencimento,
        status=resumo.status,
        valor=resumo.valor,
        valor_calculado=resumo.valor_calculado,
        valor_informado=resumo.valor_informado,
    )
