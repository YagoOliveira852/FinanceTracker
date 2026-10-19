# Arquitetura

Referência técnica do projeto: fontes de dados, stack, armadilhas do domínio, modelo de dados e estrutura de pastas. As decisões aqui valem para qualquer usuário; valores pessoais (renda, saldos, datas dos cartões, metas) ficam fora do repositório e entram no app como parâmetros editáveis.

Decisões que mudarem este documento ganham uma spec em `docs/superpowers/specs/` explicando o motivo.

---

## 1. Visão geral

App Android (Flutter) + API (FastAPI) de controle financeiro pessoal, para um único usuário. A pergunta que o app responde:

> "Quanto posso aportar no próximo salário, e estou gastando a ponto de afetar minha reserva?"

O app precisa funcionar sem depender de disciplina de registro: a maior parte dos dados chega sozinha (importação de extratos e Open Finance) e o usuário só **revisa**.

---

## 2. Fontes de dados

| Fonte | Como funciona | Observações |
|---|---|---|
| **Lançamento manual** | Formulário rápido | Dinheiro em espécie e ajustes. |
| **Importação OFX/CSV** | Nubank envia extrato da conta por e-mail em PDF, OFX e CSV (pedido manual no app). Mercado Pago exporta PDF/XLSX/CSV, até 31 dias por extrato. | Reserva para quando a Pluggy falhar e para histórico. FITID do OFX para deduplicar. |
| **Open Finance via Meu Pluggy** | O usuário conecta os bancos em meu.pluggy.ai; o backend lê pela API usando o conector MeuPluggy. | Gratuito para os próprios dados. Até 5 conexões do mesmo titular. **Atraso de ~24h aceito.** |
| **API SGS do Banco Central** | CDI diário (série 12) | Pública e gratuita. Rendimento estimado e benchmark. |

**Fora do escopo (possível futuro):** leitura de notificações do Android; cotações da B3 (brapi.dev); renda variável; multiusuário.

**Ideia central de UX:** o que vem de importação ou da Pluggy entra como **rascunho**; o usuário **revisa** (confirma categoria). A tela de revisão é o coração do app.

---

## 3. Open Finance via Meu Pluggy

**Quem é a Pluggy:** fintech de Open Finance autorizada pelo Banco Central como instituição de pagamento (ITP) desde junho/2024. Sujeita à regulação do Open Finance e à LGPD.

**Fluxo:**
1. O usuário cria conta em meu.pluggy.ai e autoriza cada banco pelo fluxo oficial de consentimento.
2. Cria uma aplicação em dashboard.pluggy.ai e obtém client id/secret.
3. Autoriza o conector MeuPluggy na aplicação, uma vez por banco.
4. O backend troca client id/secret por API key e lê contas, saldos, transações e investimentos (se o banco compartilhar).

**Comportamento que afeta a arquitetura:**
- Dois Items: o **original** (no Meu Pluggy, atualizado a cada 24h) e o **proxy** (na aplicação), que espelha o original, **não tem auto-sync próprio e não pode ser atualizado via API**.
- **Sem webhook.** Um cron diário lê as transações novas pela API. Assim o backend não precisa estar exposto para a Pluggy.
- Na criação do Item vêm até 365 dias de histórico; atualizações trazem sobreposição de 4 dias → deduplicar pelo id da transação da Pluggy.
- O que foi pedido ≠ o que o banco compartilha: consultar `GET /items/{id}/resources`.
- Consentimento tem validade (tipicamente 12 meses) e pode ser revogado no app do banco ou no Meu Pluggy. O app mostra a validade e avisa antes de expirar.

**Riscos e mitigação:**

| Risco | Na prática | Mitigação |
|---|---|---|
| Terceiro guarda os dados | Transações ficam armazenadas na Pluggy. | Instituição regulada; revogar se deixar de usar. |
| Vazamento das credenciais de API | Client id/secret dão leitura de todo o histórico. Maior risco real. | Só no backend (`.env`), nunca no APK nem no repositório. |
| Backend e banco de dados | O Postgres guarda o histórico financeiro. | Rede privada (só Tailscale) + autenticação; backup criptografado fora da VPS; dados reais nunca no seed/demo. |
| Movimentação de dinheiro | Compartilhamento de dados é só leitura; pagamento exige consentimento próprio. | Usar apenas endpoints de leitura. Nada de pagamentos. |
| Dependência de serviço gratuito | Termos podem mudar; conexão pode cair (`LOGIN_ERROR`). | Fontes plugáveis; OFX/CSV sempre disponível. |
| Golpes | Mensagens falsas "em nome do Open Finance". | Autorizar só pelos canais oficiais. |

### 3.1 Ferramentas da Pluggy para o Claude Code

**MCP de documentação** (configurar antes de escrever o cliente Pluggy):

```bash
claude mcp add --transport http pluggy-docs https://mcp.pluggy.ai/mcp
```

Hospedado pela Pluggy, sem autenticação; dá acesso à documentação, referência da API, changelog e receitas. Antes de escrever ou alterar o cliente, consultar o MCP para confirmar endpoints, campos de transação de cartão (parcelas, fatura), paginação e erros.

**Agent Skills oficiais (opcional):** repositório `pluggyai/agent-skills` (`pluggy-integration`, `pluggy-open-finance`, `pluggy-doctor`). O `pluggy-doctor` revisa uma integração existente. Instalação em docs.pluggy.ai → Developer tools → AI skills.

---

## 4. Imposto de renda

- **O que o app guarda:** snapshot de saldos em **31/12** (Bens e Direitos); rendimentos de aplicações separados; exportação anual em CSV.
- Não calcula imposto; apenas organiza dados.
- O snapshot de 31/12 precisa estar funcionando antes do fim do ano — não dá para reconstruí-lo depois com precisão.

---

## 5. Stack

**Backend — FastAPI**
- FastAPI + Pydantic v2 + SQLAlchemy 2.0 + Alembic + PostgreSQL 16.
- **Síncrono:** rotas `def`, `Session` do SQLAlchemy, `httpx.Client` para Pluggy e BCB (ver spec `2026-10-19-backend-sincrono-usuario-unico`).
- uv (dependências), ruff (lint), pytest + `TestClient`, testcontainers (Postgres real — `NUMERIC` e `CHECK` precisam se comportar como em produção).
- Auth: Bearer com access + refresh token (sem cookie/CSRF). Usuário único criado por comando (`python -m app.criar_usuario`), sem endpoint de cadastro.
- Jobs: container `jobs` com cron no Compose da VPS rodando scripts (sync Pluggy 07:00 com nova tentativa às 13:00; CDI do BCB). Sem Celery.
- Por que existe um backend: segredos fora do APK; tarefas agendadas; cálculos testáveis em Python.

**App — Flutter (Android)**
- go_router; Bloc/Cubit.
- dio + freezed/json_serializable nos modelos e estados do app; cliente Dart gerado do OpenAPI (openapi-generator, alvo `dart-dio`, `built_value`) confinado em `packages/api_client/`. O repositório de cada feature converte um no outro (ver spec `2026-10-19-dinheiro-contrato-api`).
- drift (SQLite) como cache de leitura offline; servidor é a fonte da verdade.
- fl_chart; local_auth (biometria); flutter_secure_storage (tokens); flutter_local_notifications (lembrete local nos dias de salário — não lê notificações de outros apps).

**Infra/portfólio**
- Repositório público desde o início, com secret scanning e push protection; dados reais nunca: `.env`, seed fictício, modo demo **local** para prints do README.
- Hospedagem: VPS acessível **só pela Tailscale** (HTTPS via `*.ts.net`), Docker Compose puro (`api`, `db`, `jobs`), deploy por GitHub Actions → Tailscale → ssh. Backup diário criptografado (restic) no Backblaze B2, com restauração testada. Detalhes na spec `2026-10-19-hospedagem-deploy`.
- CI: ruff + pytest; flutter analyze + flutter test; deploy na `main`; APK assinado por tag.

---

## 6. Armadilhas do domínio

- **Dinheiro nunca em float.** `Decimal` no Python, `NUMERIC(14,2)` no Postgres, string no JSON (`"123.45"`). Nada de `double` no Dart para valores: usar o pacote `decimal`.
- **Três datas:** data da compra ≠ competência da fatura ≠ data do pagamento.
- **Importação idempotente:** importar o mesmo arquivo duas vezes, ou receber a sobreposição de 4 dias da Pluggy, não duplica.
- **Mesma transação por duas fontes** (CSV e Pluggy): não fundir automaticamente; marcar como possível duplicata e pedir confirmação na revisão.
- **Pagamento de fatura e transferência entre contas próprias** não são gasto.
- **Compra parcelada:** uma compra gera N parcelas, cada uma numa fatura.
- **Vencimento e fechamento em feriado/fim de semana:** calcular pela tabela `feriado` + regra do cartão, nunca assumir o dia fixo.
- **Rentabilidade com aportes em datas diferentes:** XIRR (pyxirr) comparado ao CDI — opcional.

---

## 7. Modelo de dados

**Decisões:**
- **Usuário único.** Existe tabela `usuario` só para autenticação; as tabelas de domínio não têm `usuario_id`. Tornar multiusuário depois = adicionar a coluna e filtrar.
- **Identificadores do domínio em português, sem acento** (`fatura`, `competencia`), porque os conceitos são brasileiros e não têm tradução limpa. Código de infraestrutura pode ficar em inglês (convenção das bibliotecas).
- Chaves primárias `UUID`; `criado_em`/`atualizado_em` (`timestamptz`) em todas as tabelas.
- Valores sempre `NUMERIC(14,2)`; sinal pelo campo `tipo` e valor sempre positivo (evita confusão de sinal entre fontes).
- Enums como `text` com `CHECK` (mais fácil de migrar com Alembic do que enum nativo do Postgres).
- Todo valor de negócio (dias de fechamento, colchão, metas, rendas) é **dado no banco**, editável no app — nunca constante no código.

### 7.1 Autenticação

**usuario**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| email | text unique | |
| senha_hash | text | argon2 |

**refresh_token**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| usuario_id | uuid FK | |
| token_hash | text unique | guarda só o hash |
| expira_em | timestamptz | |
| revogado_em | timestamptz null | rotação: cada uso revoga o anterior |

### 7.2 Contas e cartões

**instituicao** — `id`, `nome` (ex.: Nubank, Mercado Pago), `codigo_compe` (null).

**conta**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| instituicao_id | uuid FK | |
| nome | text | ex.: "Nubank conta" |
| tipo | text | `corrente` \| `cartao_credito` \| `carteira` (dinheiro) |
| saldo_inicial | numeric(14,2) | saldo na data abaixo |
| data_saldo_inicial | date | ponto de partida dos cálculos |
| ativa | bool | |
| pluggy_account_id | text null unique | vínculo com a conta na Pluggy |

Saldo atual = `saldo_inicial` + soma das transações confirmadas após `data_saldo_inicial`. Saldo informado pela Pluggy fica em `snapshot_saldo` e serve para conferir se falta algum lançamento.

**cartao** (1:1 com conta do tipo `cartao_credito`)
| coluna | tipo | nota |
|---|---|---|
| conta_id | uuid PK/FK | |
| conta_pagamento_id | uuid FK | conta corrente que paga a fatura |
| dia_fechamento | smallint | 1–31, por cartão |
| dia_vencimento | smallint | 1–31, por cartão |
| limite | numeric(14,2) null | |

**fatura**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| cartao_id | uuid FK | |
| competencia | date | primeiro dia do mês da fatura (ex.: 2026-11-01) |
| data_fechamento | date | calculada a partir do cartão, editável |
| data_vencimento | date | ajustada para dia útil |
| valor_informado | numeric(14,2) null | valor que o banco mostra (Pluggy ou manual) |
| status | text | `aberta` \| `fechada` \| `paga` |
| unique | (cartao_id, competencia) | |

Total calculado = soma das transações da fatura. Diferença entre calculado e informado = lançamentos faltando.

**feriado** — `data` PK, `descricao`. Usado para ajustar vencimento e a data esperada do salário. Seed só com feriados nacionais, gerado pela biblioteca `holidays` (feriado municipal não move vencimento de banco digital).

### 7.3 Transações

**categoria**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| nome | text unique | Alimentação, Transporte, Mercado Livre... |
| grupo | text | `essencial` \| `variavel` \| `renda` \| `investimento` |
| ativa | bool | |

**importacao** (um arquivo importado ou uma execução do sync)
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| fonte | text | `ofx` \| `csv_nubank` \| `csv_mercadopago` \| `pluggy` |
| conta_id | uuid FK null | |
| nome_arquivo | text null | |
| hash_arquivo | text null unique | impede importar o mesmo arquivo duas vezes |
| periodo_inicio / periodo_fim | date null | |
| qtd_novas / qtd_duplicadas | int | resumo mostrado ao usuário |
| status | text | `ok` \| `erro` |
| erro | text null | |

**compra_parcelada** — `id`, `descricao`, `valor_total`, `qtd_parcelas`, `data_compra`. Agrupa as parcelas.

**transacao**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| conta_id | uuid FK | |
| tipo | text | `despesa` \| `receita` \| `transferencia_saida` \| `transferencia_entrada` \| `pagamento_fatura` \| `aporte` \| `resgate` \| `estorno` \| `ajuste` |
| valor | numeric(14,2) | sempre > 0 |
| data | date | data da operação (compra/Pix) |
| descricao_original | text | como veio do banco, nunca editada |
| descricao | text | editável pelo usuário |
| categoria_id | uuid FK null | |
| status | text | `rascunho` \| `confirmada` \| `ignorada` |
| fonte | text | `manual` \| `ofx` \| `csv_nubank` \| `csv_mercadopago` \| `pluggy` |
| id_externo | text null | FITID, id da Pluggy ou hash gerado |
| importacao_id | uuid FK null | |
| fatura_id | uuid FK null | obrigatório se a conta é cartão |
| compra_parcelada_id | uuid FK null | |
| parcela_numero | smallint null | |
| transferencia_par_id | uuid FK null | liga saída e entrada entre contas próprias |
| investimento_id | uuid FK null | para `aporte`/`resgate` |
| possivel_duplicata_de | uuid FK null | marcada quando outra fonte trouxe algo igual |
| unique | (conta_id, fonte, id_externo) | coração da idempotência |

**Regras de `id_externo`:** OFX → FITID; Pluggy → id da transação; CSV sem id → hash de (conta, data, valor, descrição original, ordem da linha no mesmo dia).

**Por que `transferencia_par_id`:** um Pix entre duas contas próprias aparece como saída numa e entrada na outra. Ligadas, não contam como gasto nem como renda. O app sugere o par (mesmo valor, sentidos opostos, contas próprias diferentes, até ±2 dias) e só liga com confirmação na revisão; depósito de dinheiro físico (carteira → corrente) também é transferência.

**Por que `pagamento_fatura` é tipo próprio:** sai dinheiro da conta corrente, mas o gasto já foi contado nas compras do cartão. Se contasse de novo, o gasto do mês dobraria.

**regra_classificacao**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| padrao | text | descrição original normalizada (sem acentos, números, datas, códigos e termos genéricos como "pix enviado") |
| conta_id | uuid FK null | restringe a uma conta |
| categoria_id | uuid FK | |
| prioridade | int | maior vence |
| origem | text | `manual` \| `aprendida` (criada na 1ª confirmação de categoria; uma correção sobrescreve a categoria e zera `vezes_aplicada`) |
| vezes_aplicada | int | |

### 7.4 Planejamento

**configuracao** (linha única)
| coluna | tipo | nota |
|---|---|---|
| id | smallint PK = 1 | |
| colchao | numeric(14,2) | valor mantido na conta após o aporte |
| meta_reserva_meses | numeric(4,1) | meta da reserva em meses de gasto |
| gasto_semanal_estimado | numeric(14,2) | usado até haver histórico |
| gasto_mensal_referencia | numeric(14,2) null | para "meses de reserva"; null = média dos últimos 3 meses |

**renda_prevista**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| descricao | text | ex.: "Salário 1ª quinzena" |
| valor | numeric(14,2) | |
| dia_previsto | smallint | dia do mês |
| conta_id | uuid FK | onde cai |
| ativa | bool | |

O cálculo de aporte e o alerta de reserva **não são tabelas**: são funções puras no backend (`planejamento/calculo.py`) que recebem saldos, faturas, rendas previstas e configuração, e devolvem o resultado. Isso as torna fáceis de testar e de explicar.

Fórmula do aporte (sugerida quando a receita do salário é detectada):

```
aporte = saldo disponível (contas corrente + carteira)
       − faturas que vencem até o próximo salário, inclusive
         (pelo maior entre valor_informado e o total calculado)
       − gastos previstos até o próximo salário
       − colchao
```

O dinheiro das faturas fica na conta, fora dos investimentos (evita IR/IOF de resgate curto). Aporte e alerta consideram transações confirmadas **e rascunhos** (menos os marcados como possível duplicata), avisando quantos rascunhos estão pendentes; o saldo oficial usa só confirmadas. O **alerta de ritmo** tem três níveis — 🟢 sobra ≥ colchão, 🟡 entre 0 e o colchão, 🔴 negativo (exigiria resgatar a reserva) — e aparece na tela inicial.

Definições completas (data esperada do salário, gastos previstos, meses de reserva, exemplos) na spec `docs/superpowers/specs/2026-10-19-calculo-aporte-alerta-design.md`.

### 7.5 Investimentos

**investimento**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| nome | text | ex.: "Caixinha Turbo" |
| instituicao_id | uuid FK | |
| indexador | text | `cdi` (só CDI no escopo) |
| percentual_indexador | numeric(6,2) | ex.: 120.00 |
| teto | numeric(14,2) null | limite de saldo com a taxa do produto |
| data_fim_condicao | date null | fim da condição promocional |
| restricao | text null | ex.: "rendimento só no Mercado Livre" |
| conta_reserva | bool | conta para a meta de reserva? |
| ativo | bool | |
| pluggy_investment_id | text null unique | |

Aportes e resgates são `transacao` com `investimento_id` (saem/entram na conta corrente).

**snapshot_saldo** (saldo real em uma data)
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| conta_id | uuid FK null | |
| investimento_id | uuid FK null | um dos dois preenchido |
| data | date | |
| saldo | numeric(14,2) | |
| fonte | text | `manual` \| `pluggy` |
| unique | (conta_id, investimento_id, data) | |

Uso: conferir saldos, rendimento real (`saldo atual − saldo anterior − aportes + resgates`) e o 31/12 do IR.

**indice_diario** — `data` + `indice` (PK composta), `valor` numeric(12,8). CDI diário da série SGS 12.

### 7.6 Open Finance

**conexao_pluggy**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| item_id | text unique | item proxy MeuPluggy |
| instituicao_id | uuid FK | |
| status | text | como a Pluggy informa |
| consentimento_expira_em | timestamptz null | para o aviso |
| ultimo_sync_em | timestamptz null | |
| ultimo_erro | text null | |

### 7.7 Relacionamentos (resumo)

```
instituicao 1─N conta 1─1 cartao 1─N fatura
conta 1─N transacao N─1 categoria
fatura 1─N transacao
compra_parcelada 1─N transacao
transacao 1─1 transacao (transferencia_par_id)
importacao 1─N transacao
investimento 1─N transacao (aporte/resgate)
conta|investimento 1─N snapshot_saldo
instituicao 1─N conexao_pluggy
```

---

## 8. Estrutura de pastas (monorepo)

```
FinanceTracker/
├── CLAUDE.md                     # instruções do projeto para o Claude Code
├── CLAUDE.local.md               # instruções pessoais (no .gitignore)
├── README.md                     # vitrine do portfólio: prints (modo demo), arquitetura, decisões
├── docker-compose.yml            # Postgres local
├── .github/workflows/
│   ├── backend.yml               # ruff + pytest
│   ├── app.yml                   # flutter analyze + test; APK assinado em tag
│   └── deploy.yml                # imagem no GHCR → Tailscale → ssh → docker compose up
├── docs/
│   ├── arquitetura.md            # este documento
│   ├── briefing.md               # dados e cronograma pessoais (local, fora do git)
│   ├── superpowers/
│   │   ├── specs/                # decisões: YYYY-MM-DD-<tema>-design.md
│   │   └── plans/                # planos de implementação: YYYY-MM-DD-<tema>.md
│   └── explicacoes/              # notas de aprendizado por tema
├── scripts/
│   └── gerar-cliente-api.sh      # exporta openapi.json e roda o openapi-generator
├── backend/
│   ├── pyproject.toml / uv.lock
│   ├── .env.example              # DATABASE_URL, JWT_SECRET, PLUGGY_CLIENT_ID, PLUGGY_CLIENT_SECRET
│   ├── alembic.ini
│   ├── alembic/versions/
│   ├── app/
│   │   ├── main.py               # cria o FastAPI, registra routers
│   │   ├── core/
│   │   │   ├── config.py         # pydantic-settings lê o .env
│   │   │   ├── db.py             # engine, sessão, Base
│   │   │   ├── seguranca.py      # hash de senha, JWT
│   │   │   ├── deps.py           # dependências: sessão, usuário logado
│   │   │   ├── dinheiro.py       # tipo Decimal padronizado e serialização
│   │   │   └── erros.py          # formato único de erro da API
│   │   ├── modulos/              # um módulo por área do domínio
│   │   │   ├── auth/             #   cada um com:
│   │   │   ├── contas/           #   models.py  (tabelas SQLAlchemy)
│   │   │   ├── cartoes/          #   schemas.py (entrada/saída Pydantic)
│   │   │   ├── transacoes/       #   service.py (regras de negócio)
│   │   │   ├── categorias/       #   router.py  (endpoints HTTP)
│   │   │   ├── importacao/
│   │   │   │   └── parsers/      # ofx.py, csv_nubank.py, csv_mercadopago.py
│   │   │   ├── planejamento/
│   │   │   │   └── calculo.py    # funções puras: aporte, meses de reserva, alerta
│   │   │   ├── investimentos/
│   │   │   ├── indices/          # cliente SGS/BCB
│   │   │   ├── pluggy/           # client.py (só leitura), sync.py, mapeamento.py
│   │   │   └── relatorios/       # exportação anual / 31-12
│   │   └── jobs/                 # scripts chamados pelo cron
│   │       ├── sync_pluggy.py
│   │       └── atualizar_cdi.py
│   └── tests/
│       ├── conftest.py           # Postgres via testcontainers, TestClient
│       ├── unit/                 # calculo.py, parsers, datas de fatura
│       ├── integration/          # endpoints com banco real
│       └── fixtures/             # OFX/CSV fictícios
└── app/                          # Flutter
    ├── pubspec.yaml
    ├── packages/
    │   └── api_client/           # GERADO pelo openapi-generator — não editar à mão
    └── lib/
        ├── main.dart
        ├── app/
        │   ├── router.dart       # go_router
        │   ├── tema.dart
        │   └── injecao.dart      # cria repositórios e cubits
        ├── core/
        │   ├── api/              # configura dio, token, refresh automático
        │   ├── auth/             # flutter_secure_storage, local_auth
        │   ├── cache/            # drift (leitura offline)
        │   └── formatacao/       # dinheiro (decimal → "R$ 1.234,56"), datas
        └── features/             # espelha os módulos do backend
            ├── login/
            ├── inicio/           # tela principal: aporte, reserva, alerta
            ├── revisao/          # rascunhos para confirmar
            ├── transacoes/
            ├── contas/
            ├── faturas/
            ├── importacao/
            ├── investimentos/
            └── configuracoes/
            # cada feature: data/ (repositório), cubit/ (estado), ui/ (telas e widgets)
```

**Por que assim:**
- **Por módulo de domínio, não por camada.** Tudo de "faturas" fica junto; fica mais fácil achar e explicar.
- **router → service → banco:** o router só traduz HTTP; a regra de negócio fica no service, testável sem HTTP.
- **`calculo.py` sem banco e sem I/O:** a parte mais importante do app é também a mais fácil de testar.
- **Cliente gerado em pacote separado:** se a API muda, roda o script e o Dart acusa onde quebrou.
- **Flutter `features/` espelha `modulos/`:** a mesma palavra leva ao mesmo assunto nos dois lados.

---

## 9. Questões técnicas em aberto

As três são respondidas pelo spike da Pluggy e pela coleta de amostras, no início do desenvolvimento, antes de modelar cartão e investimento.

1. Investimentos de caixinha/cofrinho aparecem como investimento via Open Finance? (`GET /items/{id}/resources`)
2. Formato de exportação da **fatura** do cartão em cada banco. Se não houver CSV/OFX, cartão chega só pela Pluggy e por lançamento manual.
3. Campos de cartão na API da Pluggy (parcela, fatura) — consultar o MCP `pluggy-docs`.

---

## Fontes

- Pluggy Docs — Item (Meu Pluggy, proxy, sync, histórico): https://docs.pluggy.ai/pt/docs/connections/item
- Pluggy Docs — Servidor MCP: https://docs.pluggy.ai/pt/docs/developer-tools/mcp
- Pluggy Docs — Habilidades do Agente: https://docs.pluggy.ai/pt/docs/developer-tools/ai-skills
- Pluggy — autorização ITP: https://startups.com.br/negocios/rodada-de-investimento/pluggy-conclui-serie-a-de-us-35m-com-dgf-e-y-combinator/
- Política de privacidade Pluggy: https://www.pluggy.ai/docs/politica-de-privacidade.pdf
- Extrato Nubank (PDF/OFX/CSV): https://tecnoblog.net/responde/como-tirar-o-extrato-da-conta-nubank-no-aplicativo/
- Extrato Mercado Pago: https://www.mercadopago.com.br/blog/como-obter-extrato-mercado-pago
- Renovação/revogação de consentimento (BC): https://agenciagov.ebc.com.br/noticias/202310/bc-simplifica-renovacao-de-consentimentos-no-open-finance-e-amplia-prazo-de-validade-do-compartilhamento
