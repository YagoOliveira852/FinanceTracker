# Pluggy: resultado do spike e decisões de sync

**Status:** decidida em 2026-10-19, a partir de um spike contra dados reais (três bancos conectados via conector MeuPluggy). O spike imprimiu só estrutura, contagens e sim/não; nenhum valor ou id real foi registrado.

## Contexto

O sync da Pluggy é item que não pode ser cortado e concentrava as maiores incertezas: se investimentos de caixinha e cofrinho aparecem, que campos de cartão vêm, e como a falta de webhook afeta a consistência. O spike foi feito antes de modelar cartão e investimento para que essas respostas moldem o modelo.

## Acesso (uso pessoal)

Segue o guia oficial de uso pessoal do Meu Pluggy: gratuito, sem due diligence e sem expirar com trial; até 5 conexões; atualização a cada 24h.

1. Conectar os bancos em meu.pluggy.ai (consentimento de cada banco ali).
2. No dashboard, na Demo da aplicação de desenvolvimento, conectar o conector **MeuPluggy** (nunca o conector do banco nem o Sandbox), uma vez por banco.
3. Copiar o `itemId` de cada item (`GET /v2/items` não existe para uso pessoal; os ids precisam ser guardados).
4. O pedido "Unlock real data" do dashboard não é necessário para uso pessoal.

A autorização vale **1 ano** (`consentExpiresAt`). Ao expirar, as leituras voltam vazias e o próximo update falha com `USER_AUTHORIZATION_EXPIRED`. A renovação é manual (refazer o passo 2) e pode gerar **itemId novo**.

## O que o spike encontrou

### Endpoints

- `POST /auth` → `apiKey` (vale 2h), enviada em `X-API-KEY`.
- `GET /items/{id}`, `GET /items/{id}/resources`, `GET /accounts?itemId=`, `GET /bills?accountId=`, `GET /investments?itemId=`.
- **`GET /transactions` (paginação por página) está depreciado e só funciona até 2026-12-31.** O sync usa **`GET /v2/transactions`** (cursor: `results` + `next`, que é a query string pronta da próxima página; filtros `accountId`, `dateFrom`, `dateTo`, `createdAtFrom`).

### Contas e transações

- Conta corrente: `type=BANK`, `subtype=CHECKING_ACCOUNT`, com `balance` e `bankData` (`closingBalance`, `automaticallyInvestedBalance`, `reservedBalances`).
- Cartão: `type=CREDIT`, `subtype=CREDIT_CARD`, com `creditData` (`balanceDueDate`, `creditLimit`, `availableCreditLimit`, `minimumPayment`, `brand`).
- Transação: `id`, `date`, `amount`, `type` (`DEBIT`/`CREDIT`), `status` (`POSTED`/`PENDING`), `description`, `descriptionRaw`, `category`, `operationType`, `merchant`, `paymentData`, `creditCardMetadata`.
- **`date` é ISO 8601 em UTC com horário** (ex.: `aaaa-mm-ddThh:mm:ss.sssZ`). Pegar só a parte da data erra o dia de transações noturnas; no teste, 7 de 61 transações de um mês caíram em outro dia.
- **Sinal:** na conta, `DEBIT` negativo e `CREDIT` positivo; **no cartão, o inverso** (compra positiva, pagamento/estorno negativo).
- **`providerId` e `providerCode` não vêm** (MeuPluggy é conector direto). Pela documentação, sem eles **não há id estável**: a Pluggy apaga e recria a transação com id novo quando data, descrição ou valor mudam demais, e uma reconexão gera item e ids novos.
- Os ids da Pluggy **não** coincidem com os `FITID` do OFX do mesmo banco.
- `category` (genérica, em inglês: `Same person transfer`, `Credit card payment`, `Salary`, `Groceries`...) e `operationType` (`PIX`, `CARTAO`, `PAGAMENTO_FATURA`, `TARIFA`, `ESTORNO`, `RESGATE_APLIC_FINANCEIRA`, `TRANSFERENCIA_SALDO_RESERVADO`...) vêm preenchidos.

### Cartão e faturas

- `creditCardMetadata`: `installmentNumber`, `totalInstallments`, **`purchaseDate` real** (presente em todas as parcelas; difere da data de cobrança na maioria), `billId`, `billPostDate`, `billForecastDate`, `transactionDateTime`.
- Compras da fatura aberta e parcelas futuras vêm como **`PENDING`** e sem `billId`. Pela documentação, a passagem `PENDING` → `POSTED` **preserva o id** no caso normal.
- `GET /bills`: `billClosingDate`, `dueDate`, `totalAmount`, `minimumPaymentAmount`, `payments`, `financeCharges`. Os `billId` das transações existem em `/bills`.
- IOF vem como transação própria (`operationType=TARIFA`), com id distinto da compra.

### Investimentos

- Caixinhas de rendimento de banco digital aparecem em `/investments` como `type=FIXED_INCOME`, `subtype=CDB`, `rateType=CDI`, `rate` = percentual do CDI (ex.: `120`), com `status` (`ACTIVE`, `TOTAL_WITHDRAWAL`).
- O **cofrinho** do Mercado Pago **não** aparece em `/investments`: vem na conta corrente, em `bankData.reservedBalances` (`name`, `identification`, `availableAmounts`), e seus movimentos são transações `TRANSFERENCIA_SALDO_RESERVADO`. Não traz taxa.

## Decisão

1. **Sync por `GET /v2/transactions`**, 1×/dia (horários da spec de hospedagem), sempre relendo uma **janela de 40 dias** por conta (cobre a sobreposição de 4 dias da Pluggy e a fatura aberta).
2. **Data de negócio = `date` convertido de UTC para `America/Fortaleza`**, e só então truncado para `date`. Vale para `date` e `purchaseDate`.
3. **Normalização de valor:** `valor = abs(amount)`; o sentido vem do `type` combinado com o tipo da conta (na conta, `DEBIT` = saída; no cartão, `DEBIT` = compra), nunca do sinal.
4. **`PENDING` entra como rascunho** normalmente; quando vira `POSTED` com o mesmo id, só atualiza.
5. **Reconciliação da janela:** transação de fonte `pluggy` dentro da janela relida que não veio mais da API:
   - se está `rascunho`, é removida;
   - se já foi `confirmada`, recebe `removida_na_origem_em` e aparece como alerta na revisão (você decide se exclui).
   Uma transação que reaparece com o mesmo id limpa a marcação.
6. **Reautorização anual:** o app pede para associar o item novo à `conexao_pluggy` existente. Contas casam pelo número da conta (`number`); transações do item novo casam com as existentes por (data local, valor, descrição original) e só têm o `id_externo` trocado. O que não casar entra como rascunho.
7. **Faturas a partir de `/bills`:** `billClosingDate` → `data_fechamento`, `dueDate` → `data_vencimento`, `totalAmount` → `valor_informado`; transações ligadas por `billId`. Compras `PENDING` sem `billId` vão para a fatura aberta calculada pela regra do cartão.
8. **Parcelas:** o app **não projeta** parcelas futuras a partir das fontes: a Pluggy já envia as futuras como `PENDING` e o OFX traz a parcela do mês. `compra_parcelada.data_compra` vem do `purchaseDate` quando a fonte é a Pluggy (`data_compra_estimada = false`). Só o lançamento manual de compra parcelada gera as N parcelas.
9. **Investimentos:** CDBs de `/investments` viram `investimento` (`percentual_indexador` = `rate`). O **cofrinho** vira um `investimento` ligado ao saldo reservado (`pluggy_saldo_reservado_id` = `identification`), com saldo vindo de `availableAmounts` e aportes/resgates vindos das transações `TRANSFERENCIA_SALDO_RESERVADO`; o percentual do CDI é informado à mão.
10. **Sugestões a partir da Pluggy:** quando não há regra de classificação aprendida, `category` da Pluggy (mapeada para as categorias do app) vira sugestão; `operationType=PAGAMENTO_FATURA` e `category=Credit card payment` sugerem `pagamento_fatura`; `category=Same person transfer` reforça a sugestão de par de transferência; `category=Salary` ajuda a detectar a receita do salário.
11. **Deduplicação entre fontes** (OFX × Pluggy) continua por `possivel_duplicata_de` com (data local, valor), já que os ids não coincidem.

## Alternativas consideradas

- **`GET /transactions` (v1):** removido após 2026-12-31.
- **Ignorar `PENDING`:** compras da fatura aberta só apareceriam ao liquidar, subestimando a fatura no cálculo do aporte.
- **Sem reconciliação:** recriações da Pluggy virariam duplicatas silenciosas.
- **Importar o item novo só a partir do último sync do antigo:** perde correções retroativas dos últimos dias.
- **Cofrinho só como saldo informativo:** sem histórico de aportes, não entra bem na meta de reserva.
- **App projetar todas as parcelas:** exige casar projeções com o que chega depois, criando outra fonte de duplicata.

## Consequências

- `transacao` ganha `removida_na_origem_em` (timestamptz, nulo).
- `investimento` ganha `pluggy_saldo_reservado_id` (text, nulo, único).
- A conversão de fuso e a normalização de sinal são funções puras com testes de tabela (transação noturna, cartão × conta).
- A reautorização anual tem um fluxo próprio no app, disparado pelo aviso de `consentimento_expira_em`.
- O spike confirmou que a conta onde o salário cai é visível no Open Finance, como previsto na spec de cálculo.
