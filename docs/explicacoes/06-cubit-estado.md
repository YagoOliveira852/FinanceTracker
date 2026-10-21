# 06 — Cubit (flutter_bloc) × `useState` + Context

## O problema

A tela Contas precisa de três situações: carregando, carregada (com os saldos) e erro. O Início e o Lançamento mostram as mesmas contas. Se cada tela buscasse e guardasse os dados sozinha, criar uma conta deixaria o saldo do Início desatualizado.

## Como seria no React Native

```tsx
const ContasContext = createContext(...);

function ContasProvider({children}) {
  const [estado, setEstado] = useState({tipo: 'carregando'});
  const carregar = async () => {
    setEstado({tipo: 'carregando'});
    try { setEstado({tipo: 'carregado', resumo: await api.listar()}); }
    catch (e) { setEstado({tipo: 'erro', mensagem: e.message}); }
  };
  return <ContasContext.Provider value={{estado, carregar}}>{children}</ContasContext.Provider>;
}
```

## Como é com Cubit

```dart
class ContasCubit extends Cubit<ContasEstado> {
  ContasCubit(this._contas) : super(const ContasEstado.carregando());

  Future<void> carregar() async {
    emit(const ContasEstado.carregando());
    try {
      emit(ContasEstado.carregado(await _contas.listar()));
    } on ErroApi catch (erro) {
      emit(ContasEstado.erro(erro.mensagem));
    }
  }
}
```

- `Cubit<Estado>` é o `useState` + as funções que mudam o estado, numa classe testável sem tela.
- `emit(novoEstado)` é o `setEstado`. O estado é **imutável**: sempre um objeto novo, nunca um campo alterado.
- `BlocProvider` é o `Context.Provider`: entrega o cubit a quem está abaixo na árvore.
- Nas telas: `context.watch<ContasCubit>().state` redesenha quando o estado muda (como `useContext`); `context.read<ContasCubit>()` só pega o cubit para chamar um método (num `onPressed`), sem redesenhar.
- `BlocListener` reage a uma mudança sem desenhar nada (fechar a tela quando a conta foi salva, recarregar as contas a cada login), como um `useEffect` que observa o estado.

## Onde cada cubit vive no app

| Cubit | Criado em | Por quê |
|---|---|---|
| `SessaoCubit` | `injecao.dart` | O interceptor do dio e o router dependem dele. |
| `ContasCubit` | `app.dart`, acima do router | Início, Contas e Lançamento mostram as mesmas contas. |
| `TransacoesCubit`, `LoginCubit`, `NovaContaCubit`, `LancamentoCubit` | na rota (`router.dart`) | Estado só daquela tela; some quando a tela fecha. |

## Testes

Como o cubit não sabe de tela, o teste é só "chamo o método, confiro os estados emitidos", com `bloc_test`:

```dart
blocTest<ContasCubit, ContasEstado>(
  'erro da API vira estado de erro com a mensagem',
  build: () => ContasCubit(repositorioQueFalha),
  act: (cubit) => cubit.carregar(),
  expect: () => [
    const ContasEstado.carregando(),
    const ContasEstado.erro('Não foi possível falar com o servidor.'),
  ],
);
```

O repositório é um fake escrito à mão (`test/apoio/`), que implementa a mesma interface do real. É o mesmo papel do `TestClient` com banco de teste no backend: o cubit não sabe que não está falando com a API.
