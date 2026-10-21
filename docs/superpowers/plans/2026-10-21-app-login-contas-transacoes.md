# App Flutter: login + contas + transações — plano de implementação

> **Para agentes:** use superpowers:executing-plans (ou subagent-driven-development) para executar tarefa por tarefa. Passos com checkbox (`- [ ]`).

**Objetivo:** o app Android faz login na API, mostra e cria contas, lança despesa/receita e lista as transações do mês, com tema claro/escuro do design system e placeholders "em breve" para o que ainda não existe.

**Arquitetura:** `lib/features/<feature>/{data,cubit,ui}`. O repositório de cada feature é o único que usa o cliente gerado (`package:api_client`) e converte para modelos `freezed` do app (dinheiro `String` → `Decimal`, `Date` → `DateTime`). `lib/core/api/` monta o dio com o interceptor de token/refresh. A navegação é um `go_router` com quatro abas (`StatefulShellRoute`) e um `redirect` que segue o estado da sessão.

**Stack:** Flutter 3.47.7 / Dart 3, go_router, flutter_bloc (Cubit), dio, freezed, flutter_secure_storage, decimal, intl + flutter_localizations, bloc_test.

**Referências:** card S2 · App Flutter (Trello `qTNlGFwI`), `docs/arquitetura.md` §5 e §8, `docs/explicacoes/04-cliente-gerado-openapi.md`, spec `2026-10-19-dinheiro-contrato-api-design.md`, design aprovado no canvas do Claude Design (páginas Login, Início, Contas, Nova conta, Transações, Lançamento, Mais).

## Restrições globais

- Dinheiro nunca é `double`: `Decimal` do pacote `decimal` do repositório até a tela; formatação `R$ 1.234,56` só em `lib/core/formatacao/`.
- Telas e cubits nunca importam `package:api_client`; só `features/*/data/` e `core/api/`.
- Textos de interface, comentários e commits em pt-BR; identificadores do domínio em português sem acento.
- 401 de `/auth/login` ou `/auth/refresh` nunca dispara refresh. Um refresh por vez (fila).
- Só dados fictícios em testes e prints (ex.: "Conta principal", "Banco Exemplo", `ana@exemplo.com`).
- Tela que ainda não existe aparece como "em breve", nunca escondida.
- `flutter analyze` sem avisos e `flutter test` verde a cada commit.

## Decisões deste plano (confirmar com o Yago)

1. **Dependências novas** (cada uma precisa de ok): `go_router`, `flutter_bloc`, `freezed_annotation`, `flutter_secure_storage`, `decimal`, `intl`, `flutter_localizations` (SDK, para o seletor de data e textos do Material em pt-BR); dev: `build_runner`, `freezed`, `bloc_test`. **Sem `mocktail` e sem `json_serializable`:** os testes usam fakes escritos à mão (implementam a interface do repositório) e nenhum modelo do app lê JSON — quem lê é o cliente gerado.
2. **Fonte Manrope** empacotada em `app/assets/fonts/` (arquivo variável do repositório google/fonts, licença OFL, com o `OFL.txt` junto). Alternativa sem download: Roboto, a fonte padrão do Android.
3. **Ícones:** os `Icons.*_rounded` que já vêm no Flutter (Material Icons Rounded), equivalentes aos Material Symbols Rounded do design. Sem pacote de ícones.
4. **Categoria no Lançamento:** campo visível e desabilitado com "Em breve" (categorias chegam na S4). Transferência e Pagamento de fatura: chips visíveis e desabilitados.
5. **Cartões na tela Contas:** seção "Cartões de crédito" visível com um item "Em breve" (cartões chegam na S3). Nova conta oferece só Conta corrente e Carteira, como no design.
6. **Contas e Lançamento só listam contas ativas** de tipo `corrente` e `carteira`. Transações com status `ignorada` não aparecem na lista; `rascunho` aparece com o chip "Rascunho".
7. **Data nos formulários:** campo só leitura que abre o `showDatePicker` em pt-BR (sem digitar a data). Validação local de "data do saldo depois de hoje" usa a data do aparelho; a do servidor continua valendo.
8. **Sessão ao abrir o app:** se há refresh token guardado, o app entra direto (sem chamada de rede); o primeiro 401 renova ou manda para o login com "Sessão expirada". Sair = apagar os tokens locais (não há endpoint de logout).
9. **Badge da aba Revisão** não aparece (não há rascunhos sem importação).

## Review focus

1. Dois 401 simultâneos (Contas e Transações carregando juntas) → exatamente uma chamada a `/auth/refresh`; as duas requisições repetem com o token novo.
2. Refresh recusado (token revogado/expirado) → tokens apagados, tela de login com "Sessão expirada", sem laço de refresh.
3. Valor digitado como `1.234,56`, `1234,5`, `0,00`, `-120,40`, `1.234,567`, `abc` → `Decimal` correto ou mensagem do design; nunca passa por `double`.
4. API fora do ar / sem rede → mensagem "Não foi possível falar com o servidor." com "Tentar de novo", não tela vermelha.
5. Erro 422 do servidor com `campos` (`body.data_saldo_inicial`, `body.conta_id`) → mensagem aparece embaixo do campo certo.

---

## Estrutura de arquivos

```
app/
├── assets/fonts/Manrope-*.ttf, OFL.txt
├── lib/
│   ├── main.dart                         # runApp(FinancasApp) com injeção
│   ├── app/
│   │   ├── app.dart                      # MaterialApp.router, tema, localizações
│   │   ├── injecao.dart                  # cria storage, dio, repositórios, SessaoCubit
│   │   ├── router.dart                   # go_router: rotas, abas, redirect
│   │   ├── tema.dart                     # tokens claro/escuro, CoresFinancas
│   │   └── widgets/                      # EmBreve, CampoTexto, ChipOpcao, ItemLista, EstadoVazio, ErroComTentar
│   ├── core/
│   │   ├── api/
│   │   │   ├── cliente_api.dart          # criarClienteApi(dio, interceptors)
│   │   │   ├── interceptor_auth.dart     # Bearer + refresh em fila
│   │   │   └── erro_api.dart             # ErroApi.de(Object) → mensagem + campos
│   │   ├── auth/armazenamento_tokens.dart
│   │   └── formatacao/{dinheiro.dart,datas.dart}
│   └── features/
│       ├── login/{data/auth_repositorio.dart, cubit/{sessao,login}_cubit.dart, ui/login_tela.dart}
│       ├── inicio/ui/inicio_tela.dart
│       ├── revisao/ui/revisao_tela.dart
│       ├── contas/{data/{conta.dart,contas_repositorio.dart}, cubit/{contas,nova_conta}_cubit.dart, ui/{contas_tela,nova_conta_tela}.dart}
│       ├── transacoes/{data/{transacao.dart,transacoes_repositorio.dart}, cubit/{transacoes,lancamento}_cubit.dart, ui/{transacoes_tela,lancamento_tela}.dart}
│       └── configuracoes/ui/mais_tela.dart
└── test/ (espelha lib/)
```

---

### Tarefa 1: dependências, build_runner do app e CI

**Arquivos:** `app/pubspec.yaml`, `app/pubspec.lock`, `app/.gitignore` (`*.freezed.dart`), `app/build.yaml` (se precisar limitar o freezed a `lib/`), `.github/workflows/app.yml`.

- [ ] `flutter pub add` das dependências aprovadas (versão mais nova compatível com o Flutter 3.47.7); `flutter_localizations` como `sdk: flutter`.
- [ ] `.gitignore`: `*.freezed.dart` (mesma regra dos `.g.dart`).
- [ ] `app.yml`: depois do `flutter pub get --enforce-lockfile`, `dart run build_runner build` em `app/`.
- [ ] `flutter analyze && flutter test` verdes. Commit `chore: dependências do app (go_router, bloc, freezed...)`.

### Tarefa 2: formatação de dinheiro e datas

**Arquivos:** `lib/core/formatacao/dinheiro.dart`, `lib/core/formatacao/datas.dart`, testes em `test/core/formatacao/`.

**Produz:**
- `String formatarDinheiro(Decimal valor)` → `R$ 1.234,56`; negativo `− R$ 120,40` (sinal U+2212, como no design).
- `String formatarDinheiroComSinal(Decimal valor, {required bool entrada})` → `+ R$ 850,00` / `− R$ 187,40`.
- `Decimal? lerDinheiro(String texto, {bool aceitaNegativo = false})` e `String? validarDinheiro(String texto, {bool aceitaNegativo, bool exigePositivo})` → mensagens do design: "Informe um valor maior que zero.", "Use no máximo 2 casas decimais, por exemplo: 1.234,56.", "Valor inválido. Use o formato 1.234,56.".
- `String formatarMesAno(DateTime)` → `Outubro de 2026`; `String formatarCabecalhoDia(DateTime dia, DateTime hoje)` → `Hoje · 20 out`, `Ontem · 19 out`, `Sex · 17 out`; `String formatarData(DateTime)` → `20/10/2026`; `String formatarDataLonga(DateTime)` → `Terça, 20 de outubro`.

- [ ] Testes primeiro: milhar, centavos, zero, negativo, `1234,5` → `1234.50`, `1.234,567` → erro de casas, `abc` → erro, `-120,40` só com `aceitaNegativo`, valor grande `R$ 1.234.567,89`; cabeçalhos de dia (hoje, ontem, dia da semana).
- [ ] Implementar com `Decimal` e `intl` (`DateFormat` em `pt_BR`; testes chamam `initializeDateFormatting('pt_BR')`).
- [ ] Commit `feat: formatação de dinheiro e datas do app`.

### Tarefa 3: tema do design system

**Arquivos:** `lib/app/tema.dart`, `assets/fonts/`, `pubspec.yaml` (fonts), `test/app/tema_test.dart`.

**Produz:** `ThemeData temaClaro()`, `ThemeData temaEscuro()`; `CoresFinancas extends ThemeExtension` com `receita`, `receitaContainer`, `despesa`, `despesaContainer`, `rascunho`, `rascunhoContainer`, `ritmoOk/Atencao/Risco` (+ containers); `Espacos` (4, 8, 12, 16, 20, 24, 32, 40, 48) e `Raios` (8, 12, 16, 28) como constantes.

Valores copiados do `tokens.css` do design system (claro e escuro): `surface #f6f5f1`/`#111514`, `primary #1f5f66`/`#86d0d6` etc. Botão 48 px, campo 56 px, item de lista 72 px, barra de navegação 80 px; Manrope 400/500/600/700.

- [ ] Teste: os dois temas têm `CoresFinancas`; `colorScheme.primary` bate com o token.
- [ ] Commit `feat: tema claro e escuro com os tokens do design system`.

### Tarefa 4: tokens, interceptor de auth e erros da API

**Arquivos:** `lib/core/auth/armazenamento_tokens.dart`, `lib/core/api/interceptor_auth.dart`, `lib/core/api/erro_api.dart`, `lib/core/api/cliente_api.dart`, testes em `test/core/`.

**Produz:**
- `abstract class ArmazenamentoTokens { Future<TokensSessao?> ler(); Future<void> salvar(TokensSessao); Future<void> apagar(); }` + `ArmazenamentoTokensSeguro` (flutter_secure_storage) + `ArmazenamentoTokensMemoria` (testes). `TokensSessao(access, refresh)` é classe do app.
- `class InterceptorAuth extends QueuedInterceptor` com `InterceptorAuth({required ArmazenamentoTokens armazenamento, required Future<TokensSessao> Function(String refresh) renovar, required Dio dio, required void Function() aoExpirarSessao})`. `onRequest`: põe `Authorization: Bearer <access>` (exceto `/auth/login` e `/auth/refresh`). `onError` 401: se a requisição é de `/auth/login` ou `/auth/refresh`, repassa o erro; se o token usado já não é o atual (outra requisição renovou), só repete; senão chama `renovar` uma vez, salva, repete com `dio.fetch`. Falha da renovação → `apagar()`, `aoExpirarSessao()`, repassa o 401. O `QueuedInterceptor` é a fila: trata um erro por vez.
- `renovar` usa um `AuthApi` de um `Dio` **sem** o interceptor (evita laço).
- `class ErroApi { String mensagem; Map<String, String> campos; }` com `factory ErroApi.de(Object erro)`: lê `detail`/`campos` do corpo (`body.valor` → `valor`); sem resposta → "Não foi possível falar com o servidor."; 500 → "Erro no servidor. Tente de novo.".
- `criarClienteApi({String baseUrl, List<Interceptor> interceptors})` passa `interceptors:` (tira os interceptors padrão do gerado).

- [ ] Testes com o adaptador falso do dio (já existe em `cliente_api_test.dart`; extrair para `test/apoio/adaptador_falso.dart`):
  - requisição comum leva `Authorization: Bearer access-1`;
  - 401 → uma chamada a `/auth/refresh`, requisição repetida com `access-2`, tokens novos salvos;
  - **duas requisições em paralelo com 401 → uma só chamada a `/auth/refresh`**;
  - refresh 401 → tokens apagados, `aoExpirarSessao` chamado uma vez;
  - 401 de `/auth/login` → nenhuma chamada a `/auth/refresh`;
  - `ErroApi.de` com 422 + `campos`, com 401 de login ("E-mail ou senha incorretos."), com `DioExceptionType.connectionError`.
- [ ] Manter o teste atual de dinheiro em `String`.
- [ ] Commit `feat: interceptor com Bearer e refresh em fila`.

### Tarefa 5: login e sessão

**Arquivos:** `features/login/data/auth_repositorio.dart`, `features/login/cubit/sessao_cubit.dart`, `features/login/cubit/login_cubit.dart`, `features/login/ui/login_tela.dart`, testes.

**Produz:**
- `abstract class AuthRepositorio { Future<void> entrar(String email, String senha); Future<void> sair(); Future<bool> temSessao(); }` + `AuthRepositorioApi`.
- `SessaoCubit` com estado freezed `SessaoEstado.verificando() | .desconectada({bool expirou}) | .conectada()`; métodos `iniciar()`, `entrou()`, `sair()`, `expirou()` (ligado ao `aoExpirarSessao` do interceptor).
- `LoginCubit` com estado freezed `LoginEstado({bool enviando, String? erro})`; `entrar(email, senha)` → `SessaoCubit.entrou()` no sucesso.
- `LoginTela`: textos do design ("Finanças pessoais", "Acesse suas finanças", "Entre com o e-mail e a senha do seu usuário.", "Entrar"/"Entrando", rodapé "Sem cadastro: o acesso é criado no servidor."), botão mostrar senha, aviso "Sessão expirada. Faça login de novo para continuar." quando `expirou`, caixa de erro "E-mail ou senha incorretos.".

- [ ] bloc_test: `SessaoCubit.iniciar` com e sem tokens; `expirou` → `desconectada(expirou: true)`; `LoginCubit` sucesso, 401, sem rede.
- [ ] Widget test: aviso de sessão expirada aparece; erro aparece; botão desabilitado com "Entrando" enquanto envia.
- [ ] Commit `feat: tela de login e sessão`.

### Tarefa 6: navegação, abas e placeholders

**Arquivos:** `app/app.dart`, `app/router.dart`, `app/injecao.dart`, `app/widgets/em_breve.dart`, `features/inicio/ui/inicio_tela.dart` (versão simples), `features/revisao/ui/revisao_tela.dart`, `features/configuracoes/ui/mais_tela.dart`, `main.dart`, testes.

**Rotas:** `/login`; abas `/inicio`, `/revisao`, `/transacoes`, `/mais`; `/mais/contas`, `/mais/contas/nova`, `/transacoes/nova`. `redirect`: `desconectada` → `/login`; `conectada` em `/login` → `/inicio`. `refreshListenable` a partir do stream do `SessaoCubit`.

- `MaisTela`: grupos Dinheiro (Contas → `/mais/contas`; Faturas, Investimentos "Em breve"), Dados (Importar extrato, Open Finance "Em breve"), Ajustes (Planejamento, Categorias e regras, Segurança "Em breve"); botão "Sair". Item "em breve" visível, subtítulo "Em breve", sem navegação.
- `RevisaoTela`: estado vazio "Revisão chega em breve" explicando que importações e Open Finance vão gerar rascunhos aqui.
- `injecao.dart`: `class Dependencias` criada em `main()` com storage, dio, interceptor, repositórios e `SessaoCubit`; entregue por `MultiRepositoryProvider`/`BlocProvider`.

- [ ] Widget test do app com repositórios fake: sem sessão abre o login; com sessão abre Início; tocar Mais → Contas abre Contas; "Sair" volta para o login.
- [ ] Commit `feat: navegação com abas e telas em breve`.

### Tarefa 7: contas e nova conta

**Arquivos:** `features/contas/data/conta.dart` (freezed `Conta`, `ResumoContas`, enum `TipoConta { corrente, cartaoCredito, carteira }`), `contas_repositorio.dart`, `cubit/contas_cubit.dart`, `cubit/nova_conta_cubit.dart`, `ui/contas_tela.dart`, `ui/nova_conta_tela.dart`, testes.

**Produz:**
- `abstract class ContasRepositorio { Future<ResumoContas> listar(); Future<Conta> criar(NovaConta dados); }`; `NovaConta(nome, tipo, instituicao?, saldoInicial: Decimal, dataSaldoInicial: DateTime)`. Conversão: `Decimal.parse(conta.saldoAtual)`, `Date` → `DateTime`, envio `saldoInicial.toStringAsFixed(2)`.
- `ContasCubit`: `ContasEstado.carregando() | .carregado(ResumoContas) | .erro(String)`; `carregar()`.
- `NovaContaCubit`: estado com `tipo`, `enviando`, `erros: Map<String,String>`, `salva: bool`; `salvar(...)` valida localmente (nome vazio "Dê um nome à conta, por exemplo: Conta principal.", instituição vazia na corrente "Informe a instituição da conta.", dinheiro via `validarDinheiro(aceitaNegativo: true)`, data futura "A data do saldo não pode ser depois de hoje.") e depois aplica `ErroApi.campos`.
- `ContasTela`: card "Total disponível" + texto do design, seção "Contas e carteira" (saldo negativo em `error` com "Saldo negativo"), seção "Cartões de crédito" com "Em breve", botão "Adicionar conta"; estado vazio "Nenhuma conta cadastrada"; erro com "Tentar de novo". Ao voltar de Nova conta salva, recarrega.
- `NovaContaTela`: chips Conta corrente / Carteira (dinheiro) (carteira esconde Instituição), Nome, Instituição, Saldo inicial (prefixo R$, ajuda "O saldo exato do extrato na data abaixo. Pode ser negativo."), Saldo em (hoje por padrão, ajuda do design), "Salvar conta".

- [ ] Testes do repositório com adaptador falso: `"1234.56"` → `Decimal.parse('1234.56')`; envio com `saldo_inicial: "-120.40"` e carteira sem `instituicao`.
- [ ] bloc_test dos dois cubits (inclui erro 422 do servidor no campo `data_saldo_inicial`).
- [ ] Widget tests: lista com total formatado; vazio; erro de validação embaixo do campo.
- [ ] Commit `feat: telas de contas e nova conta`.

### Tarefa 8: transações e lançamento

**Arquivos:** `features/transacoes/data/transacao.dart` (freezed `Transacao`, enum `TipoTransacao` com `bool get entrada`, `StatusTransacao`), `transacoes_repositorio.dart`, `cubit/transacoes_cubit.dart`, `cubit/lancamento_cubit.dart`, `ui/transacoes_tela.dart`, `ui/lancamento_tela.dart`, testes.

**Produz:**
- `abstract class TransacoesRepositorio { Future<List<Transacao>> listar({String? contaId, required DateTime de, required DateTime ate}); Future<Transacao> lancar(NovoLancamento dados); }`.
- `TransacoesCubit(transacoes, contas, hoje)`: estado com `mes` (primeiro dia), `contaId?`, `contas` (para os chips), `dias: List<DiaDeTransacoes>` (agrupado por data, mais recente primeiro, sem `ignorada`), `carregando`, `erro`; métodos `carregar()`, `mesAnterior()`, `proximoMes()` (não passa do mês atual), `filtrar(String? contaId)`.
- `LancamentoCubit`: tipo `despesa`/`receita`, validação local ("Escolha uma conta.", "Informe um valor maior que zero.", "Descreva a transação, por exemplo: Mercado.") + `ErroApi.campos`.
- `TransacoesTela`: cabeçalho do mês com setas, chips "Todas" + contas, listas por dia (`Hoje · 20 out`), valor `− R$`/`+ R$` em `despesa`/`receita` (outros tipos neutros, sem sinal), chip "Rascunho", vazio "Nenhuma transação em <mês>" com "Lançar transação", botão "Lançar" → `/transacoes/nova`; recarrega ao voltar com lançamento salvo.
- `LancamentoTela` ("Nova transação"): Conta (lista de contas ativas corrente/carteira), Tipo (Despesa, Receita; Transferência e Pagamento de fatura desabilitados com "Em breve"), Valor (ajuda "Sempre positivo; o tipo define se entra ou sai."), Data (hoje), Descrição, Categoria (desabilitada, "Em breve"), "Salvar".

- [ ] Testes: repositório envia `de`/`ate` do mês e converte `valor`; cubit agrupa por dia, esconde `ignorada`, bloqueia mês futuro, filtro por conta; lançamento com erros locais e do servidor.
- [ ] Widget tests: lista agrupada com sinais e cores; vazio do mês; chips desabilitados no lançamento.
- [ ] Commit `feat: telas de transações e lançamento`.

### Tarefa 9: Início (placeholder)

**Arquivos:** `features/inicio/ui/inicio_tela.dart`, `features/inicio/cubit/inicio_cubit.dart` (ou reuso do `ContasCubit`), teste.

- Cabeçalho com a data longa (`Terça, 20 de outubro`) e "Início"; card "Saldo disponível" (total do `GET /contas`, texto "Contas correntes e carteira."); card "Aporte e alerta chegam em breve" explicando que o app vai calcular quanto aportar no salário e avisar se o ritmo de gastos ameaça a reserva.
- [ ] Widget test: total formatado e card em breve.
- [ ] Commit `feat: início com saldo disponível e aviso em breve`.

### Tarefa 10: documentação

**Arquivos:** `docs/explicacoes/05-widgets-flutter.md`, `06-cubit-estado.md`, `07-build-runner-freezed.md`; `CLAUDE.md` (Setup do app: `dart run build_runner build` em `app/` agora é necessário; `.freezed.dart` fora do git; seção App), `docs/arquitetura.md` §8 se a estrutura mudar.

- 05: widget, `build`, Stateless × Stateful ↔ componentes do React Native; árvore e `BuildContext`.
- 06: Cubit ↔ `useState` + Context; `BlocProvider`/`BlocBuilder`/`BlocListener`; por que estado imutável.
- 07: freezed ↔ codegen do RN/TypeScript; `copyWith`, igualdade, união selada (`when`/`switch`); `.freezed.dart` fora do git.
- [ ] Commit `docs: notas de Flutter (widgets, Cubit, freezed) e setup do app`.

### Tarefa 11: verificação ponta a ponta e PR

- [ ] Backend local (`docker compose up -d db`, `uv run alembic upgrade head`, `uv run fastapi dev`), usuário fictício criado com `criar_usuario`.
- [ ] `flutter run --dart-define=API_URL=http://10.0.2.2:8000` (emulador) ou IP da máquina (aparelho): login → Mais → Contas → Nova conta → Transações → Lançar → lista; claro e escuro; derrubar a API e ver o erro; apagar o refresh no banco e ver "Sessão expirada".
- [ ] Revisão do diff (engineering:code-review), `flutter analyze`, `flutter test`.
- [ ] Push, PR para a `main`, checks `backend` e `app` verdes; card do Trello em "Em revisão (PR)" com o link.
