# Finanças pessoais

App Android (Flutter) + API (FastAPI) de controle financeiro pessoal, com usuário único. Projeto de portfólio com uso real — responde "quanto posso aportar no próximo salário e se o ritmo de gastos ameaça a reserva".

A referência técnica é [`docs/arquitetura.md`](docs/arquitetura.md): fontes de dados, Pluggy, stack, armadilhas do domínio, modelo de dados completo e estrutura de pastas. **Leia antes de qualquer tarefa.**

Instruções pessoais (modo de trabalho, prazo, cronograma) ficam em `CLAUDE.local.md`, fora do git.

| Parte | Stack | Dev URL | Diretório |
|---|---|---|---|
| App | Flutter (Android) | emulador / aparelho | `app/` |
| API | FastAPI + SQLAlchemy 2.0 + Alembic | http://localhost:8000 (docs em `/docs`) | `backend/` |
| Banco | PostgreSQL 16 | `localhost:5432` (só em dev) | `docker-compose.yml` |
| Jobs | scripts Python chamados por cron | — | `backend/app/jobs/` |

## Como trabalhar

1. **Passos pequenos**, um assunto por vez, sempre com teste.
2. **Decisão de arquitetura** vira spec em `docs/superpowers/specs/` antes de implementar; plano derivado em `docs/superpowers/plans/`.
3. **Conceito importante** vira nota curta em `docs/explicacoes/NN-tema.md`.
4. **Pergunte antes** de adicionar dependência nova ou de sair do escopo do passo.

## Stack

- **Backend:** Python 3.12, FastAPI **síncrono** (rotas `def`, `Session`), Pydantic v2 (+ pydantic-settings), SQLAlchemy 2.0 (estilo tipado, `Mapped[]`), Alembic, psycopg 3, argon2 (senha), PyJWT, httpx (`httpx.Client` para Pluggy e BCB), holidays (feriados nacionais).
- **App:** Flutter estável / Dart 3, go_router, flutter_bloc (Cubit), dio, freezed + json_serializable, `decimal`, drift (cache de leitura), fl_chart, local_auth, flutter_secure_storage, flutter_local_notifications.
- **Contrato:** cliente Dart **gerado** do OpenAPI do FastAPI (openapi-generator, alvo `dart-dio`, serialização `built_value`) em `app/packages/api_client/`.
- **Banco:** PostgreSQL 16.
- **Ferramentas:** uv (dependências Python), ruff (lint/format), pytest + httpx + testcontainers.
- **Deploy:** VPS acessível só pela Tailscale, Docker Compose puro (`api`, `db`, `jobs`), GitHub Actions → Tailscale → ssh → `docker compose up -d`. Backup diário criptografado (restic → Backblaze B2). APK assinado gerado pelo CI em tag. Ver `docs/superpowers/specs/2026-10-19-hospedagem-deploy-design.md`.

## Setup & commands

> Comandos previstos; ajuste quando o setup real divergir e mantenha esta seção correta — é a mais consultada.

### Pré-requisitos da máquina

- **Docker** (Desktop no Windows) com Compose.
- **uv** — baixa sozinho o Python 3.12 fixado no projeto; ruff entra como dependência de dev.
- **JDK 17+** em `JAVA_HOME` (Gradle do Android e openapi-generator).
- **Flutter** canal stable, com `flutter/bin` no `PATH`.
- **Android SDK sem Android Studio:** command-line tools em `$ANDROID_HOME/cmdline-tools/latest`, mais `platform-tools`, `platforms;android-36` e `build-tools;36.0.0` via `sdkmanager`. Licenças: `flutter doctor --android-licenses`. O aviso do `sdkmanager` sugerindo o novo Android CLI pode ser ignorado: o Flutter ainda chama o `sdkmanager` diretamente.
- Aparelho físico com depuração USB (ou Wi-Fi) é o alvo principal; emulador é opcional (`sdkmanager "emulator" "system-images;..."` + `avdmanager`).
- **Tailscale** no PC e no celular: a API de produção só é alcançável pela tailnet.

### Banco (Docker)

```bash
docker compose up -d db          # sobe só o Postgres
docker compose down              # para (NUNCA use -v: apaga os dados)
```

### Backend

```bash
cd backend
uv sync                                           # instala dependências (lock)
uv run alembic upgrade head                       # aplica migrations
uv run fastapi dev app/main.py                    # API com hot reload em :8000
uv run python -m app.criar_usuario                # cria o usuário único (pede e-mail e senha)
uv run python -m app.seed                         # dados FICTÍCIOS (modo demo, banco local separado)
```

Migrations:

```bash
uv run alembic revision --autogenerate -m "descricao"   # revise o arquivo gerado antes de aplicar
uv run alembic upgrade head
uv run alembic downgrade -1
```

Jobs (o cron de produção chama os mesmos comandos):

```bash
uv run python -m app.jobs.sync_pluggy
uv run python -m app.jobs.atualizar_cdi
```

### Cliente da API (sempre que um endpoint ou schema mudar)

```bash
bash scripts/gerar-cliente-api.sh   # exporta openapi.json da API e regera app/packages/api_client/
```

### App

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed / json_serializable / drift
flutter run --dart-define=API_URL=http://10.0.2.2:8000      # emulador Android
flutter build apk --release --dart-define=API_URL=<url de produção>
```

### Testes e lint

```bash
cd backend && uv run pytest                                  # precisa do Docker (testcontainers)
cd backend && uv run ruff check . && uv run ruff format --check .
cd app && flutter analyze && flutter test
```

## Conventions

- **Idioma:** documentação, comentários, commits e textos de interface em **pt-BR**. Identificadores do domínio em português **sem acento** (`fatura`, `competencia`, `transacao`); código de infraestrutura pode seguir a convenção das bibliotecas (inglês).
- **Dinheiro nunca é float.** `Decimal` no Python, `NUMERIC(14,2)` no Postgres, **string** no JSON (`"1234.56"`), pacote `decimal` no Dart. Formatação `R$ 1.234,56` só na camada de UI (`app/lib/core/formatacao/`).
- **Valor sempre positivo;** o sentido vem de `transacao.tipo`.
- **Datas:** `date` para datas de negócio (compra, competência, vencimento); `timestamptz` só para auditoria (`criado_em`, `atualizado_em`, sync). Fuso de referência: `America/Fortaleza`.
- **Enums** como `text` + `CHECK` no banco (não enum nativo do Postgres) e `StrEnum` no Python.
- **Ids:** UUID em todas as tabelas; rotas validam o id pelo tipo (`uuid.UUID` no parâmetro) — id malformado é 422, nunca 500.
- **Erros da API:** `HTTPException` com `detail` em pt-BR; manter um formato único definido em `app/core/erros.py`.
- **Dependências Python** via `uv add` (dev: `uv add --dev`); `uv.lock` versionado; CI instala com `--locked`.
- **Commits:** `feat:` / `fix:` / `test:` / `chore:` / `docs:`, em passos pequenos, teste junto com a mudança.

## Architecture

### Backend — `router → service → banco`

Organizado **por módulo de domínio**, não por camada: `backend/app/modulos/<modulo>/` com `models.py` (tabelas), `schemas.py` (entrada/saída Pydantic), `service.py` (regras de negócio) e `router.py` (HTTP). Routers só traduzem HTTP; toda regra fica no service.

- `app/main.py` — cria a app e registra os routers. **Router novo precisa ser incluído aqui.**
- `app/core/` — `config.py` (pydantic-settings lê o `.env`), `db.py` (engine, sessão, `Base`), `seguranca.py` (hash, JWT), `deps.py` (dependências: sessão, usuário logado), `dinheiro.py` (tipo `Dinheiro`, usado em **todo** campo monetário de schema), `erros.py`.
- `app/modulos/` — `auth`, `contas`, `cartoes`, `transacoes`, `categorias`, `importacao` (com `parsers/`), `planejamento`, `investimentos`, `indices`, `pluggy`, `relatorios`.
- `app/modulos/planejamento/calculo.py` — **funções puras** (sem banco, sem I/O): aporte do dia de salário, meses de reserva, alerta de ritmo. É a regra mais importante do app; cobertura de teste completa.
- `app/jobs/` — scripts do cron; reutilizam os services, não duplicam lógica.

### App — `features/` espelha `modulos/`

- `lib/app/` — `router.dart` (go_router), `tema.dart`, `injecao.dart` (cria repositórios e cubits).
- `lib/core/api/` — configura o dio: injeta o access token, faz refresh em 401 e repete a requisição. **É o único lugar que fala com a API.**
- `lib/core/auth/` — tokens no flutter_secure_storage, desbloqueio por biometria.
- `lib/core/cache/` — drift, só leitura offline; o servidor é a fonte da verdade.
- `lib/features/<feature>/` — `data/` (repositório que usa o cliente gerado e converte seus modelos `built_value` em modelos `freezed` do app, `String` monetária → `Decimal`), `cubit/` (estado), `ui/` (telas e widgets). Telas e cubits nunca importam tipos do cliente gerado.
- Features: `login`, `inicio` (aporte, reserva, alerta), `revisao` (rascunhos para confirmar), `transacoes`, `contas`, `faturas`, `importacao`, `investimentos`, `configuracoes`.

### Autenticação

Bearer, sem cookie e sem CSRF (cliente é um app nativo, não um navegador).

1. `POST /auth/login` devolve access (15 min) + refresh (30 dias) no corpo.
2. O app guarda os dois no flutter_secure_storage; o dio envia `Authorization: Bearer`.
3. Em 401, o dio chama `POST /auth/refresh` e repete a requisição.
4. **Refresh com rotação:** cada uso revoga o anterior (`refresh_token.revogado_em`); o banco guarda só o hash. Reuso de token revogado derruba todas as sessões.
5. Biometria (local_auth) só desbloqueia o app; não substitui o login.

### Fontes de dados

Manual, importação OFX/CSV e Open Finance via Pluggy. Tudo que não é manual entra como **rascunho** e é confirmado na tela de revisão.

- **Formatos:** Nubank (conta e cartão) só por **OFX**; Mercado Pago por **CSV** (não exporta OFX). Não há parser de CSV do Nubank.
- **Idempotência:** unique `(conta_id, fonte, id_externo)`. `id_externo` = FITID (OFX; a linha de IOF usa `FITID:iof`, porque compra e IOF compartilham o FITID no Nubank), id da Pluggy, ou identificador/hash para o CSV do Mercado Pago. FITID ainda repetido no arquivo = erro explícito, nunca descarte silencioso. `importacao.hash_arquivo` impede reimportar o mesmo arquivo.
- **Mesma transação por fontes diferentes** (CSV e Pluggy): não fundir automaticamente; preencher `possivel_duplicata_de` e decidir na revisão.
- **Não contam como gasto:** `pagamento_fatura` e transferências entre contas próprias (`transferencia_par_id`).
- **Cartão:** toda transação de conta `cartao_credito` tem `fatura_id`. Data da compra ≠ competência da fatura ≠ data do pagamento. Compra parcelada = `compra_parcelada` + uma transação por parcela, cada uma na sua fatura; o app só gera parcelas no lançamento manual — das fontes, chegam as que a Pluggy/OFX enviam.

### Pluggy (Open Finance)

- **Consulte o MCP `pluggy-docs` antes de escrever ou alterar código de integração.** Não confie em memória sobre a API. Se não estiver configurado: `claude mcp add --transport http pluggy-docs https://mcp.pluggy.ai/mcp`.
- Conector **MeuPluggy**, item **proxy**: espelha o item do Meu Pluggy (atualizado a cada 24h) e **não pode ser atualizado via API**. Atraso de ~24h é aceito.
- **Sem webhook:** `jobs/sync_pluggy.py` roda uma vez por dia e relê uma **janela de 40 dias** por conta via **`GET /v2/transactions`** (o v1 `GET /transactions` some após 2026-12-31).
- Cada atualização traz **sobreposição de 4 dias** → deduplicar pelo id da Pluggy. **Não há id estável** (sem `providerId`): transação da janela que sumiu da API é removida se rascunho, ou marcada `removida_na_origem_em` se confirmada.
- **`date` vem em UTC com horário** → converter para `America/Fortaleza` antes de truncar. No cartão o sinal de `amount` é o inverso da conta; use `type`.
- Uso pessoal: autorização de 1 ano, renovada à mão; a renovação pode gerar **itemId novo**, religado à conexão existente. Detalhes na spec `2026-10-19-pluggy-spike-design.md`.
- `GET /items/{id}/resources` diz o que o banco realmente compartilhou; consentimento tem validade — o app avisa antes de expirar (`conexao_pluggy.consentimento_expira_em`).
- **Somente leitura.** Cliente em `modulos/pluggy/client.py` expõe só métodos GET (além do `/auth`).

## Environment Variables

**Backend** (`backend/.env`, ver `.env.example`):

```
DATABASE_URL=postgresql+psycopg://financas:<senha>@localhost:5432/financas
JWT_SECRET=...                     # 32+ caracteres
ACCESS_TOKEN_MINUTOS=15
REFRESH_TOKEN_DIAS=30
PLUGGY_CLIENT_ID=...
PLUGGY_CLIENT_SECRET=...
TZ_NEGOCIO=America/Fortaleza
```

**Compose** (`.env` na raiz): `POSTGRES_PASSWORD` obrigatório.

**App:** só `--dart-define=API_URL=...` no build (em release, o endereço `https://...ts.net` da VPS). **Nenhum segredo no APK** — chave da Pluggy fica exclusivamente no backend.

**Produção:** o `.env` real fica só na VPS. Segredos do deploy (OAuth client da Tailscale, chave ssh, keystore do APK, credenciais do B2/restic) ficam nos secrets do GitHub ou na VPS, nunca no repositório.

Nunca commitar segredos nem colar credenciais em specs, planos ou notas.

## Testing & CI

- **Backend:** pytest contra **Postgres real** via testcontainers, nunca SQLite — `NUMERIC` e `CHECK` precisam se comportar como em produção. Fixtures em `backend/tests/conftest.py`.
  - `tests/unit/` — `calculo.py`, parsers, datas de fatura/feriado. Sem banco, rápidos.
  - `tests/integration/` — endpoints via `TestClient` com banco real e transação revertida por teste.
  - `tests/fixtures/` — OFX/CSV **fictícios**. Nunca extratos reais.
  - Pluggy é mockado nos testes (respx ou cliente fake); nenhum teste chama a API real.
- **App:** `flutter test` para cubits (bloc_test) e formatação de dinheiro; widget tests nas telas de início e revisão.
- **Testes herméticos:** não dependem de `.env` local nem de banco pré-populado.
- **CI** (`.github/workflows/`): `backend.yml` (ruff + pytest via uv `--locked`) e `app.yml` (build_runner + flutter analyze + flutter test); em tag `v*`, gera o APK assinado e anexa ao release.
- **Ruleset na `main`:** mudança só via PR, com os checks `backend` e `app` obrigatórios e sem exigir aprovação (projeto solo: o CI é o revisor obrigatório).

## Design

As telas são desenhadas no **Claude Design** antes de implementadas, sempre com **dados fictícios**. Cores, tipografia e espaçamentos viram tokens em `app/lib/app/tema.dart`; as telas viram widgets em `features/<feature>/ui/`. Os links dos designs ficam no `CLAUDE.local.md`.

## Documentation Map

| Onde | O quê |
|---|---|
| `docs/arquitetura.md` | Ponto de partida: fontes, Pluggy, stack, armadilhas, modelo de dados, pastas |
| `docs/briefing.md` | **Local, fora do git:** renda, contas, regras de aporte com valores reais, cronograma |
| `docs/superpowers/specs/` | Decisões e motivos, escritas antes de implementar |
| `docs/superpowers/plans/` | Planos passo a passo derivados de uma spec |
| `docs/explicacoes/` | Notas de aprendizado (FastAPI, Flutter, conceitos do domínio) |
| `docs/agents/` | Configuração dos skills de engenharia: issue tracker, labels de triagem, docs de domínio |
| `README.md` | Vitrine do portfólio: prints do modo demo, arquitetura, como rodar |

Nomes: `YYYY-MM-DD-<tema>-design.md` (specs), `YYYY-MM-DD-<tema>.md` (planos), `NN-<tema>.md` (explicações).

Specs já decididas (2026-10-19): hospedagem e deploy; cálculo de aporte e alerta; dinheiro no contrato da API; backend síncrono e usuário único; revisão e classificação; spike da Pluggy (sync, reconciliação, cartão, investimentos). Prevista: deduplicação entre fontes.

## Do / Don't

- **Do:** colocar regra de negócio no service e cálculo de planejamento em `calculo.py`.
- **Do:** regerar o cliente Dart e rodar `flutter analyze` depois de mudar endpoint ou schema.
- **Do:** manter `docs/arquitetura.md` e este arquivo em dia quando uma decisão mudar.
- **Do:** manter valores pessoais (renda, saldos, datas de cartão, metas) só em `docs/briefing.md` e `CLAUDE.local.md`; no repositório entram como exemplos fictícios.
- **Do:** usar dados fictícios em seed, testes, prints e README.
- **Don't:** editar `app/packages/api_client/` à mão — é gerado.
- **Don't:** usar `float`/`double` para dinheiro, nem somar valores com sinal misturado.
- **Don't:** implementar qualquer endpoint de escrita ou pagamento da Pluggy.
- **Don't:** colocar segredo no APK, no repositório ou em logs.
- **Don't:** fora do escopo — leitura de notificações do Android, renda variável/B3, multiusuário.

## Gotchas

**Pydantic v2 serializa `Decimal` como string no JSON, mas o schema de entrada vira `number | string`.** Isso duplica schemas (`XInput`/`XOutput`) no OpenAPI e gera tipo genérico no Dart. Use sempre o tipo `Dinheiro` de `core/dinheiro.py`, que fixa `string`/`decimal` nos dois sentidos; nunca `Decimal` direto num schema, nunca `float`. No Dart, o cliente gerado recebe `String` — converta para `Decimal` no repositório, nunca para `double`.

**Alembic autogenerate não enxerga tudo.** Mudanças em `CHECK` constraints (nossos enums) e em alguns defaults de servidor não são detectadas. Revise todo arquivo gerado e escreva à mão o que faltar.

**Emulador Android não enxerga `localhost` do PC.** Use `http://10.0.2.2:8000`. Em aparelho físico, use o IP da máquina na rede ou o endereço da Tailscale. Android bloqueia HTTP sem TLS por padrão em release — só HTTPS fora do debug.

**`build_runner` precisa rodar de novo** depois de mudar classes freezed, json_serializable ou tabelas drift; erro de "part file not found" quase sempre é isso.

**Vencimento e fechamento caem em feriado/fim de semana.** Sempre calcular pela tabela `feriado` + regra do cartão; nunca assumir o dia fixo.

**Pluggy proxy não aceita refresh.** Chamar update num item MeuPluggy falha por desenho; o dado chega em até 24h. Não "conserte" isso com polling agressivo.

**Snapshot de 31/12 precisa existir.** O IR usa os saldos dessa data e não dá para reconstruí-los depois com precisão; a funcionalidade de snapshot tem que estar em produção antes do fim do ano.

## Agent skills

### Issue tracker

Issues no GitHub do repositório, via `gh`. O Trello fica só como visão do cronograma por semana. Ver `docs/agents/issue-tracker.md`.

### Triage labels

Os cinco papéis padrão, com label de mesmo nome (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). Ver `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `docs/arquitetura.md` + `CONTEXT.md` na raiz (criado quando necessário); decisões em `docs/superpowers/specs/`, sem `docs/adr/`. Ver `docs/agents/domain.md`.

## Pull Request Workflow

O repositório tem "Automatically delete head branches" ativado.

1. Branch a partir de `main` atualizada: `git checkout main && git pull && git checkout -b feat/<nome>`
2. Commits pequenos (`feat:` / `fix:` / `test:` / `chore:` / `docs:`), testes junto.
3. `git push -u origin feat/<nome>` → abrir o PR pelo link que o GitHub mostra.
4. CI roda sozinho; se falhar, corrigir e dar push na mesma branch.
5. **Merge pelo botão do GitHub** (é o que apaga a branch automaticamente).
6. Local: `git checkout main && git pull && git fetch --prune && git branch -d feat/<nome>`
