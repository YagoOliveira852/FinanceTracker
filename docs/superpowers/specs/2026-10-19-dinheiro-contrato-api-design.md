# Dinheiro no contrato da API e cliente Dart gerado

**Status:** decidida em 2026-10-19.

## Contexto

Dinheiro nunca é float no projeto: `Decimal` no Python, `NUMERIC(14,2)` no Postgres, string no JSON, pacote `decimal` no Dart. Dois detalhes das ferramentas ameaçam essa regra:

1. Para `Decimal`, o Pydantic v2 gera JSON Schema diferente na entrada (`number | string`) e na saída (`string`). O FastAPI então publica schemas duplicados (`XInput`/`XOutput`) e o openapi-generator traduz o campo para um tipo genérico no Dart.
2. O gerador `dart-dio` usa `built_value` por padrão. A alternativa `json_serializable` está marcada como **[BETA]** na documentação do openapi-generator, e o projeto só adota opções estáveis.

## Decisão

- **Tipo único `Dinheiro`** em `backend/app/core/dinheiro.py`: um `Decimal` anotado (Pydantic `Annotated`) que valida com duas casas decimais, serializa como string e declara no schema **sempre** `{"type": "string", "format": "decimal"}`, em entrada e saída. Todo campo monetário de todo schema usa esse tipo; nenhum schema declara `Decimal` direto.
- **Cliente Dart** gerado com `dart-dio` e `serializationLibrary=built_value` (padrão estável), em `app/packages/api_client/`, que ninguém edita à mão.
- **Fronteira no repositório:** o resto do app usa `freezed` (modelos e estados). O repositório de cada feature converte o modelo gerado (`built_value`) no modelo do app (`freezed`) e transforma a `String` monetária em `Decimal`. Telas e cubits nunca veem tipos do cliente gerado.

## Alternativas consideradas

- **`json_serializable` no gerador:** um único estilo de codegen, mas em beta.
- **Só `built_value` no app inteiro:** uma biblioteca a menos, porém mais verbosa e menos comum no Flutter atual.
- **Cliente escrito à mão com dio + freezed:** sem codegen do contrato, mas o compilador deixa de acusar quebras quando a API muda.
- **Deixar o Pydantic gerar o schema padrão de `Decimal`:** produz tipos genéricos no Dart e convida à conversão para `double`.

## Consequências

- O contrato tem uma só representação de dinheiro, verificável no `openapi.json`.
- Duas bibliotecas de codegen convivem no app, mas o `built_value` fica confinado ao pacote gerado.
- O repositório é uma camada anticorrupção: mudanças na API quebram só a conversão, não as telas.
- Testes do backend verificam o schema gerado (campo monetário = `string`/`decimal`) para impedir regressões.
