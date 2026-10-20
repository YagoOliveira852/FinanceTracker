"""Tipo `Dinheiro`: o único jeito de declarar valor monetário num schema.

- Entrada: string decimal com até 2 casas (`"1234.56"`, `"-10"`, `"0.5"`) ou
  `Decimal` (quando o service monta o schema). Número JSON é recusado: chegaria
  como float e perderia precisão.
- Saída: string com exatamente 2 casas (`"1234.50"`).
- Schema OpenAPI: sempre `{"type": "string", "format": "decimal"}`, na entrada e
  na saída. Assim o FastAPI não duplica schemas (`XInput`/`XOutput`) e o cliente
  Dart recebe `String`. Ver spec `2026-10-19-dinheiro-contrato-api-design.md`.

O sinal é permitido (saldo pode ser negativo). Campo que só aceita valor maior
que zero (ex.: valor de transação, cujo sentido vem do `tipo`) usa
`DinheiroPositivo`.
"""

import re
from decimal import Decimal
from typing import Annotated, Any

from pydantic import AfterValidator, BeforeValidator, PlainSerializer, WithJsonSchema
from pydantic_core import PydanticCustomError

_FORMATO = re.compile(r"-?\d+(\.\d{1,2})?")
_CENTAVO = Decimal("0.01")
# NUMERIC(14,2) no Postgres: até 12 dígitos antes da vírgula.
_LIMITE = Decimal("1E12")


def _erro(mensagem: str) -> PydanticCustomError:
    return PydanticCustomError("dinheiro_invalido", mensagem)


def _validar_entrada(valor: Any) -> Decimal:
    if isinstance(valor, str) and _FORMATO.fullmatch(valor):
        valor = Decimal(valor)
    elif not isinstance(valor, Decimal):
        raise _erro('Valor monetário deve ser uma string com até 2 casas decimais, ex.: "1234.56".')

    if not valor.is_finite():
        raise _erro("Valor monetário deve ser um número finito.")
    if abs(valor) >= _LIMITE:
        raise _erro("Valor monetário deve ter no máximo 12 dígitos antes da vírgula.")
    if valor != valor.quantize(_CENTAVO):
        raise _erro("Valor monetário deve ter no máximo 2 casas decimais.")
    return valor.quantize(_CENTAVO)


def _serializar(valor: Decimal) -> str:
    return str(valor.quantize(_CENTAVO))


Dinheiro = Annotated[
    Decimal,
    BeforeValidator(_validar_entrada),
    PlainSerializer(_serializar, return_type=str),
    WithJsonSchema({"type": "string", "format": "decimal"}),
]


def _exigir_positivo(valor: Decimal) -> Decimal:
    if valor <= 0:
        raise _erro("Informe um valor maior que zero.")
    return valor


DinheiroPositivo = Annotated[Dinheiro, AfterValidator(_exigir_positivo)]
