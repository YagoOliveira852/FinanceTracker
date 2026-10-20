from decimal import Decimal

import pytest
from fastapi import FastAPI
from pydantic import BaseModel, ValidationError

from app.core.dinheiro import Dinheiro, DinheiroPositivo
from app.main import app

SCHEMA_DINHEIRO = {"type": "string", "format": "decimal"}


class Exemplo(BaseModel):
    valor: Dinheiro


class ExemploPositivo(BaseModel):
    valor: DinheiroPositivo


@pytest.mark.parametrize(
    ("entrada", "esperado"),
    [
        ("1234.56", Decimal("1234.56")),
        ("-10", Decimal("-10.00")),
        ("0.5", Decimal("0.50")),
        ("999999999999.99", Decimal("999999999999.99")),
        (Decimal("10.500"), Decimal("10.50")),
        (Decimal("1E+2"), Decimal("100.00")),
    ],
)
def test_aceita_string_decimal_e_decimal(entrada, esperado):
    valor = Exemplo(valor=entrada).valor

    assert valor == esperado
    assert valor.as_tuple().exponent == -2


@pytest.mark.parametrize(
    "entrada",
    [
        1.5,  # float perde precisão: recusado
        10,  # número JSON também: o contrato é string
        True,
        None,
        "1,50",
        "1.555",
        " 1.50",
        "1e3",
        "NaN",
        "",
        "1000000000000.00",  # mais de 12 dígitos inteiros não cabe em NUMERIC(14,2)
        Decimal("10.555"),
        Decimal("NaN"),
        Decimal("Infinity"),
    ],
)
def test_recusa_valor_fora_do_formato(entrada):
    with pytest.raises(ValidationError) as erro:
        Exemplo(valor=entrada)

    assert erro.value.errors()[0]["type"] == "dinheiro_invalido"


def test_dinheiro_positivo_aceita_a_partir_de_um_centavo():
    assert ExemploPositivo(valor="0.01").valor == Decimal("0.01")


@pytest.mark.parametrize("entrada", ["0", "0.00", "-0.01", "-10"])
def test_dinheiro_positivo_recusa_zero_e_negativo(entrada):
    with pytest.raises(ValidationError) as erro:
        ExemploPositivo(valor=entrada)

    assert erro.value.errors()[0]["type"] == "dinheiro_invalido"
    assert erro.value.errors()[0]["msg"] == "Informe um valor maior que zero."


def test_dinheiro_positivo_mantem_o_formato_de_dinheiro():
    with pytest.raises(ValidationError):
        ExemploPositivo(valor=1.5)
    assert ExemploPositivo.model_json_schema()["properties"]["valor"] == {
        **SCHEMA_DINHEIRO,
        "title": "Valor",
    }
    assert ExemploPositivo(valor="3").model_dump(mode="json") == {"valor": "3.00"}


def test_serializa_como_string_com_duas_casas():
    assert Exemplo(valor="1234.5").model_dump(mode="json") == {"valor": "1234.50"}
    assert Exemplo(valor="-3").model_dump_json() == '{"valor":"-3.00"}'


def test_schema_openapi_e_string_decimal_na_entrada_e_na_saida():
    api = FastAPI()

    @api.post("/exemplo")
    def ecoar(exemplo: Exemplo) -> Exemplo:
        return exemplo

    schemas = api.openapi()["components"]["schemas"]

    # Sem Exemplo-Input/Exemplo-Output: um schema só, igual nos dois sentidos.
    assert "Exemplo" in schemas
    assert not any(nome.startswith("Exemplo-") for nome in schemas)
    assert schemas["Exemplo"]["properties"]["valor"] == {**SCHEMA_DINHEIRO, "title": "Valor"}


def _schemas_com_numero(no) -> list:
    """Procura, recursivamente, schemas `number` (float, ou Decimal cru: number|string)."""
    if isinstance(no, dict):
        encontrados = [no] if no.get("type") == "number" else []
        return encontrados + [s for filho in no.values() for s in _schemas_com_numero(filho)]
    if isinstance(no, list):
        return [s for filho in no for s in _schemas_com_numero(filho)]
    return []


def test_openapi_da_app_nao_tem_decimal_cru_nem_schema_duplicado():
    """Guarda contra regressão: campo monetário declarado sem o tipo Dinheiro."""
    schemas = app.openapi().get("components", {}).get("schemas", {})

    assert [nome for nome in schemas if nome.endswith(("-Input", "-Output"))] == []
    assert _schemas_com_numero(schemas) == []
