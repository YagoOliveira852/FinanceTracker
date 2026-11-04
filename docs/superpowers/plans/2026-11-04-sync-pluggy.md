# Plano: cliente da Pluggy e sync diário (S7)

Card "S7 · Cliente Pluggy (só leitura) + sync diário". Specs: `2026-10-19-pluggy-spike-design.md` (sync, reconciliação, cartão), `2026-10-20-conexoes-pluggy-design.md` (conexões, estado, "Buscar agora") e `2026-10-19-hospedagem-deploy-design.md` (07:00 com nova tentativa às 13:00). API conferida no MCP `pluggy-docs` em 2026-11-04.

## O que a API diz (pluggy-docs, 2026-11-04)

- `POST /auth` com `clientId` e `clientSecret` devolve `apiKey`, que vale **2 horas** e vai no header `X-API-KEY`. Limite de 360 requisições por minuto por IP.
- `GET /items/{id}`: `status`, `executionStatus`, `error`, `lastUpdatedAt`, `consentExpiresAt`, `connector.name`.
- `GET /accounts?itemId=`: `id`, `type` (`BANK` | `CREDIT`), `subtype` (`CHECKING_ACCOUNT`, `SAVINGS_ACCOUNT`, `CREDIT_CARD`), `number`, `name`, `balance`, `bankData`, `creditData`. Paginada (`page`, `totalPages`).
- `GET /v2/transactions?accountId=&dateFrom=`: cursor; a resposta traz `results` e `next`, a query string pronta para a próxima página (nula no fim). Campos usados: `id`, `description`, `descriptionRaw`, `amount`, `date` (UTC), `type` (`DEBIT` | `CREDIT`; no cartão a Pluggy já normaliza compra como `DEBIT` e pagamento como `CREDIT`), `status` (`POSTED` | `PENDING`), `operationType`, `category`, `creditCardMetadata` (`installmentNumber`, `totalInstallments`, `purchaseDate`, `billId`).
- `GET /bills?accountId=`: `id`, `dueDate`, `billClosingDate`, `totalAmount`. Paginada.

## Decisões do código

- **Cliente** (`modulos/pluggy/client.py`): `httpx.Client` com a URL base e timeout; só `GET` além do `POST /auth`. A chave fica em memória e é renovada antes das 2 horas, ou uma vez ao receber 401. As páginas (cursor ou `page`) são percorridas dentro do cliente, que devolve dataclasses próprias, nunca o JSON cru. Erros viram `ErroPluggy` com uma mensagem em português para `conexao_pluggy.ultimo_erro`.
- **Normalização pura** (`modulos/pluggy/normalizacao.py`): data local (`date` UTC → `America/Fortaleza` → `date`), valor (`abs(amount)` como `Decimal` pela string, nunca `float` somado) e tipo:
  - conta: `CREDIT` → receita, `DEBIT` → despesa; movimento do cofrinho (`TRANSFERENCIA_SALDO_RESERVADO`, visto no spike) → aporte (`DEBIT`) ou resgate (`CREDIT`), como no CSV. A documentação não lista esse valor entre os `operationType` de conta, então a marca é procurada no `operationType` e na descrição original; o campo certo é conferido no teste contra o item real;
  - cartão: `DEBIT` → despesa, `CREDIT` → estorno; o pagamento da fatura do lado do cartão (`operationType=PAGAMENTO_FATURA`) não entra, como no OFX.
- **Modelo:** tabela `conexao_pluggy` (spec de conexões) e, em `conta`, `pluggy_account_id` (único), `conexao_pluggy_id` e `pluggy_numero_final`. Em `fatura`, `pluggy_bill_id` (único). O cadastro pelo app é do card "Vínculo de contas"; este card só lê o que estiver vinculado.
- **Execução do sync** (`modulos/pluggy/sync.py`), por conexão ativa, numa transação do banco cada:
  1. `ultima_tentativa_em` = agora (gravada mesmo se der erro);
  2. `GET /items/{id}`: atualiza `status` e `consentimento_expira_em`;
  3. para cada conta ativa vinculada: no cartão, as faturas (`/bills`) gravam `pluggy_bill_id`, fechamento, vencimento e `valor_informado` na fatura da competência do vencimento; depois as transações a partir de hoje − 40 dias;
  4. transação nova → rascunho com `fonte=pluggy` e `id_externo` = id da Pluggy, com a possível duplicata contra outras fontes (`importacao/duplicatas.py`); no cartão, a fatura vem do `billId` ou, sem ele, da regra do cartão pela data; parcela com `installmentNumber` liga à compra parcelada (data da compra do `purchaseDate`, `data_compra_estimada=false`);
  5. transação já gravada: o rascunho é atualizado (valor, data, descrição; `PENDING` → `POSTED` mantém o id); a confirmada não muda, só perde `removida_na_origem_em` se tinha;
  6. reconciliação: transação `pluggy` da conta com data na janela que não veio → rascunho apagado, confirmada marcada `removida_na_origem_em`;
  7. sucesso: `ultimo_sync_em` = agora e `ultimo_erro` nulo. Erro: desfaz o que a conexão gravou, guarda o `ultimo_erro` e segue para a próxima conexão.
  O sync não grava linha em `importacao`: ela apareceria no histórico e no "Desfazer" das importações de arquivo, e o estado de cada execução já fica na `conexao_pluggy`. As transações da Pluggy têm `importacao_id` nulo.
- **Faturas do `/bills`:** só as que vencem a partir do início da janela (hoje − 40 dias). Uma fatura antiga sem o pagamento registrado no app ficaria "vencida e não paga" e entraria no cálculo do aporte.
- **Agendamento:** como o backup, um timer do systemd na VPS roda `docker compose run --rm api python -m app.jobs.sync_pluggy` às 07:00 e `... --repescagem` às 13:00 (`America/Fortaleza`). A repescagem só relê as conexões cuja última tentativa falhou. Sem container `jobs` permanente: na VPS de 1 GB, a RAM fica livre o resto do dia.
- **"Buscar agora"** (`POST /pluggy/conexoes/{id}/sync`): roda a mesma execução para uma conexão, recusando com 429 se `ultima_tentativa_em` tem menos de 1 hora.

## Passos e PRs

**PR 1, backend do sync** (este card):
1. `uv add --dev respx` (aprovado em 2026-10-31).
2. Migration: `conexao_pluggy`, colunas em `conta` e `fatura`, com `CHECK`/únicos à mão.
3. `normalizacao.py` test-first (tabela de casos: transação noturna em UTC, cartão × conta, cofrinho, pagamento da fatura no cartão).
4. `client.py` com testes respx (auth e renovação, cursor, páginas, erros).
5. `sync.py` com testes de integração (cliente falso): nova, duplicata, atualização do rascunho, confirmada intocada, reconciliação, fatura e parcela, erro numa conexão sem afetar as outras.
6. `jobs/sync_pluggy.py` e os units do systemd em `deploy/systemd/`, com o runbook.

**PR 2, estado e telas** (junto com o card "Vínculo de contas"): endpoints de conexões (listar com o estado, cadastrar, vincular, desativar, reativar, renovar, "Buscar agora"), o card de problema no `GET /planejamento/resumo`, a tela Open Finance e o card no Início.

Teste contra o item real (`uv run python -m app.jobs.sync_pluggy`) só depois dos testes, com `PLUGGY_CLIENT_ID` e `PLUGGY_CLIENT_SECRET` no `.env` local.
