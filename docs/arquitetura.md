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
| **Importação OFX/CSV** | Nubank: extrato da conta e fatura do cartão, importados por **OFX** (o app também oferece PDF e CSV). Mercado Pago: extrato por **CSV**, que só sai pelo site (o app exporta só PDF; sem OFX). | Reserva para quando a Pluggy falhar e para histórico. FITID do OFX e `REFERENCE_ID` do CSV para deduplicar. Formatos detalhados nas specs `2026-10-19-revisao-classificacao` (Nubank) e `2026-10-28-importacao` (adendo de 2026-10-29, Mercado Pago). |
| **Open Finance via Meu Pluggy** | O usuário conecta os bancos em meu.pluggy.ai; o backend lê pela API usando o conector MeuPluggy. | Gratuito para os próprios dados. Até 5 conexões do mesmo titular. **Atraso de ~24h aceito.** |
| **API SGS do Banco Central** | CDI diário (série 12) | Pública e gratuita. Rendimento estimado e benchmark. |

**Fora do escopo (possível futuro):** leitura de notificações do Android; cotações da B3 (brapi.dev); renda variável; multiusuário.

**Ideia central de UX:** o que vem de importação ou da Pluggy entra como **rascunho**; o usuário **revisa** (confirma categoria). A tela de revisão é o coração do app.

---

## 3. Open Finance via Meu Pluggy

**Quem é a Pluggy:** fintech de Open Finance autorizada pelo Banco Central como instituição de pagamento (ITP) desde junho/2024. Sujeita à regulação do Open Finance e à LGPD.

**Fluxo:**
1. O usuário cria conta em meu.pluggy.ai e autoriza cada banco pelo fluxo oficial de consentimento.
2. Cria uma aplicação de desenvolvimento em dashboard.pluggy.ai e obtém client id/secret (uso pessoal: gratuito, sem due diligence, até 5 conexões; não precisa do "Unlock real data").
3. Na **Demo** da aplicação, conecta o conector **MeuPluggy** (não o do banco), uma vez por banco, e copia cada `itemId` — não há endpoint para listá-los.
4. No app, em Mais → Open Finance → "Adicionar conexão", cola o `itemId`; o backend valida com `GET /items/{id}`, lista as contas do item e o usuário cria contas novas ou vincula a contas existentes. A renovação anual usa o mesmo campo.
5. O backend troca client id/secret por API key (`POST /auth`, header `X-API-KEY`) e lê contas, saldos, faturas, transações (`GET /v2/transactions`) e investimentos.

Resultado completo do spike e decisões de sync: spec `docs/superpowers/specs/2026-10-19-pluggy-spike-design.md`. Cadastro de conexões, vínculo de contas, "Buscar agora" e estado do sync: spec `docs/superpowers/specs/2026-10-20-conexoes-pluggy-design.md`.

**Comportamento que afeta a arquitetura:**
- Dois Items: o **original** (no Meu Pluggy, atualizado a cada 24h) e o **proxy** (na aplicação), que espelha o original, **não tem auto-sync próprio e não pode ser atualizado via API**.
- **Sem webhook.** Um cron diário lê as transações novas pela API. Assim o backend não precisa estar exposto para a Pluggy.
- Na criação do Item vêm até 365 dias de histórico; atualizações trazem sobreposição de 4 dias. O sync relê uma **janela de 40 dias** e deduplica pelo id da transação da Pluggy.
- **Sem id estável:** o MeuPluggy não envia `providerId`/`providerCode`. A Pluggy pode apagar e recriar uma transação com id novo, e sem webhook não há aviso. Transação da janela que sumiu da API: rascunho é removido; confirmada recebe `removida_na_origem_em` e vira alerta na revisão.
- **`date` vem em UTC com horário:** converter para `America/Fortaleza` antes de truncar para data. No cartão, o sinal de `amount` é o inverso da conta; o sentido vem do `type`.
- `GET /transactions` (v1) só funciona até 2026-12-31; o sync usa `GET /v2/transactions` (cursor).
- O que foi pedido ≠ o que o banco compartilha: consultar `GET /items/{id}/resources`.
- Consentimento vale 1 ano (`consentExpiresAt`) e pode ser revogado no app do banco ou no Meu Pluggy. O app mostra a validade e avisa antes de expirar. A renovação é manual e pode gerar **itemId novo**: o app religa o item à conexão existente, casando contas pelo número e transações por (data local, valor, descrição original).

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
- uv (dependências), ruff (lint), pytest + `TestClient` (pytest-cov para a cobertura do `calculo.py`), testcontainers (Postgres real — `NUMERIC` e `CHECK` precisam se comportar como em produção).
- Auth: Bearer com access + refresh token (sem cookie/CSRF). Usuário único criado por comando (`python -m app.criar_usuario`), sem endpoint de cadastro.
- Jobs: container `jobs` com cron no Compose da VPS rodando scripts (sync Pluggy 07:00 com nova tentativa às 13:00; CDI do BCB). Sem Celery.
- Por que existe um backend: segredos fora do APK; tarefas agendadas; cálculos testáveis em Python.

**App — Flutter (Android)**
- go_router; Bloc/Cubit.
- dio + freezed nos modelos e estados do app; cliente Dart gerado do OpenAPI (openapi-generator via Docker, alvo `dart-dio`, `built_value`, `decimal=String` para dinheiro chegar como `String`) confinado em `packages/api_client/`. O repositório de cada feature converte um no outro (ver spec `2026-10-19-dinheiro-contrato-api`).
- drift (SQLite) como cache de leitura offline; servidor é a fonte da verdade.
- fl_chart; local_auth (biometria); flutter_secure_storage (tokens); flutter_local_notifications (lembrete local nos dias de salário — não lê notificações de outros apps).
- file_picker (seletor do extrato, sem permissão de armazenamento) e receive_sharing_intent (extrato recebido pelo Compartilhar do Android).

**Infra/portfólio**
- Repositório público desde o início, com secret scanning e push protection; dados reais nunca: `.env`, seed fictício, modo demo **local** para prints do README.
- Hospedagem: Locaweb VPS de 1 GB (Ubuntu 24.04, swap de 2 GB), acessível **só pela Tailscale** (`ufw` só aceita ssh na interface da tailnet; HTTPS via `tailscale serve` em `*.ts.net`). Docker Compose puro (`api`, `db` com Postgres enxuto; `jobs` quando os jobs entrarem). `.env` gerado no próprio servidor. Backup diário criptografado (restic) no Backblaze B2: `pg_dump` às 03:30 por um systemd timer, cifrado no servidor, 30 dias de retenção, alerta pelo healthchecks.io e restauração testada num Postgres temporário (runbook `docs/runbooks/backup-restauracao.md`). Detalhes na spec `2026-10-19-hospedagem-deploy`.
- Deploy: a cada push na `main`, `imagem.yml` publica a api no GHCR e `deploy.yml` entra na tailnet como nó efêmero (`tag:ci`, OIDC, sem segredo de longa duração), copia `deploy/compose.prod.yml` e `deploy/implantar.sh` por scp e roda o script por Tailscale SSH: `pull` da tag `sha-<7>`, migrations, `up -d --wait`, teste de fumaça em `/saude`.
- CI: ruff + pytest; flutter analyze + flutter test; imagem e deploy na `main`; APK assinado por tag.

---

## 6. Armadilhas do domínio

- **Dinheiro nunca em float.** `Decimal` no Python, `NUMERIC(14,2)` no Postgres, string no JSON (`"123.45"`). Nada de `double` no Dart para valores: usar o pacote `decimal`.
- **Três datas:** data da compra ≠ competência da fatura ≠ data do pagamento.
- **Importação idempotente:** importar o mesmo arquivo duas vezes, ou receber a sobreposição de 4 dias da Pluggy, não duplica.
- **Mesma transação por duas fontes** (CSV e Pluggy): não fundir automaticamente; marcar como possível duplicata e pedir confirmação na revisão.
- **Pagamento de fatura e transferência entre contas próprias** não são gasto. O pagamento é **uma** transação `pagamento_fatura` na conta que paga (corrente ou carteira), ligada à fatura por `fatura_id`; não há linha do lado do cartão. A transferência são duas transações ligadas por `transferencia_par_id`. Spec `2026-10-24-pagamento-transferencia`.
- **Compra parcelada:** uma compra gera N parcelas, cada uma numa fatura. No lançamento manual, a parcela k tem a data da compra + (k−1) meses e entra na fatura da compra + (k−1) competências (nunca na fatura da própria data, que pode pular uma competência); o centavo que sobra da divisão vai para a 1ª. Fechamento que muda leva a compra inteira, pela data da compra. Spec `2026-10-24-compra-parcelada`.
- **Vencimento e fechamento em feriado/fim de semana:** calcular pela tabela `feriado` + regra do cartão, nunca assumir o dia fixo. Os dois passam para o próximo dia útil, e compra feita no dia do fechamento (já ajustado) entra na fatura seguinte ("melhor dia de compra").
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
| email | text unique | gravado em minúsculas, sem espaços nas pontas |
| senha_hash | text | argon2 |

**refresh_token**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| usuario_id | uuid FK | `ON DELETE CASCADE`, indexado |
| token_hash | text unique | SHA-256 do token; o token em si nunca é guardado |
| expira_em | timestamptz | |
| revogado_em | timestamptz null | rotação: cada uso revoga o anterior; reuso de um revogado revoga todos |

Access token: JWT HS256 assinado com `JWT_SECRET`, com `sub` (id do usuário), `tipo=access`, `iat` e `exp`; não é guardado no banco. Senha entre 8 e 256 caracteres.

### 7.2 Contas e cartões

**instituicao** — `id`, `nome` (unique; ex.: Nubank, Mercado Pago). Sem código COMPE: nenhuma fonte precisa dele (a conta da importação é escolhida pelo usuário, e a Pluggy liga pelo id da conta); entra com migration se algum dia for útil.

**conta**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| instituicao_id | uuid FK null | obrigatório, exceto na carteira (`CHECK`); no cadastro vem o nome, e o backend reaproveita a instituição de mesmo nome (sem diferenciar maiúsculas) ou cria uma |
| nome | text | ex.: "Nubank conta" |
| tipo | text | `corrente` \| `cartao_credito` \| `carteira` (dinheiro) |
| saldo_inicial | numeric(14,2) | saldo no começo do dia abaixo; pode ser negativo |
| data_saldo_inicial | date | ponto de partida dos cálculos; não pode ser depois de hoje |
| ativa | bool | |
| pluggy_account_id | text null unique | vínculo com a conta na Pluggy |
| conexao_pluggy_id | uuid FK null | conexão que alimenta a conta; desativá-la não desativa a conta |
| pluggy_numero_final | text null | 4 últimos dígitos do número na Pluggy; sugere o vínculo na renovação |

Saldo atual = `saldo_inicial` + soma das transações confirmadas a partir de `data_saldo_inicial`, inclusive (entradas somam, saídas subtraem). Transação do próprio dia entra: o caso real é criar a conta e lançar algo no mesmo dia; o risco inverso (transação do dia que já estava no saldo informado) é raro e aparece na conferência. Não é guardado: o service calcula numa consulta agregada só para a lista inteira. O "total disponível" da tela de contas soma correntes e carteiras ativas; cartão não entra. Saldo informado pela Pluggy fica em `snapshot_saldo` e serve para conferir se falta algum lançamento.

**cartao** (1:1 com conta do tipo `cartao_credito`)
| coluna | tipo | nota |
|---|---|---|
| conta_id | uuid PK/FK | |
| conta_pagamento_id | uuid FK | conta corrente que paga a fatura |
| dia_fechamento | smallint | 1–31, por cartão; 31 vira o último dia do mês |
| dia_vencimento | smallint | 1–31, diferente do fechamento (`CHECK`) |
| limite | numeric(14,2) null | `> 0` |

A conta do cartão entra com `saldo_inicial = 0` a partir do dia do cadastro: o cartão não tem saldo, e o app mostra a fatura atual no lugar (`ContaSaida.cartao.fatura_atual`). Editar os dias vale a partir da fatura seguinte à atual. Desativar é `conta.ativa = false`; nada é excluído.

**fatura**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| cartao_id | uuid FK | |
| competencia | date | primeiro dia do mês do **vencimento** (ex.: 2026-11-01 = fatura de novembro) |
| data_fechamento | date | calculada pela regra do cartão, ajustada para dia útil, editável |
| data_vencimento | date | idem; depois do fechamento (`CHECK`) |
| valor_informado | numeric(14,2) null | valor que o banco mostra (Pluggy, OFX ou manual); `>= 0` |
| unique | (cartao_id, competencia) | |

**Regra das datas** (funções puras em `cartoes/datas.py`): se o dia de fechamento é maior que o de vencimento, o fechamento cai no mês anterior ao da competência; dia inexistente no mês vira o último; fechamento e vencimento em fim de semana ou feriado passam para o próximo dia útil; uma compra entra na primeira fatura cujo fechamento (gravado, se a fatura foi editada, ou calculado) é depois da data da compra.

**A fatura só é gravada quando precisa** (recebe transação ou é editada); antes disso a API a calcula. Por isso as rotas usam a competência (`/cartoes/{id}/faturas/2026-11`), e uma `GET` nunca grava. **Sem coluna de status:** aberta antes do fechamento; a partir dele, `paga` se o **valor pago** (soma dos `pagamento_fatura` ligados à fatura, com rascunhos, sem os ignorados e sem os que estiverem na própria conta do cartão) é maior que zero e cobre o valor da fatura, senão `fechada`. Fatura aberta nunca aparece paga, mesmo com pagamento adiantado; pagamento menor deixa a fatura fechada. Pagamento: `POST /cartoes/{id}/faturas/{competencia}/pagamentos`, com a conta que paga, o valor e a data em que o dinheiro sai.

**Valor:** calculado = compras − estornos da fatura (rascunhos contam, ignoradas não, pagamento e transferência ficam fora); valor da fatura = o maior entre informado e calculado. Com diferença, o app oferece "ajustar para o valor real": grava o informado e deixa na fatura **um** `ajuste_saida`/`ajuste_entrada` com a diferença (substituído a cada novo ajuste, removido quando a diferença zera). Mudar o fechamento realoca as compras entre a data antiga e a nova; o ajuste nunca muda de fatura. Detalhes na spec `2026-10-23-cartoes-faturas`.

**feriado** — `data` PK, `descricao`. Usado para ajustar fechamento, vencimento e a data esperada do salário. Feriados nacionais **mais a segunda e a terça de Carnaval** (os bancos não abrem), de 2024 a 2040, escritos por extenso na migration a partir da biblioteca `holidays` (dependência só de dev; um teste confere a lista). Feriado municipal não move vencimento de banco digital. Ano fora da tabela = erro explícito, nunca cálculo sem feriados.

### 7.3 Transações

**categoria**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| nome | text | único sem diferenciar maiúsculas (índice em `lower(nome)`); ex.: Alimentação, Transporte |
| grupo | text | `essencial` \| `variavel` \| `renda` \| `investimento`; editável (para fora de essencial/variável, só sem transações) |
| ativa | bool | desativada sai das opções e as regras dela não sugerem; nunca é excluída |

Seed genérico na migration (essencial: Mercado, Moradia, Saúde, Transporte; variável: Alimentação, Assinaturas, Compras, Educação, Lazer; renda: Salário, Outras receitas; investimento: Investimento). Sem ícone: o ícone vem do tipo da transação. O grupo diz com que tipo de transação a categoria combina: `despesa`/`estorno` ↔ essencial e variável, `receita` ↔ renda, `aporte`/`resgate` ↔ investimento; transferência, pagamento de fatura e ajuste não têm categoria.

**importacao** (um arquivo importado ou uma execução do sync)
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| fonte | text | `ofx` \| `csv_mercadopago` \| `pluggy` |
| conta_id | uuid FK null | |
| nome_arquivo | text null | |
| hash_arquivo | text null unique | SHA-256 dos bytes; impede importar o mesmo arquivo duas vezes (global, independe da conta); só gravado quando a importação dá certo |
| periodo_inicio / periodo_fim | date null | `DTSTART`/`DTEND` do OFX |
| qtd_novas / qtd_possiveis_duplicatas / qtd_ja_importadas / qtd_parcelas | int | resumo mostrado ao usuário; "já importada" = mesmo `(conta_id, fonte, id_externo)`, inclusive ignorada |
| fatura_id | uuid FK null | fatura que o OFX do cartão gravou |
| fatura_valor_antes / fatura_fechamento_antes | numeric(14,2) / date null | o que a fatura tinha antes; o desfazer restaura |
| fatura_valor_gravado / fatura_fechamento_gravado | numeric(14,2) / date null | o que a importação gravou; o desfazer só restaura se a fatura ainda estiver assim |
| status | text | `ok` \| `erro` (erro só no sync da Pluggy: importação de arquivo com erro não grava nada) |
| erro | text null | |

**Importação de arquivo** (`POST /importacoes`, multipart): tudo ou nada; sem prévia, com **desfazer** (`DELETE /importacoes/{id}`) enquanto nenhuma transação dela está confirmada — apaga as transações, as compras parceladas sem parcela, o snapshot e a linha da importação, e devolve a fatura ao que era. Spec `2026-10-28-importacao`.

**compra_parcelada** — `id`, `descricao`, `valor_total` (`CHECK > 0`), `qtd_parcelas` (`CHECK >= 2`; o máximo de 24 do lançamento manual fica na API), `data_compra`, `data_compra_estimada` (bool, padrão `false`). Agrupa as parcelas. Lançamento manual: `POST /transacoes/parceladas`. A Pluggy traz a data real da compra (`creditCardMetadata.purchaseDate`); o OFX só traz a data de cobrança, e aí a data da compra é estimada (parcela N recuada N−1 meses), marcada como estimada e editável na revisão. O app não projeta parcelas futuras a partir das fontes (a Pluggy já as envia como `PENDING`; o OFX traz a do mês); só o lançamento manual de compra parcelada gera as N parcelas.

**transacao**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| conta_id | uuid FK | |
| tipo | text | entradas: `receita` \| `transferencia_entrada` \| `resgate` \| `estorno` \| `ajuste_entrada`; saídas: `despesa` \| `transferencia_saida` \| `pagamento_fatura` \| `aporte` \| `ajuste_saida` |
| valor | numeric(14,2) | sempre > 0 |
| data | date | data da operação (compra/Pix) |
| descricao_original | text | como veio do banco, nunca editada |
| descricao | text | editável pelo usuário |
| categoria_id | uuid FK null | preenchida ao confirmar na revisão ou no lançamento manual; a sugestão das regras não é gravada |
| status | text | `rascunho` \| `confirmada` \| `ignorada` |
| fonte | text | `manual` \| `ofx` \| `csv_mercadopago` \| `pluggy` |
| id_externo | text null | FITID, id da Pluggy ou hash gerado |
| importacao_id | uuid FK null | indexada; o desfazer apaga as transações da importação |
| fatura_id | uuid FK null | obrigatório se a conta é cartão (regra no service); lançamento manual em cartão só aceita `despesa`. Em conta que não é cartão, só o `pagamento_fatura` tem (a fatura paga); sem `CHECK`, porque o pagamento vindo das fontes pode chegar como rascunho antes de a revisão saber a fatura |
| compra_parcelada_id | uuid FK null | indexado; com `parcela_numero`, os dois juntos ou nenhum (`CHECK`) |
| parcela_numero | smallint null | `CHECK >= 1`; até `qtd_parcelas` (regra no service). Sem unique com a compra: a mesma parcela pode chegar por duas fontes até a revisão decidir |
| transferencia_par_id | uuid FK null | liga saída e entrada entre contas próprias; unique, e cada lado aponta para o outro (regra no service). `CHECK`: só `transferencia_saida`/`transferencia_entrada` têm par, e nenhuma é par de si mesma |
| investimento_id | uuid FK null | para `aporte`/`resgate` |
| possivel_duplicata_de | uuid FK null | marcada quando outra fonte trouxe algo igual (mesma conta, valor e sentido, ±2 dias, a outra de fonte diferente e não ignorada, um para um); `ON DELETE SET NULL` (o sync apaga rascunho que sumiu da origem; o desfazer apaga os da importação) |
| removida_na_origem_em | timestamptz null | transação confirmada que sumiu da Pluggy na janela de reconciliação; alerta na revisão |
| unique | (conta_id, fonte, id_externo) | coração da idempotência |

**Ajuste em dois tipos:** com valor sempre positivo, a correção de saldo na conferência com o banco (snapshots) precisa dizer se entra ou sai: `ajuste_entrada` (sobrou dinheiro) e `ajuste_saida` (faltou). Assim o ajuste segue a regra de sinal como qualquer outro tipo e fica no histórico.

**Lançamento manual** entra com `fonte = manual`, `status = confirmada`, `descricao_original = descricao` e `id_externo` nulo.

**Regras de `id_externo`:** OFX → FITID, com sufixo `:iof` na linha de IOF (no Nubank, a compra e o IOF dela compartilham o FITID); se ainda sobrar FITID repetido no arquivo, a importação falha com erro explícito. Pluggy → id da transação. CSV (Mercado Pago) → `REFERENCE_ID`, único por linha na amostra (o hash previsto para um CSV sem identificador não foi necessário); repetido no arquivo = o mesmo erro do FITID. Formatos observados: specs `2026-10-19-revisao-classificacao` e `2026-10-28-importacao` (adendo).

**Dados de fatura vindos do OFX do cartão:** a fatura é a de fechamento mais perto de `DTEND`; `valor_informado` = −`BALAMT` (0 se credor); `data_fechamento` = `DTEND`. O arquivo não traz vencimento: ele continua calculado pela regra do cartão. Todas as linhas do arquivo vão para essa fatura, e compras das fontes nunca são realocadas por mudança de fechamento (só as manuais). "Pagamento recebido" do lado do cartão não é importado.

**Linhas do OFX:** saída = `despesa` (`pagamento_fatura` se o `MEMO` começa com "Pagamento de fatura", na conta); entrada = `receita` (`estorno` se começa com "Estorno"; no cartão, toda entrada que não é pagamento é `estorno`). Parcela (`MEMO` com " - Parcela N/M") ganha `compra_parcelada` com a data da compra estimada. Tudo entra como rascunho.

**Por que `transferencia_par_id`:** um Pix entre duas contas próprias aparece como saída numa e entrada na outra. Ligadas, não contam como gasto nem como renda. O app sugere o par (mesmo valor, sentidos opostos, contas próprias diferentes, até ±2 dias) e só liga com confirmação na revisão; depósito de dinheiro físico (carteira → corrente) também é transferência. No lançamento manual (`POST /transacoes/transferencias`), as duas linhas entram já ligadas, só entre correntes e carteiras ativas (pagar o cartão é pagamento de fatura); sem descrição, "Transferência". Spec `2026-10-24-pagamento-transferencia`.

**Por que `pagamento_fatura` é tipo próprio:** sai dinheiro da conta corrente, mas o gasto já foi contado nas compras do cartão. Se contasse de novo, o gasto do mês dobraria.

**regra_classificacao**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| padrao | text | descrição original normalizada (sem acentos, números, datas, códigos e termos genéricos como "pix enviado"); não vazio (`CHECK`) |
| conta_id | uuid FK null | restringe a uma conta; nulo = todas |
| categoria_id | uuid FK | |
| origem | text | `manual` \| `aprendida` (criada na 1ª confirmação de categoria; editar pelo app a torna manual) |
| vezes_aplicada | int | `>= 0`; sugestões confirmadas como vieram; zera quando uma correção troca a categoria |

**Sem coluna `prioridade`:** a regra casa quando o padrão aparece como palavras inteiras na descrição normalizada (funções puras em `categorias/classificacao.py`); entre as que casam, manual antes de aprendida, restrita a uma conta antes de geral, padrão mais longo antes, e por fim a ordem alfabética. Só sugere regra de categoria ativa e compatível com o tipo da transação. A sugestão é calculada na leitura, não gravada. Na confirmação: sem regra, nasce uma aprendida; sugestão confirmada soma 1 em `vezes_aplicada`; correção de aprendida com o mesmo padrão troca a categoria e zera a contagem (com padrão mais curto, nasce uma aprendida mais longa); regra manual não muda na revisão. Sem unique no banco: duas regras com o mesmo padrão podem coexistir se uma for de renda e outra de gasto; o service recusa as demais repetições. Spec `2026-10-19-revisao-classificacao`.

**par_recusado** — `saida_id`, `entrada_id` (FKs para `transacao`, `ON DELETE CASCADE`), unique no par. "Não é par" na revisão grava aqui; a sugestão daquele par não volta, mas cada lado ainda pode parear com outra transação.

**Revisão:** cada rascunho aparece numa situação só — duplicata pendente > lado de um par sugerido > pagamento de fatura > rascunho comum (com a categoria sugerida) — e a confirmada com `removida_na_origem_em` aparece como "sumiu da origem"; o contador soma decisões e rascunhos comuns (um par conta 1). Par sugerido e categoria sugerida são calculados na leitura. Nada é apagado: ignorar, remover e descartar são `status = ignorada`. Uma conta é **alimentada por fonte** quando tem transação com `fonte` diferente de `manual`: marcar um rascunho como transferência para ela liga com o rascunho que veio de lá; para uma conta sem fonte (a carteira), o app cria o outro lado. Spec `2026-10-19-revisao-classificacao`, seções "Decisões do design da revisão" e "Decisões do código da revisão".

### 7.4 Planejamento

**configuracao** (linha única, criada no primeiro salvamento; sem ela o aporte não é calculado)
| coluna | tipo | nota |
|---|---|---|
| id | smallint PK = 1 | |
| colchao | numeric(14,2) | valor mantido na conta após o aporte |
| meta_reserva_meses | numeric(4,1) | meta da reserva em meses de gasto |
| gasto_semanal_estimado | numeric(14,2) | piso dos gastos previstos (sozinho até 4 semanas de histórico) |
| gasto_mensal_referencia | numeric(14,2) null | para "meses de reserva"; null = média dos 3 últimos meses fechados |

**renda_prevista**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| descricao | text | ex.: "Salário 1ª quinzena" |
| valor | numeric(14,2) | |
| dia_previsto | smallint | dia do mês, 1 a 31 (em mês curto, o último dia; depois, o dia útil seguinte) |
| conta_id | uuid FK | onde cai |
| ativa | bool | renda é desativada, nunca excluída |

O cálculo de aporte e o alerta de reserva **não são tabelas**: são funções puras no backend (`planejamento/calculo.py`) que recebem saldos, faturas, transações recentes, rendas previstas e configuração (dataclasses do próprio módulo, com a data de referência como parâmetro) e devolvem o resultado. Isso as torna fáceis de testar e de explicar.

Fórmula do aporte (sugerida quando a receita do salário é detectada):

```
aporte = saldo disponível (contas corrente + carteira)
       − faturas que vencem até o próximo salário, inclusive
         (pelo maior entre valor_informado e o total calculado,
          menos o que já foi pago)
       − gastos previstos até o próximo salário
       − colchao
```

O dinheiro das faturas fica na conta, fora dos investimentos (evita IR/IOF de resgate curto). Aporte e alerta consideram transações confirmadas **e rascunhos** (menos os marcados como possível duplicata), avisando quantos rascunhos estão pendentes; o saldo oficial usa só confirmadas. O **alerta de ritmo** tem três níveis — 🟢 sobra ≥ colchão, 🟡 entre 0 e o colchão, 🔴 negativo (exigiria resgatar a reserva) — e aparece na tela inicial. O aporte é sugerido quando chega o salário: uma receita na conta da renda, de 80% a 120% do previsto, de 3 dias antes a 5 dias depois da data esperada; a partir daí, o próximo salário é o seguinte.

Definições completas (data esperada do salário, detecção, gastos previstos, meses de reserva, exemplos) na spec `docs/superpowers/specs/2026-10-19-calculo-aporte-alerta-design.md`.

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
| pluggy_investment_id | text null unique | CDBs/caixinhas de `/investments` |
| pluggy_saldo_reservado_id | text null unique | cofrinho que vem como `bankData.reservedBalances` da conta corrente (`identification`) |

Aportes e resgates são `transacao` com `investimento_id` (saem/entram na conta corrente). Para o cofrinho, vêm das transações `TRANSFERENCIA_SALDO_RESERVADO` da Pluggy e das linhas "Dinheiro reservado"/"Dinheiro retirado" do CSV do Mercado Pago; o percentual do CDI é informado à mão, porque o saldo reservado não traz taxa. Até os investimentos existirem, a revisão confirma aporte e resgate com categoria de investimento e sem `investimento_id`.

**snapshot_saldo** (saldo real em uma data)
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| conta_id | uuid FK | obrigatório até os investimentos existirem |
| investimento_id | uuid FK null | **ainda não existe:** entra com os investimentos; aí `conta_id` vira nulo, com `CHECK` de um dos dois |
| data | date | |
| saldo | numeric(14,2) | |
| fonte | text | `manual` \| `ofx` (`LEDGERBAL` do extrato) \| `csv_mercadopago` (saldo da última linha) \| `pluggy` |
| importacao_id | uuid FK null | importação que o gravou; o desfazer o apaga |
| unique | (conta_id, data) | com os investimentos, `(conta_id, investimento_id, data)` com `NULLS NOT DISTINCT` |

Snapshot que chega para uma data que já tem um substitui o valor e passa a ser da nova importação.

Uso: conferir saldos, rendimento real (`saldo atual − saldo anterior − aportes + resgates`) e o 31/12 do IR.

**indice_diario** — `data` + `indice` (PK composta), `valor` numeric(12,8). CDI diário da série SGS 12.

### 7.6 Open Finance

**conexao_pluggy**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| item_id | text unique | item proxy MeuPluggy, cadastrado pelo app; trocado na renovação |
| instituicao_id | uuid FK | |
| status | text | como a Pluggy informa |
| ativa | bool | desativada = o sync não lê; sem exclusão pelo app |
| consentimento_expira_em | timestamptz null | para o aviso |
| ultimo_sync_em | timestamptz null | último sync bem-sucedido |
| ultima_tentativa_em | timestamptz null | última execução, com ou sem sucesso; limita o "Buscar agora" (1×/hora) |
| ultimo_erro | text null | |

O estado do sync aparece na tela Open Finance e, só quando há problema, num card no Início (consentimento vencido > sync com erro > mais de 30 h sem dados > consentimento vencendo em até 30 dias). Regras na spec `2026-10-20-conexoes-pluggy-design.md`.

### 7.7 Relacionamentos (resumo)

```
instituicao 1─N conta 1─1 cartao 1─N fatura
conta 1─N transacao N─1 categoria 1─N regra_classificacao N─0..1 conta
fatura 1─N transacao
compra_parcelada 1─N transacao
transacao 1─1 transacao (transferencia_par_id)
importacao 1─N transacao
importacao 1─0..1 snapshot_saldo
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
├── deploy/                       # produção: compose.prod.yml, implantar.sh, .env.example
│                                 #   backup.sh, testar-restauracao.sh, restic.env.example, systemd/ (timer do backup)
├── .github/workflows/
│   ├── backend.yml               # ruff + pytest
│   ├── app.yml                   # build_runner + flutter analyze + test; APK assinado em tag
│   ├── imagem.yml                # imagem da api (amd64 + arm64) no GHCR
│   └── deploy.yml                # Tailscale (OIDC) → scp + ssh → implantar.sh na VPS
├── docs/
│   ├── arquitetura.md            # este documento
│   ├── briefing.md               # dados e cronograma pessoais (local, fora do git)
│   ├── runbooks/                 # procedimentos de produção (backup e restauração)
│   ├── superpowers/
│   │   ├── specs/                # decisões: YYYY-MM-DD-<tema>-design.md
│   │   └── plans/                # planos de implementação: YYYY-MM-DD-<tema>.md
│   └── explicacoes/              # notas de aprendizado por tema (local, fora do git)
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
│   │   │   ├── revisao/          # lista da revisão, pares sugeridos, decisões
│   │   │   ├── importacao/       # service (tudo ou nada, desfazer), duplicatas.py (puro)
│   │   │   │   └── parsers/      # ofx.py (Nubank conta e cartão), csv_mercadopago.py
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
        │   ├── app.dart          # MaterialApp, providers
        │   ├── router.dart       # go_router: login + abas, redirect pela sessão
        │   ├── tema.dart         # tokens do design system (claro e escuro)
        │   ├── injecao.dart      # cria repositórios e a sessão
        │   └── widgets/          # peças comuns do design
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
            ├── categorias/       # categorias e regras (Mais)
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

1. Formato da **fatura** do cartão do Mercado Pago — verificar quando a primeira fechar. O CSV do extrato da conta foi coletado em 2026-10-29 (spec `2026-10-28-importacao`, adendo).

Respondidas em 2026-10-19 (spec `2026-10-19-pluggy-spike`): caixinhas de banco digital aparecem como CDB em `/investments`; o cofrinho do Mercado Pago aparece como saldo reservado da conta; a Pluggy traz parcela, data real da compra e fatura (`/bills`). O Nubank exporta a fatura em OFX (spec `2026-10-19-revisao-classificacao`).

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
