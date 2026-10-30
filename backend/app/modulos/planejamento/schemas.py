"""Entrada e saída HTTP do planejamento: rendas previstas e configuração."""

import re
import uuid
from datetime import date
from decimal import Decimal
from typing import Annotated, Any

from pydantic import (
    BaseModel,
    BeforeValidator,
    ConfigDict,
    Field,
    PlainSerializer,
    WithJsonSchema,
)
from pydantic_core import PydanticCustomError

from app.core.dinheiro import Dinheiro
from app.modulos.cartoes.schemas import FeriadoSaida
from app.modulos.planejamento.service import LeituraConfiguracao, ProximaData, RendaComProxima

_FORMATO_MESES = re.compile(r"-?\d{1,3}(\.\d)?")
_DECIMO = Decimal("0.1")


def _validar_meses(valor: Any) -> Decimal:
    if isinstance(valor, Decimal):
        return valor.quantize(_DECIMO)
    if isinstance(valor, str) and _FORMATO_MESES.fullmatch(valor):
        return Decimal(valor).quantize(_DECIMO)
    raise PydanticCustomError(
        "meses_invalidos",
        'Meses devem ser uma string com até 3 dígitos e 1 casa decimal, ex.: "6" ou "4.5".',
    )


def _serializar_meses(valor: Decimal) -> str:
    return str(valor.quantize(_DECIMO))


# Quantidade de meses com uma casa (NUMERIC(4,1)): como o `Dinheiro`, string
# no JSON nos dois sentidos, para não virar float nem duplicar schemas.
Meses = Annotated[
    Decimal,
    BeforeValidator(_validar_meses),
    PlainSerializer(_serializar_meses, return_type=str),
    WithJsonSchema({"type": "string", "format": "decimal"}),
]


class RendaEntrada(BaseModel):
    """As regras (descrição preenchida, valor > 0, dia de 1 a 31, conta
    corrente ou carteira ativa) ficam no service, com as mensagens da tela."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    descricao: str = Field(max_length=100)
    valor: Dinheiro = Field(description="O líquido que cai na conta; maior que zero.")
    dia_previsto: int = Field(description="Dia do mês, de 1 a 31.")
    conta_id: uuid.UUID = Field(description="Corrente ou carteira ativa onde o crédito aparece.")


class RendaEdicao(RendaEntrada):
    """Os campos do cadastro, mais `ativa` (desativar ou reativar)."""

    ativa: bool


class ProximaDataSaida(BaseModel):
    """Próxima data esperada de uma renda, a partir de hoje (inclusive)."""

    data: date = Field(description="A data efetiva, já em dia útil.")
    data_prevista: date = Field(
        description="O dia da renda no mês; 29 a 31 em mês mais curto vira o último dia."
    )
    feriados: list[FeriadoSaida] = Field(
        description=(
            "Feriados da data prevista até a efetiva (exclusive); vazia se só o fim de "
            "semana pesou ou se a data não mudou."
        )
    )


class RendaSaida(BaseModel):
    id: uuid.UUID
    descricao: str
    valor: Dinheiro
    dia_previsto: int
    conta_id: uuid.UUID
    ativa: bool
    proxima: ProximaDataSaida


def proxima_saida(proxima: ProximaData) -> ProximaDataSaida:
    return ProximaDataSaida(
        data=proxima.data,
        data_prevista=proxima.data_prevista,
        feriados=[FeriadoSaida(data=d, descricao=n) for d, n in proxima.feriados.items()],
    )


def renda_saida(item: RendaComProxima) -> RendaSaida:
    renda = item.renda
    return RendaSaida(
        id=renda.id,
        descricao=renda.descricao,
        valor=renda.valor,
        dia_previsto=renda.dia_previsto,
        conta_id=renda.conta_id,
        ativa=renda.ativa,
        proxima=proxima_saida(item.proxima),
    )


class ConfiguracaoEntrada(BaseModel):
    """Os quatro campos vão sempre (o formulário manda tudo):
    `gasto_mensal_referencia` nulo = automático."""

    model_config = ConfigDict(extra="forbid")

    colchao: Dinheiro = Field(description="Fica na conta depois do aporte; não negativo.")
    meta_reserva_meses: Meses = Field(description="Meta da reserva em meses de gasto; > 0.")
    gasto_semanal_estimado: Dinheiro = Field(description="Piso dos gastos previstos; não negativo.")
    gasto_mensal_referencia: Dinheiro | None = Field(
        description="Valor fixo (> 0) que divide a reserva; nulo = média automática."
    )


class ConfiguracaoValores(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    colchao: Dinheiro
    meta_reserva_meses: Meses
    gasto_semanal_estimado: Dinheiro
    gasto_mensal_referencia: Dinheiro | None = Field(description="Nulo = automático.")


class GastoMensalAutomaticoSaida(BaseModel):
    valor: Dinheiro = Field(description="Média do gasto (despesa − estorno) dos meses.")
    meses: list[date] = Field(
        description="Meses fechados da média (1º dia), do mais antigo ao mais recente; até 3."
    )


class ConfiguracaoSaida(BaseModel):
    configuracao: ConfiguracaoValores | None = Field(
        description="Nula até o primeiro salvamento: sem ela, o aporte não é calculado."
    )
    gasto_mensal_automatico: GastoMensalAutomaticoSaida | None = Field(
        description=(
            "Média dos 3 últimos meses fechados inteiros no histórico, mesmo com valor "
            "fixo salvo; nula sem nenhum."
        )
    )
    media_semanal_real: Dinheiro | None = Field(
        description="Gasto médio por semana nas últimas 8 semanas; nula com menos de 4."
    )
    meses_de_reserva: Meses | None = Field(
        description=(
            "Quantos meses a reserva cobre hoje, pelo gasto mensal que vale (o fixo ou o "
            "automático); nulo sem ele."
        )
    )


def configuracao_saida(leitura: LeituraConfiguracao) -> ConfiguracaoSaida:
    automatico = leitura.gasto_mensal_automatico
    return ConfiguracaoSaida(
        configuracao=(
            None
            if leitura.configuracao is None
            else ConfiguracaoValores.model_validate(leitura.configuracao)
        ),
        gasto_mensal_automatico=(
            None
            if automatico is None
            else GastoMensalAutomaticoSaida(valor=automatico.valor, meses=automatico.meses)
        ),
        media_semanal_real=leitura.media_semanal_real,
        meses_de_reserva=leitura.meses_de_reserva,
    )
