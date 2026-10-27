# Finanças pessoais

App Android (Flutter) + API (FastAPI) de controle financeiro pessoal, com usuário único. Projeto de portfólio com uso real — responde "quanto posso aportar no próximo salário e se o ritmo de gastos ameaça a reserva".

A referência técnica é [`docs/arquitetura.md`](docs/arquitetura.md): fontes de dados, Pluggy, stack, armadilhas do domínio, modelo de dados completo e estrutura de pastas. **Leia antes de qualquer tarefa.**

Instruções pessoais (modo de trabalho, prazo, cronograma) ficam em `CLAUDE.local.md`, fora do git.

| Parte | Stack | Dev URL | Diretório |
|---|---|---|---|
| App | Flutter (Android) | emulador / aparelho | `app/` |
| API | FastAPI + SQLAlchemy 2.0 + Alembic | http://localhost:8000 (docs em `/docs`) | `backend/` |
| Banco | PostgreSQL 16 | `127.0.0.1:5432` (só em dev) | `docker-compose.yml` |
| Jobs | scripts Python chamados por cron | — | `backend/app/jobs/` |

## Como trabalhar

1. **Passos pequenos**, um assunto por vez, sempre com teste.
2. **Decisão de arquitetura** vira spec em `docs/superpowers/specs/` antes de implementar; plano derivado em `docs/superpowers/plans/`.
3. **Conceito importante** vira nota curta em `docs/explicacoes/NN-tema.md`, pessoal e fora do git (`.gitignore`): o repositório é público.
4. **Pergunte antes** de adicionar dependência nova ou de sair do escopo do passo.

## Stack

- **Backend:** Python 3.12, FastAPI **síncrono** (rotas `def`, `Session`), Pydantic v2 (+ pydantic-settings), SQLAlchemy 2.0 (estilo tipado, `Mapped[]`), Alembic, psycopg 3, argon2 (senha), PyJWT, httpx (`httpx.Client` para Pluggy e BCB), holidays (feriados nacionais).
- **App:** Flutter estável / Dart 3, go_router, flutter_bloc (Cubit), dio, freezed (json_serializable quando o app tiver JSON próprio), `decimal`, drift (cache de leitura), fl_chart, local_auth, flutter_secure_storage, flutter_local_notifications.
- **Contrato:** cliente Dart **gerado** do OpenAPI do FastAPI (openapi-generator 7.26.0 via Docker, alvo `dart-dio`, serialização `built_value`, `decimal=String`) em `app/packages/api_client/`. O FastAPI publica operationId `<tag>_<função>` e o gerador corta a tag (`removeOperationIdPrefix`): `contas_listar` vira `ContasApi.listar()`. Por isso cada rota tem **uma tag só, sem `_`** (teste em `tests/unit/test_operation_ids.py`).
- **Banco:** PostgreSQL 16.
- **Ferramentas:** uv (dependências Python), ruff (lint/format), pytest + httpx + testcontainers.
- **Deploy:** Locaweb VPS de 1 GB acessível só pela Tailscale, Docker Compose puro (`api`, `db`; `jobs` quando os jobs entrarem). A cada push na `main`: imagem no GHCR → `deploy.yml` entra na tailnet por OIDC → scp + Tailscale SSH → `deploy/implantar.sh` (pull da `sha-<7>`, migrations, `up -d --wait`). Backup diário criptografado (restic → Backblaze B2, systemd timer na VPS). APK assinado gerado pelo CI em tag. Ver `docs/superpowers/specs/2026-10-19-hospedagem-deploy-design.md`.

## Setup & commands

> Comandos previstos; ajuste quando o setup real divergir e mantenha esta seção correta — é a mais consultada.

### Pré-requisitos da máquina

- **Docker** (Desktop no Windows) com Compose; também roda o openapi-generator.
- **uv** — baixa sozinho o Python 3.12 fixado no projeto; ruff entra como dependência de dev.
- **JDK 17+** em `JAVA_HOME` (Gradle do Android).
- **Flutter** canal stable, com `flutter/bin` no `PATH`.
- **Android SDK sem Android Studio:** command-line tools em `$ANDROID_HOME/cmdline-tools/latest`, mais `platform-tools`, `platforms;android-36` e `build-tools;36.0.0` via `sdkmanager`. Licenças: `flutter doctor --android-licenses`. O aviso do `sdkmanager` sugerindo o novo Android CLI pode ser ignorado: o Flutter ainda chama o `sdkmanager` diretamente.
- Aparelho físico com depuração USB (ou Wi-Fi) é o alvo principal; emulador é opcional (`sdkmanager "emulator" "system-images;..."` + `avdmanager`).
- **Tailscale** no PC e no celular: a API de produção só é alcançável pela tailnet.

### Banco (Docker)

```bash
cp .env.example .env             # 1ª vez: defina POSTGRES_PASSWORD
docker compose up -d db          # sobe só o Postgres
docker compose down              # para (NUNCA use -v: apaga os dados)
```

### Backend

```bash
cd backend
cp .env.example .env                              # 1ª vez: DATABASE_URL (senha do compose) e JWT_SECRET
uv sync                                           # instala o Python 3.12 e as dependências (lock)
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

Precisa de uv, Docker rodando e Dart. Não sobe a API nem lê o `backend/.env`. Commite o resultado (inclusive o `openapi.json`, que mostra a mudança de contrato no PR); os `.g.dart` ficam fora do git.

### App

```bash
cd app/packages/api_client
dart pub get && dart run build_runner build                  # .g.dart do cliente gerado (1ª vez e após regerar)
cd ../..                                                     # volta para app/
flutter pub get
dart run build_runner build                                  # .freezed.dart dos modelos e estados do app
flutter run --dart-define=API_URL=http://10.0.2.2:8000      # emulador Android (sem API_URL o app não abre)
flutter build apk --release --dart-define=API_URL=<url de produção>
```

### Testes e lint

```bash
cd backend && uv run pytest                                  # precisa do Docker (testcontainers)
cd backend && uv run ruff check . && uv run ruff format --check .
cd app && flutter analyze && flutter test
```

### Produção (VPS)

A imagem da API (`backend/Dockerfile`, amd64 e arm64) é publicada em `ghcr.io/yagooliveira852/financetracker-api` pelo workflow `imagem.yml` a cada push na `main`, com as tags `latest` e `sha-<7 caracteres>`. Quando ele termina, o `deploy.yml` implanta essa versão sozinho. Decisões e motivos na spec `2026-10-19-hospedagem-deploy-design.md`.

**Deploy** (do PC, com o `gh`):

```bash
gh run list --workflow deploy --limit 5                 # últimos deploys (o automático roda após o imagem)
gh workflow run deploy                                  # reimplanta o commit atual da main
gh workflow run deploy -f tag=sha-1a2b3c4               # volta para uma versão anterior (rollback)
gh run watch                                            # acompanha o deploy em andamento
```

**Acesso:** só com a Tailscale ligada no PC; o IP público não aceita conexão. O ssh passa pela Tailscale SSH (a política da tailnet autoriza o usuário `deploy`, em modo *check*: de vez em quando pede confirmação no navegador). Emergência: console web do painel da Locaweb.

```bash
ssh deploy@<maquina>.<tailnet>.ts.net                   # nome real em CLAUDE.local.md / memória
curl https://<maquina>.<tailnet>.ts.net/saude           # {"status":"ok"}, do PC ou do celular na tailnet
```

**No servidor**, em `/opt/financas`: `compose.prod.yml`, `implantar.sh`, `backup.sh`, `testar-restauracao.sh` e os units `financas-backup.{service,timer}` (copiados pelo deploy), `.env` (segredos, permissão 600), `restic.env` (segredos do backup, permissão 600, lido só pelo container `restic`) e `versao.env` (`TAG=sha-<7>` da versão no ar, gravado pelo `implantar.sh`). Todo comando do compose leva os dois arquivos de ambiente; sem o `versao.env`, um `up -d` trocaria a imagem pela `latest`:

```bash
cd /opt/financas
alias dc='docker compose -f compose.prod.yml --env-file .env --env-file versao.env'
dc ps                                                   # estado e healthcheck
dc logs -f api
dc exec db psql -U financas -d financas                 # console do banco
bash implantar.sh sha-1a2b3c4                           # o mesmo que o deploy faz (pull, migrations, up --wait)
dc down                                                 # para (NUNCA use -v: apaga os dados)
```

**Backup** (restic → Backblaze B2, todo dia às 03:30 pelo `financas-backup.timer`; retenção de 30 dias; alerta pelo healthchecks.io). Preparação, restauração e o caso da VPS perdida em [`docs/runbooks/backup-restauracao.md`](docs/runbooks/backup-restauracao.md):

```bash
systemctl list-timers financas-backup.timer             # última e próxima execução
sudo journalctl -u financas-backup --since yesterday    # saída do último backup
sudo systemctl start financas-backup                    # backup agora (antes de algo arriscado)
dc run --rm restic snapshots                            # o restic roda no container do profile backup
sudo systemctl start financas-backup && bash testar-restauracao.sh   # restaura num Postgres temporário e compara
```

**Preparação do servidor** (feita uma vez, à mão, em 23/10/2026; refazer só ao trocar de VPS). Ubuntu 24.04:

1. Usuário `deploy` com sudo sem senha (`/etc/sudoers.d/deploy`) e no grupo `docker`; `/etc/ssh/sshd_config.d/00-financas.conf` com `PermitRootLogin no`, `PasswordAuthentication no` e `KbdInteractiveAuthentication no`.
2. Docker Engine + Compose (repositório oficial da Docker); logs do Docker limitados em `/etc/docker/daemon.json` (`json-file`, `max-size 10m`, `max-file 3`) e do journald em 100 MB (`SystemMaxUse=100M`).
3. Swap de 2 GB (a partição de 1 GB da imagem + `/swapfile` de 1 GB no `/etc/fstab`) com `vm.swappiness=10`.
4. Tailscale: `tailscale up --ssh --hostname=<maquina>`; no painel, a máquina recebe `tag:server`. `tailscale serve --bg 8000` publica a api em HTTPS só na tailnet.
5. Firewall: `ufw default deny incoming`, `ufw allow in on tailscale0 to any port 22 proto tcp`, `ufw enable`. A api escuta só em `127.0.0.1:8000` porque o Docker publica portas por fora do `ufw`.
6. `/opt/financas` do usuário `deploy`; `.env` copiado de `deploy/.env.example` com os segredos gerados **ali mesmo** (`python3 -c "import secrets; ..."`, comandos no próprio arquivo) e `chmod 600 .env`.
7. Primeiro deploy pelo `gh workflow run deploy` (aplica as migrations); depois `dc run --rm api python -m app.criar_usuario` para criar o usuário.
8. Backup: bucket e application key no B2, check no healthchecks.io, `restic.env` com a senha do restic gerada ali (e copiada para o gerenciador de senhas), `dc run --rm restic init` e os units em `/etc/systemd/system/` (runbook, "Preparação"). Ao trocar de VPS, restaurar o banco em vez de criar o usuário (runbook, "Desastre").

**Tailscale e GitHub** (painel, uma vez): política da tailnet com `tagOwners` (`tag:ci`, `tag:server`), grant `tag:ci` → `tag:server` em `tcp:22` e `tcp:443`, regra de ssh `tag:ci` → `tag:server` como `deploy`, e `tests`/`sshTests` que conferem isso. Credencial OIDC em Settings → Trust credentials (issuer GitHub, subject `repo:<dono>@<id>/<repo>@<id>:environment:producao`, scope Auth Keys de escrita, `tag:ci`). No GitHub, environment `producao` restrito à `main`, com os secrets `TS_OAUTH_CLIENT_ID`, `TS_AUDIENCE` e `VPS_HOST`.

Build local da imagem (para testar o compose com ela, `TAG=local` no ambiente do comando; a porta 8000 é a mesma do `fastapi dev`):

```bash
docker buildx build --platform linux/amd64 --load -t ghcr.io/yagooliveira852/financetracker-api:local backend
docker buildx build --platform linux/arm64 backend                    # só confere o arm64 (emulado, mais lento)
```

## Conventions

- **Idioma:** documentação, comentários, commits e textos de interface em **pt-BR**. Identificadores do domínio em português **sem acento** (`fatura`, `competencia`, `transacao`); código de infraestrutura pode seguir a convenção das bibliotecas (inglês).
- **Dinheiro nunca é float.** `Decimal` no Python, `NUMERIC(14,2)` no Postgres, **string** no JSON (`"1234.56"`), pacote `decimal` no Dart. Formatação `R$ 1.234,56` só na camada de UI (`app/lib/core/formatacao/`).
- **Valor sempre positivo;** o sentido vem de `transacao.tipo`.
- **Datas:** `date` para datas de negócio (compra, competência, vencimento); `timestamptz` só para auditoria (`criado_em`, `atualizado_em`, sync). Fuso de referência: `America/Fortaleza`.
- **Enums** como `text` + `CHECK` no banco (não enum nativo do Postgres) e `StrEnum` no Python.
- **Ids:** UUID em todas as tabelas; rotas validam o id pelo tipo (`uuid.UUID` no parâmetro) — id malformado é 422, nunca 500.
- **Erros da API:** `HTTPException` com `detail` em pt-BR; manter um formato único definido em `app/core/erros.py`. Regra de negócio que recusa um campo do corpo: o service levanta `CampoInvalido("campo", "mensagem")`, que vira 422 com `campos` (mesmo formato da validação do Pydantic).
- **"Hoje"** vem de `HojeDep` (`core/deps.py`), no fuso `TZ_NEGOCIO`; nunca `date.today()` (a VPS roda em UTC).
- **Dependências Python** via `uv add` (dev: `uv add --dev`); `uv.lock` versionado; CI instala com `--locked`.
- **Commits:** `feat:` / `fix:` / `test:` / `chore:` / `docs:`, em passos pequenos, teste junto com a mudança.

## Architecture

### Backend — `router → service → banco`

Organizado **por módulo de domínio**, não por camada: `backend/app/modulos/<modulo>/` com `models.py` (tabelas), `schemas.py` (entrada/saída Pydantic), `service.py` (regras de negócio) e `router.py` (HTTP). Routers só traduzem HTTP; toda regra fica no service.

- `app/main.py` — cria a app e registra os routers. **Router novo precisa ser incluído aqui.**
- `app/core/` — `config.py` (pydantic-settings lê o `.env`), `db.py` (engine, sessão, `Base`), `seguranca.py` (hash, JWT), `deps.py` (dependências: sessão, usuário logado), `dinheiro.py` (tipo `Dinheiro`, usado em **todo** campo monetário de schema), `erros.py`.
- `app/modulos/` — `auth`, `contas`, `cartoes`, `transacoes`, `categorias`, `revisao` (lista e decisões; `pareamento.py` puro), `importacao` (com `parsers/`), `planejamento`, `investimentos`, `indices`, `pluggy`, `relatorios`.
- `app/modulos/planejamento/calculo.py` — **funções puras** (sem banco, sem I/O): aporte do dia de salário, meses de reserva, alerta de ritmo. É a regra mais importante do app; cobertura de teste completa.
- `app/jobs/` — scripts do cron; reutilizam os services, não duplicam lógica.

### App — `features/` espelha `modulos/`

- `lib/app/` — `app.dart` (MaterialApp, providers), `router.dart` (go_router: login + quatro abas em `StatefulShellRoute`, `redirect` pelo `SessaoCubit`), `tema.dart` (tokens do design system, claro e escuro, `CoresFinancas`), `injecao.dart` (`Dependencias`: repositórios e sessão), `widgets/` (peças comuns do design).
- `lib/core/api/` — `cliente_api.dart` (dio e cliente gerado), `interceptor_auth.dart` (Bearer e refresh em 401, `QueuedInterceptor`), `erro_api.dart` (`ErroApi`: `detail` e `campos` em pt-BR). **É o único lugar que monta o cliente**; os repositórios das features o usam e convertem `DioException` em `ErroApi`.
- `lib/core/auth/` — tokens no flutter_secure_storage, desbloqueio por biometria.
- `lib/core/formatacao/` — dinheiro (`R$ 1.234,56`, leitura do valor digitado, sempre `Decimal`) e datas em pt-BR.
- `lib/core/cache/` — drift, só leitura offline; o servidor é a fonte da verdade.
- `lib/features/<feature>/` — `data/` (repositório que usa o cliente gerado e converte seus modelos `built_value` em modelos `freezed` do app, `String` monetária → `Decimal`), `cubit/` (estado), `ui/` (telas e widgets). Telas e cubits nunca importam tipos do cliente gerado.
- Features: `login`, `inicio` (aporte, reserva, alerta), `revisao` (rascunhos e decisões; o `RevisaoCubit` fica no topo do app, porque a barra de abas mostra o contador; cada folha tem o seu cubit, e o efeito na regra vem pronto da API), `transacoes`, `contas`, `faturas`, `categorias` (categorias e regras, em Mais; o `CategoriasCubit` fica no topo do app, como o `ContasCubit`), `importacao`, `investimentos`, `configuracoes`.

### Autenticação

Bearer, sem cookie e sem CSRF (cliente é um app nativo, não um navegador).

1. `POST /auth/login` devolve access (15 min) + refresh (30 dias) no corpo.
2. O app guarda os dois no flutter_secure_storage; o dio envia `Authorization: Bearer`.
3. Em 401, o dio chama `POST /auth/refresh` e repete a requisição.
4. **Refresh com rotação:** cada uso revoga o anterior (`refresh_token.revogado_em`); o banco guarda só o hash. Reuso de token revogado derruba todas as sessões.
   - Por isso o app faz **um refresh por vez** (fila no interceptor do dio): dois refresh simultâneos com o mesmo token contam como reuso e derrubam tudo.
   - 401 do próprio `/auth/login` ou `/auth/refresh` não dispara refresh: volta para a tela de login.
5. Rotas protegidas recebem `UsuarioDep` (`core/deps.py`); `GET /auth/eu` devolve o usuário do token.
6. Biometria (local_auth) só desbloqueia o app; não substitui o login.

### Fontes de dados

Manual, importação OFX/CSV e Open Finance via Pluggy. Tudo que não é manual entra como **rascunho** e é confirmado na tela de revisão.

- **Formatos:** Nubank (conta e cartão) só por **OFX**; Mercado Pago por **CSV** (não exporta OFX). Não há parser de CSV do Nubank.
- **Idempotência:** unique `(conta_id, fonte, id_externo)`. `id_externo` = FITID (OFX; a linha de IOF usa `FITID:iof`, porque compra e IOF compartilham o FITID no Nubank), id da Pluggy, ou identificador/hash para o CSV do Mercado Pago. FITID ainda repetido no arquivo = erro explícito, nunca descarte silencioso. `importacao.hash_arquivo` impede reimportar o mesmo arquivo.
- **Mesma transação por fontes diferentes** (CSV e Pluggy): não fundir automaticamente; preencher `possivel_duplicata_de` e decidir na revisão.
- **Revisão** (`GET /revisao`, `modulos/revisao/`): cada rascunho aparece numa situação só — duplicata pendente > lado de par sugerido > `pagamento_fatura` > comum com a categoria sugerida; a confirmada com `removida_na_origem_em` é "sumiu da origem". O contador soma as linhas (um par conta 1). Par sugerido (`pareamento.py`: mesmo valor, contas diferentes, ±2 dias, fora de `par_recusado`) e sugestão são calculados na leitura; cada rascunho traz os dois efeitos possíveis na regra (`prever_efeito`). Confirmar exige categoria e usa `confirmar_categoria`; ações compostas usam `aprender` sem commit; ação sobre transação já revisada → 409. Nada é apagado: ignorar = `status = ignorada`. Conta **alimentada por fonte** = tem transação com `fonte ≠ manual`.
- **Categoria e regras:** o grupo da categoria diz com que tipo ela combina (despesa/estorno ↔ essencial e variável, receita ↔ renda, aporte/resgate ↔ investimento). A regra casa quando o padrão (descrição original normalizada, `categorias/classificacao.py`) aparece como palavras inteiras; sem coluna `prioridade`: manual > restrita a uma conta > padrão mais longo. A sugestão é calculada na leitura; `transacao.categoria_id` só é gravada ao confirmar (`categorias/regras.py: confirmar_categoria`, que aprende ou corrige a regra; regra manual não muda na revisão) ou no lançamento manual (sem aprender).
- **Não contam como gasto:** `pagamento_fatura` e transferências entre contas próprias (`transferencia_par_id`). Pagamento de fatura = **uma** transação `pagamento_fatura` na corrente/carteira que paga, com `fatura_id` da fatura paga (`POST /cartoes/{id}/faturas/{competencia}/pagamentos`). Transferência = saída na origem + entrada no destino, cada uma apontando para a outra (`POST /transacoes/transferencias`, só corrente e carteira). Spec `2026-10-24-pagamento-transferencia-design.md`.
- **Cartão:** toda transação de conta `cartao_credito` tem `fatura_id`. Data da compra ≠ competência da fatura (mês do vencimento) ≠ data do pagamento. Fechamento e vencimento no próximo dia útil; compra no dia do fechamento vai para a fatura seguinte. A fatura só é gravada quando recebe transação ou é editada, e as rotas a endereçam pela competência (`AAAA-MM`). Status derivado: aberta antes do fechamento; depois, `paga` se o valor pago (pagamentos ligados, com rascunhos, fora o lado do cartão) cobre o valor, senão fechada. Spec `2026-10-23-cartoes-faturas-design.md`. Compra parcelada = `compra_parcelada` + uma transação por parcela, cada uma na sua fatura; o app só gera parcelas no lançamento manual (`POST /transacoes/parceladas`, 2 a 24x) — das fontes, chegam as que a Pluggy/OFX enviam. Parcela k: data da compra + (k−1) meses, fatura da compra + (k−1) competências, centavo que sobra na 1ª; fechamento que muda leva a compra inteira (`realocar_compras`). Spec `2026-10-24-compra-parcelada-design.md`.

### Pluggy (Open Finance)

- **Consulte o MCP `pluggy-docs` antes de escrever ou alterar código de integração.** Não confie em memória sobre a API. Se não estiver configurado: `claude mcp add --transport http pluggy-docs https://mcp.pluggy.ai/mcp`.
- Conector **MeuPluggy**, item **proxy**: espelha o item do Meu Pluggy (atualizado a cada 24h) e **não pode ser atualizado via API**. Atraso de ~24h é aceito.
- **Sem webhook:** `jobs/sync_pluggy.py` roda uma vez por dia e relê uma **janela de 40 dias** por conta via **`GET /v2/transactions`** (o v1 `GET /transactions` some após 2026-12-31).
- Cada atualização traz **sobreposição de 4 dias** → deduplicar pelo id da Pluggy. **Não há id estável** (sem `providerId`): transação da janela que sumiu da API é removida se rascunho, ou marcada `removida_na_origem_em` se confirmada.
- **`date` vem em UTC com horário** → converter para `America/Fortaleza` antes de truncar. No cartão o sinal de `amount` é o inverso da conta; use `type`.
- Uso pessoal: autorização de 1 ano, renovada à mão; a renovação pode gerar **itemId novo**, religado à conexão existente. Detalhes na spec `2026-10-19-pluggy-spike-design.md`.
- **Sem endpoint para listar itens:** o `itemId` é colado no app (Mais → Open Finance), validado com `GET /items/{id}`; cada conta da Pluggy vira conta nova ou é vinculada a uma existente. Conexão só é desativada, nunca excluída. "Buscar agora" roda o nosso sync no máximo 1×/hora. Spec `2026-10-20-conexoes-pluggy-design.md`.
- `GET /items/{id}/resources` diz o que o banco realmente compartilhou; consentimento tem validade — o app avisa antes de expirar (`conexao_pluggy.consentimento_expira_em`).
- **Somente leitura na Pluggy.** Cliente em `modulos/pluggy/client.py` expõe só métodos GET (além do `/auth`). Os endpoints de escrita de conexões e vínculos gravam só no nosso banco.

## Environment Variables

**Backend** (`backend/.env`, ver `.env.example`):

```
DATABASE_URL=postgresql+psycopg://financas:<senha>@127.0.0.1:5432/financas
JWT_SECRET=...                     # 32+ caracteres
ACCESS_TOKEN_MINUTOS=15
REFRESH_TOKEN_DIAS=30
PLUGGY_CLIENT_ID=...
PLUGGY_CLIENT_SECRET=...
TZ_NEGOCIO=America/Fortaleza
```

**Compose** (`.env` na raiz): `POSTGRES_PASSWORD` obrigatório.

**App:** só `--dart-define=API_URL=...` no build (em release, o endereço `https://...ts.net` da VPS). **Nenhum segredo no APK** — chave da Pluggy fica exclusivamente no backend.

**Produção:** o `.env` real fica só na VPS, gerado lá mesmo (`deploy/.env.example`: `POSTGRES_PASSWORD`, `JWT_SECRET` e os opcionais); a `TAG` da imagem fica em `versao.env`, gravado pelo `implantar.sh`. O deploy não guarda segredo de longa duração: o environment `producao` do GitHub tem só `TS_OAUTH_CLIENT_ID` e `TS_AUDIENCE` (da credencial OIDC da Tailscale) e `VPS_HOST` (`<maquina>.<tailnet>.ts.net`), que não dão acesso sozinhos e ficam em secrets para saírem mascarados no log público. Os segredos do backup ficam em `/opt/financas/restic.env` (`deploy/restic.env.example`: `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` da application key do B2, `BACKUP_PING_URL` opcional); a senha do restic tem uma segunda cópia no gerenciador de senhas, porque sem ela o backup não abre. Os que vierem depois (keystore do APK) ficam nos secrets do GitHub ou na VPS, nunca no repositório.

Nunca commitar segredos nem colar credenciais em specs, planos ou notas.

## Testing & CI

- **Backend:** pytest contra **Postgres real** via testcontainers, nunca SQLite — `NUMERIC` e `CHECK` precisam se comportar como em produção. Fixtures em `backend/tests/conftest.py`: `client` (sessão e config do teste, "hoje" fixo em `tests.utils.HOJE`) e `api` (o `client` já com o Bearer de um usuário fictício).
  - `tests/unit/` — `calculo.py`, parsers, datas de fatura/feriado. Sem banco, rápidos.
  - `tests/integration/` — endpoints via `TestClient` com banco real e transação revertida por teste.
  - `tests/fixtures/` — OFX/CSV **fictícios**. Nunca extratos reais.
  - Pluggy é mockado nos testes (respx ou cliente fake); nenhum teste chama a API real.
- **App:** `flutter test` para cubits (bloc_test), formatação, interceptor e repositórios (adaptador HTTP falso do dio, `test/apoio/adaptador_falso.dart`) e widget tests das telas e do app inteiro (`test/app/app_test.dart`). Repositórios falsos escritos à mão em `test/apoio/`, sem mocktail.
- **Testes herméticos:** não dependem de `.env` local nem de banco pré-populado.
- **CI** (`.github/workflows/`): `backend.yml` (ruff + pytest via uv `--locked`), `app.yml` (Flutter 3.47.7: build_runner do cliente gerado + `flutter pub get --enforce-lockfile` + build_runner do app + flutter analyze + flutter test), `imagem.yml` (imagem da API para amd64 e arm64: em PR só builda; na `main` publica no GHCR) e `deploy.yml` (depois do `imagem` na `main`, ou à mão: Tailscale por OIDC → scp + ssh → `implantar.sh` → teste de fumaça); em tag `v*`, gera o APK assinado e anexa ao release (previsto, card S10).
- **Ruleset "main protegida":** mudança só via PR (sem exigir aprovação: projeto solo), sem force-push e sem apagar a `main`. **Push direto na `main` é bloqueado.** Os checks `backend` e `app` entram como obrigatórios no ruleset assim que cada workflow rodar pela primeira vez (o nome do check só existe depois disso).
- **Repositório:** público; branch apagada após o merge; secret scanning e push protection ativos (push com segredo é bloqueado); alertas e PRs de segurança do Dependabot ativos (passam pelo CI como qualquer PR); `GITHUB_TOKEN` só leitura; workflows de PR vindos de fork exigem aprovação para qualquer colaborador externo.

## Design

As telas são desenhadas no **Claude Design** antes de implementadas, sempre com **dados fictícios**. Cores, tipografia e espaçamentos viram tokens em `app/lib/app/tema.dart`; as telas viram widgets em `features/<feature>/ui/`. Os links dos designs ficam no `CLAUDE.local.md`.

- **Um canvas só**, uma página por feature, usando o design system do projeto (claro e escuro em cada tela).
- **Fluxo:** o Claude Code desenha o rascunho direto no canvas a partir das specs; os ajustes vêm pelo chat (ou à mão no Claude Design, para detalhes visuais).
- **Um card "Design · …" no Trello por feature**, com prazo no domingo antes da semana do código. O card de código só vai para "Em andamento" com o design aprovado.
- Tela que ainda não existe no app aparece como placeholder "em breve" (aba, item de menu ou opção), nunca escondida.

## Documentation Map

| Onde | O quê |
|---|---|
| `docs/arquitetura.md` | Ponto de partida: fontes, Pluggy, stack, armadilhas, modelo de dados, pastas |
| `docs/briefing.md` | **Local, fora do git:** renda, contas, regras de aporte com valores reais, cronograma |
| `docs/superpowers/specs/` | Decisões e motivos, escritas antes de implementar |
| `docs/superpowers/plans/` | Planos passo a passo derivados de uma spec |
| `docs/explicacoes/` | **Local, fora do git:** notas de aprendizado (FastAPI, Flutter, conceitos do domínio) |
| `docs/runbooks/` | Procedimentos de produção passo a passo: backup e restauração |
| `docs/agents/` | Configuração dos skills de engenharia: issue tracker, labels de triagem, docs de domínio |
| `README.md` | Vitrine do portfólio: prints do modo demo, arquitetura, como rodar |

Nomes: `YYYY-MM-DD-<tema>-design.md` (specs), `YYYY-MM-DD-<tema>.md` (planos), `NN-<tema>.md` (explicações).

Specs já decididas (2026-10-19): hospedagem e deploy; cálculo de aporte e alerta; dinheiro no contrato da API; backend síncrono e usuário único; revisão e classificação; spike da Pluggy (sync, reconciliação, cartão, investimentos). Em 2026-10-20: conexões da Pluggy pelo app (itemId, vínculo de contas, estado do sync). Em 2026-10-23: cartões e faturas (regra das datas, feriados com Carnaval, fatura calculada até ser gravada, ajuste para o valor real, editar/desativar cartão). Em 2026-10-24: compra parcelada (divisão com o centavo na 1ª, data e fatura de cada parcela, realocação da compra inteira); pagamento de fatura e transferência (pagamento numa transação só, status `paga` derivado, par de transferência). Em 2026-10-26: a spec da revisão ganhou as decisões do design (categorias, regras sem prioridade, compatibilidade com o tipo, `par_recusado`, duplicata). Em 2026-10-27: as decisões do código da revisão (ordem das situações, pareamento, efeito calculado no servidor, categoria obrigatória ao confirmar, conta alimentada por fonte); e o backup em detalhe, na spec de hospedagem (systemd timer, restic em container, dump sem compressão em arquivo, B2 pela API S3, `restic.env` separado, healthchecks.io, restauração testada). Prevista: deduplicação entre fontes.

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

**`DATABASE_URL` com `127.0.0.1`, não `localhost`.** No Windows, `localhost` tenta IPv6 (`::1`) primeiro e a porta do compose só escuta em `127.0.0.1`: cada conexão trava ~20–60 s antes de cair no IPv4 (a API parece "pendurada").

**Emulador Android não enxerga `localhost` do PC.** Use `http://10.0.2.2:8000`. Em aparelho físico, use o IP da máquina na rede ou o endereço da Tailscale. Android bloqueia HTTP sem TLS por padrão em release — só HTTPS fora do debug.

**`build_runner` precisa rodar de novo** depois de mudar classes freezed, json_serializable ou tabelas drift, e depois de regerar o cliente da API; erro de "part file not found" quase sempre é isso. Os `.g.dart` e `.freezed.dart` não são commitados. A flag `--delete-conflicting-outputs` foi removida no `build_runner` atual (só gera aviso).

**O `dart-dio` traduz `format: decimal` para `double`.** O contrato está certo (`string`/`decimal`), mas sem o `--type-mappings decimal=String` do script todo campo de dinheiro vira `double` no Dart, e a leitura de `"1234.56"` quebra em tempo de execução. Ao mexer no script, confira que `saldoAtual`/`valor` continuam `String` (o teste `app/test/core/api/cliente_api_test.dart` acusa).

**Vencimento e fechamento caem em feriado/fim de semana.** Sempre calcular pela tabela `feriado` + regra do cartão (`modulos/cartoes/datas.py`); nunca assumir o dia fixo. A tabela tem feriados até 2040, escritos por extenso na migration (com o Carnaval); anos novos = migration nova gerada com o critério de `tests/integration/test_feriados.py`. `holidays` é dependência só de dev.

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
