# 05 — Widgets no Flutter × componentes no React Native

## Tudo é widget

No React Native, a tela é uma árvore de componentes (`<View>`, `<Text>`, `<FlatList>`) e cada componente é uma função que devolve JSX. No Flutter é igual, só que sem JSX: a árvore é escrita em Dart, com construtores aninhados.

```dart
// Flutter                                   // React Native
Column(children: [                           // <View style={{flexDirection: 'column'}}>
  Text('Total disponível'),                  //   <Text>Total disponível</Text>
  Text(formatarDinheiro(total)),             //   <Text>{formatarDinheiro(total)}</Text>
])                                           // </View>
```

Layout também é widget: `Padding`, `SizedBox` (espaço fixo), `Row`/`Column` (flexbox numa direção), `Expanded` (o `flex: 1`). Não existe `style` com margem; o espaçamento vira um widget em volta.

## `build` e `BuildContext`

Todo widget tem um método `build(BuildContext context)` que devolve a sub-árvore, como a função do componente devolve JSX. O `context` é a posição do widget na árvore: é por ele que o widget acha coisas que vieram de cima, como o tema (`Theme.of(context)`, aqui `context.cores`) ou um cubit (`context.read<ContasCubit>()`). É o mesmo papel do `useContext` no React.

## Stateless × Stateful

| Flutter | React Native |
|---|---|
| `StatelessWidget` | componente sem `useState` |
| `StatefulWidget` + `State` | componente com `useState`/`useRef` |
| `setState(() => ...)` | o setter do `useState` |
| `initState` / `dispose` | `useEffect(() => {...; return limpeza}, [])` |

No app, a maioria das telas é `StatelessWidget`: o estado de verdade fica no Cubit (nota 06). `StatefulWidget` aparece só para estado local de tela, como os `TextEditingController` dos formulários (`login_tela.dart`, `nova_conta_tela.dart`), que precisam de `dispose`, igual a limpar um `ref` no `useEffect`.

## Tema em vez de estilos espalhados

O design system virou `app/lib/app/tema.dart`: cores do Material 3 no `ColorScheme`, cores do domínio (receita, despesa, rascunho) num `ThemeExtension` e a escala tipográfica no `TextTheme`. As telas não escrevem cor nem tamanho de fonte à mão; leem do tema, como um `StyleSheet` compartilhado ou um `ThemeProvider`. Claro e escuro são dois `ThemeData`, e o Flutter troca sozinho conforme o sistema.

## Widgets do app

Peças repetidas do design ficam em `app/lib/app/widgets/` (lista com bordas, item de duas linhas, estados vazio e de erro, chips, campos de valor e data). É o equivalente a uma pasta `components/` num app React Native.
