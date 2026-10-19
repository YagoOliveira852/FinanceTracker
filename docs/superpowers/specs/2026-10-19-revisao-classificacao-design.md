# Revisão: classificação, transferências, feriados e amostras de importação

**Status:** decidida em 2026-10-19.

## Contexto

A tela de revisão é o coração do app: tudo que não é lançamento manual entra como rascunho e é confirmado ali. Para o uso não depender de disciplina, o app precisa sugerir bem (categoria, pares de transferência) e deixar a decisão final com o usuário.

## Decisão

### Regras de classificação aprendidas

- **Padrão = descrição original normalizada**, por uma função pura e testável: minúsculas, sem acentos, sem números, datas e códigos, sem termos genéricos do banco ("pix enviado", "compra", "pagamento", ...). Ex.: `PIX ENVIADO 12/11 PADARIA SAO JOSE LTDA 0349` → `padaria sao jose ltda`.
- A regra é **aprendida na 1ª confirmação** de categoria (`origem = aprendida`). O app só sugere; a revisão confirma.
- **Correção sobrescreve:** se uma regra sugerir errado e o usuário corrigir, a categoria da regra é trocada e `vezes_aplicada` volta a zero.
- Regras manuais e aprendidas convivem; vence a de maior `prioridade`.

### Categorias iniciais

Seed versionado com uma lista genérica, sem nada pessoal: Alimentação, Mercado, Transporte, Moradia, Saúde, Lazer, Assinaturas, Compras, Educação (`essencial`/`variavel`), Salário, Outras receitas (`renda`) e Investimento (`investimento`). O usuário renomeia ou cria outras pelo app.

### Transferências entre contas próprias

- **Sugestão automática de par:** mesmo valor, sentidos opostos, contas próprias diferentes, datas até ±2 dias. O par aparece na revisão e só é ligado (`transferencia_par_id`) com confirmação.
- Depósito de dinheiro físico (`carteira` → `corrente`) também é transferência.
- Nunca fundir automaticamente; mesmo princípio da deduplicação entre fontes.

### Feriados

- A tabela `feriado` recebe **só feriados nacionais**, gerados pela biblioteca `holidays` num seed para os anos em uso. Vencimento de cartão de banco digital segue o calendário bancário nacional; feriado municipal não move a data.
- `fatura.data_vencimento` continua editável para casos que fujam da regra.

### Amostras para os importadores

- Extratos reais ficam numa pasta **fora do repositório** e nunca são lidos diretamente nem versionados.
- Um script local imprime só a estrutura (encoding, separador, cabeçalhos, formato de data e valor, linhas com letras e números mascarados). As fixtures em `backend/tests/fixtures/` são escritas à mão com dados inventados no mesmo formato.
- Leitura de PDF está fora do escopo; só CSV e OFX são importados.

### Formatos observados nas amostras (2026-10-19)

Lidos pela estrutura mascarada e por comparações agregadas (contagens e sim/não), sem conteúdo real. Amostras: extrato da conta e fatura do cartão Nubank de um mês, em CSV e OFX.

**Extrato da conta Nubank**
- OFX (`BANKMSGSRSV1`, `ACCTTYPE` = `CHECKING`): cada `STMTTRN` tem `TRNTYPE` (`CREDIT`/`DEBIT`, coerente com o sinal), `DTPOSTED` (`aaaammddhhmmss[-3:BRT]`), `TRNAMT` (ponto decimal, negativo = saída), `FITID` (UUID único) e `MEMO`. `LEDGERBAL` traz o saldo final com data (`DTASOF`).
- CSV (`Data, Valor, Identificador, Descrição`) tem **o mesmo conteúdo**: os `FITID` são exatamente os valores de `Identificador`, com mesmo sinal e mesma data em todas as linhas.
- Prefixos de descrição: "Compra no débito", "Transferência enviada/recebida pelo Pix", "Depósito Recebido por Boleto", "Estorno", "Débito em conta", "Pagamento de fatura".

**Fatura do cartão Nubank**
- OFX (`CREDITCARDMSGSRSV1`): compras e IOF negativos (`DEBIT`), "Pagamento recebido" positivo (`CREDIT`). `BALAMT` = −(soma de compras e IOF), ou seja, o total da fatura. `DTSTART..DTEND` cobre ~1 mês e `DTEND` é a data de fechamento; **não há data de vencimento** no arquivo.
- **Compra e o IOF dela vêm com o mesmo `FITID`.**
- "- Parcela N/M" no `MEMO` indica parcela; o `DTPOSTED` é a data de **cobrança na fatura**, não a da compra original.
- CSV (`date, title, amount`) tem o mesmo conteúdo, mas com sinal invertido, vírgula decimal, separador de milhar e negativo no formato `- 9.999,99` (espaço após o sinal), e sem identificador por linha.

**Mercado Pago:** conta nova, ainda sem dados. O app exporta extrato em PDF/XLSX/CSV (sem OFX); o CSV do extrato e o formato da fatura serão coletados antes da importação ser implementada.

### Decisões de importação a partir das amostras

- **Nubank só por OFX**, conta e cartão, com um parser OFX genérico. Não há parser de CSV do Nubank; CSV é usado só para o Mercado Pago. `fonte` passa a ser `manual | ofx | csv_mercadopago | pluggy`.
- **`id_externo` no OFX:** o `FITID`; a linha cujo `MEMO` começa com `IOF de` usa `FITID:iof`. Determinístico entre reimportações. Se ainda restar `FITID` repetido no mesmo arquivo, a importação falha com erro explícito em vez de descartar linha.
- **Dados de fatura vindos do OFX:** `valor_informado` = −`BALAMT`; `data_fechamento` = `DTEND`; vencimento continua calculado pela regra do cartão e editável.
- **Saldo da conta vindo do OFX:** `LEDGERBAL` vira `snapshot_saldo` com `fonte = ofx`, para conferência.
- **Parcelas:** `compra_parcelada.data_compra` é **estimada** recuando N−1 meses a partir da data de cobrança da parcela N, marcada como estimada (`data_compra_estimada = true`) e editável na revisão. Quando a mesma compra vem pela Pluggy, o `purchaseDate` real substitui a estimativa (spec `2026-10-19-pluggy-spike`).

## Alternativas consideradas

- **Padrão = descrição inteira:** nunca casa de novo por causa de datas e códigos.
- **Aprender só após 2 confirmações iguais:** menos sugestões erradas, mais trabalho manual no começo do uso.
- **Pares de transferência ligados manualmente:** mais trabalhoso e fácil de esquecer, o que dobra gasto e renda.
- **Feriados de Ceará e Fortaleza:** não afetam o vencimento de bancos digitais.
- **Lista de feriados à mão:** sem dependência nova, mas precisa ser mantida todo ano.

## Consequências

- Normalização e pareamento são funções puras com testes de tabela.
- `holidays` é dependência nova do backend.
- O cartão do Nubank tem exportação estruturada (OFX), então não depende só da Pluggy; o do Mercado Pago ainda será verificado.
- Um único parser OFX atende conta e cartão do Nubank, o que reduz parsers e fixtures na fase de importação.
- Importar CSV do Nubank fica fora do escopo; se for necessário depois, o `Identificador` do CSV é o mesmo `FITID` do OFX.
