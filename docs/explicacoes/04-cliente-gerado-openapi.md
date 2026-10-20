# 04 — Cliente Dart gerado do OpenAPI

## O caminho

```
backend (rotas + schemas Pydantic)
  → app.openapi()                       contrato em JSON, sem subir servidor
  → openapi-generator (dart-dio)        classes Dart: ContasApi, ContaSaida, ...
  → build_runner (built_value)          .g.dart com serialização e builders
  → app/lib/core/api/cliente_api.dart   cria o cliente com API_URL
  → repositório da feature              converte para os modelos do app
```

`bash scripts/gerar-cliente-api.sh` faz as três primeiras etapas. Rode sempre que um endpoint ou schema mudar.

## Por que gerar em vez de escrever

O FastAPI já descreve cada rota e schema no `/openapi.json`, o mesmo papel do apispec num projeto Flask com Marshmallow. O gerador lê esse contrato e escreve um método Dart por rota e uma classe por schema. Se o backend renomear um campo, o próximo `gerar-cliente-api.sh` muda a classe e o `flutter analyze` aponta cada uso quebrado. Com um cliente escrito à mão, o erro só apareceria em tempo de execução.

## `built_value` e `build_runner`

O Dart não tem reflexão no Flutter, então serializar JSON exige código gerado. As classes do cliente declaram só os campos (`String get saldoAtual;`). O `build_runner`, uma etapa de codegen como um `npm run codegen` num projeto React Native, escreve o `.g.dart` com o construtor, a igualdade e a conversão de/para JSON. Esses `.g.dart` não vão para o git: o script e o CI os recriam.

## Dinheiro como `String`

O contrato declara dinheiro como `{"type": "string", "format": "decimal"}`, mas o `dart-dio` traduz o formato `decimal` para `double`. O script corrige isso com `--type-mappings decimal=String`. O cliente entrega `"1234.56"`, e o repositório converte para `Decimal` (pacote `decimal`). `double` nunca aparece, nem na leitura nem no envio.

## Nomes dos métodos

O `dart-dio` cria uma classe por tag (`ContasApi`) e um método por rota, com o nome tirado do `operationId` em camelCase. O padrão do FastAPI é `{função}{caminho}_{método}` (`listar_contas_get` → `listarContasGet()`), e o caminho muda o nome do método sempre que a URL muda.

Por isso `app/main.py` passa `generate_unique_id_function=operation_id`: o FastAPI chama essa função para cada rota ao montá-la e publica `<tag>_<função>` (`contas_listar`). É o papel do `endpoint` no Flask, o nome da view que o `url_for` usa, só que publicado no contrato. O prefixo da tag deixa o id único no documento inteiro (`contas_listar` ≠ `transacoes_listar`), como o OpenAPI exige. O script passa `removeOperationIdPrefix=true` ao gerador, que corta tudo até o primeiro `_`, e o método vira `ContasApi.listar()`.

Isso impõe duas regras, garantidas por `tests/unit/test_operation_ids.py`: cada rota tem exatamente uma tag (vem do `APIRouter(tags=[...])`), e a tag não tem `_`. Renomear a função de uma rota renomeia o método no Dart.

## Fronteira

Telas e cubits nunca importam `package:api_client`. O repositório de cada feature converte o modelo gerado no modelo `freezed` do app, como uma camada anticorrupção: se a API mudar, quebra só a conversão.
