# 07 — freezed e `build_runner`: classes de dados geradas

## O problema

Estados e modelos do app precisam de igualdade por valor (o `bloc_test` compara estados com `==`), de `copyWith` para mudar um campo sem mexer no resto, e de uniões ("carregando **ou** carregado **ou** erro"). Escrever isso à mão em Dart dá dezenas de linhas por classe.

## O que o freezed faz

Declaramos só a forma:

```dart
@freezed
sealed class ContasEstado with _$ContasEstado {
  const factory ContasEstado.carregando() = ContasCarregando;
  const factory ContasEstado.carregado(ResumoContas resumo) = ContasCarregado;
  const factory ContasEstado.erro(String mensagem) = ContasErro;
}
```

O `build_runner` lê a anotação e escreve `contas_cubit.freezed.dart` com `==`, `hashCode`, `toString` e `copyWith`. É o papel de um `npm run codegen` (GraphQL Codegen, por exemplo) num projeto React Native, ou de um `@dataclass(frozen=True)` no Python, só que gerado em arquivo.

Uma união `sealed` vira tipo soma, como uma union discriminada no TypeScript (`{tipo: 'carregando'} | {tipo: 'erro', mensagem: string}`). O `switch` do Dart obriga a tratar todos os casos:

```dart
switch (estado) {
  ContasCarregando() => const Carregando(),
  ContasErro(:final mensagem) => ErroComTentar(mensagem: mensagem, ...),
  ContasCarregado(:final resumo) => ListaDeContas(resumo),
}
```

Se alguém acrescentar um quarto estado, o `flutter analyze` aponta cada `switch` que ficou incompleto.

## Dois codegens no projeto

| Onde | Gerador | Saída | Para quê |
|---|---|---|---|
| `app/packages/api_client/` | built_value | `*.g.dart` | Serializar o JSON do cliente gerado do OpenAPI (nota 04). |
| `app/lib/` | freezed | `*.freezed.dart` | Modelos e estados do app. |

O repositório converte um no outro: `ContaSaida` (built_value, dinheiro `String`) vira `Conta` (freezed, dinheiro `Decimal`). As telas só conhecem o segundo.

## Na prática

- Depois de criar ou mudar uma classe `@freezed`: `dart run build_runner build` em `app/`. Erro de "part file not found" ou `_$Classe` indefinido quase sempre é isso.
- Os `*.freezed.dart` e `*.g.dart` ficam fora do git (`app/.gitignore`); o CI roda o `build_runner` antes do `flutter analyze`.
- Não há `json_serializable` no app: quem lê JSON é o cliente gerado. Ele entra quando o app tiver JSON próprio (cache do drift, por exemplo).
