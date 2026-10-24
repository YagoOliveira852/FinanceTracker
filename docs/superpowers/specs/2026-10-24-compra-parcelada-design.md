# Compra parcelada no cartão

**Status:** proposta em 2026-10-24, a partir do design aprovado em 21/10 (página "Cartões e faturas" do canvas, artboard "Lançamento · Compra no cartão") e do card "S3 · Compra parcelada".

## Contexto

O card anterior (spec `2026-10-23-cartoes-faturas-design.md`, em produção) trouxe cartão, fatura e a compra à vista: cada transação de cartão tem `fatura_id`, escolhida pela data da compra. Uma compra parcelada não cabe nessa regra: ela pesa em N faturas seguidas, e é isso que o cálculo do aporte (S6) precisa enxergar, porque as parcelas futuras são saída certa nos próximos vencimentos.

Este card cobre só o **lançamento manual** da compra parcelada. Das fontes, as parcelas chegam prontas (a Pluggy envia as futuras como `PENDING`; o OFX traz a do mês) e entram com a importação (S5) e o sync (S7). O modelo daqui serve para elas sem mudança.

## Objetivos

- Lançar uma compra parcelada num cartão: valor total, número de parcelas, data da compra e descrição.
- Gerar uma transação por parcela, cada uma na sua fatura, sem perder nem criar centavo.
- No Lançamento, mostrar a divisão ("3x de R$ 333,33; a 1ª parcela fica com R$ 333,34") e a última fatura ("A última parcela cai na fatura de janeiro de 2027") antes de salvar.
- Mostrar "Parcela N/M" nas compras da fatura.
- Manter as parcelas nas faturas certas quando um fechamento muda (editar fatura ou dias do cartão).

## Fora do escopo

- Importação de parcelas do OFX (S5) e da Pluggy (S7), com a data da compra estimada ou real.
- Editar ou excluir uma compra parcelada (ainda não há edição nem exclusão de transação no app).
- Parcelamento fora do cartão (boleto, carnê) e parcelamento da própria fatura.
- Juros: a compra parcelada é "sem juros" no sentido de que o total digitado é o que se paga; parcelado com juros se lança pelo total com juros.

## Decisões

### Divisão em parcelas

- O usuário digita o **valor total** (o design chama o campo de "Valor total").
- Cada parcela vale o total dividido por N, **truncado no centavo**; o que sobra (de 1 a N−1 centavos) vai **inteiro para a 1ª parcela** (decisão do design, card "S2 · Design · Cartões e faturas"). R$ 1.000,00 em 3x = 333,34 + 333,33 + 333,33; R$ 1,00 em 7x = 0,16 + 6 × 0,14.
- A soma das parcelas é sempre o total. Cada parcela precisa valer pelo menos R$ 0,01, então o total mínimo é N centavos.
- **De 2 a 24 parcelas** *(minha decisão; 24x cobre o que os cartões oferecem no varejo e o limite fica só no schema da API, não no banco)*. "À vista" (1x) continua sendo o lançamento comum.
- Função pura `dividir_em_parcelas(total, quantidade) -> list[Decimal]` em `backend/app/modulos/transacoes/parcelas.py`, com testes de tabela em `tests/unit/` escritos antes do código (TDD): soma = total, a 1ª fica com o resto, as demais iguais, casos de divisão exata, de resto máximo (N−1 centavos) e do mínimo (N centavos).

### Data e fatura de cada parcela

*(Decisão do Yago em 24/10.)*

- **Data da parcela k = data da compra + (k−1) meses**, com o dia que não existe no mês virando o último (31 jan + 1 mês = 28 ou 29 fev). É o que o design mostra ("15 out · Parcela 3/10" na fatura de novembro) e o que as fontes fazem: no OFX do Nubank a data é a da cobrança, e na Pluggy a `date` muda a cada parcela. Assim a parcela manual e a importada se comportam igual na aba Transações (cada uma aparece no mês da sua cobrança) e no filtro por período.
- **Fatura da parcela k = competência da compra + (k−1) competências.** A competência da compra sai de `competencia_para_data(data_compra)`, a mesma regra da compra à vista (fechamento efetivo, compra no dia do fechamento vai para a seguinte). A fatura **não** sai da data da parcela: com fechamento em dia útil, uma data só avançada pode pular uma fatura ou cair duas vezes na mesma.
- Cada fatura de parcela é gravada com `obter_ou_criar_fatura` (a fatura só existe quando recebe transação). Uma compra em 24x grava até 24 faturas futuras, com as datas calculadas pela regra do cartão.
- Função pura `data_da_parcela(data_compra, numero)` junto da divisão, com teste dos fins de mês.

### Fechamento que muda leva a compra inteira

Hoje `realocar_compras` (em `cartoes/service.py`) põe cada transação do cartão com data num intervalo na fatura que a regra manda, pela data dela. Com parcelas isso espalharia a compra: a data da parcela 3 não diz em que fatura ela está. A regra passa a ser:

- Transação **sem** `compra_parcelada_id`: como hoje, pela data dela.
- **Compra parcelada:** entra na realocação quando a **data da compra** (`compra_parcelada.data_compra`) está no intervalo; aí a competência da compra é recalculada e **todas** as parcelas vão para competência + (k−1), gravando as faturas que faltarem. As datas das parcelas não mudam, só o `fatura_id`. Parcela cuja data está no intervalo, mas cuja compra não está, fica onde está.
- Ajuste da fatura continua fora (nunca é realocado).

Vale para os dois lugares que chamam a realocação: editar o fechamento de uma fatura e mudar os dias do cartão (a partir do fechamento da fatura atual). Uma compra antiga com parcelas em faturas futuras não se move quando os dias do cartão mudam: as faturas futuras dela só têm as datas recalculadas, como já acontece.

Quando a importação e a Pluggy entrarem, a parcela ligada à fatura pela própria fonte (`billId`, OFX da fatura) fica onde a fonte diz, como a spec de cartões já prevê para as demais transações.

### Compra antiga, já em andamento

Lançar uma compra com data no passado gera **todas** as N parcelas, inclusive as que caem em faturas que já fecharam ou venceram *(minha decisão)*. É o retrato fiel da compra e não exige um campo "a partir da parcela X"; o cálculo do aporte só olha as faturas que vencem daqui para frente. Não há restrição de data além das que o lançamento comum já tem.

### Modelo de dados

**compra_parcelada** (nova; colunas como em `arquitetura.md` §7)

| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| descricao | text | a descrição digitada; as parcelas copiam |
| valor_total | numeric(14,2) | `CHECK > 0` |
| qtd_parcelas | smallint | `CHECK >= 2` (o máximo de 24 fica na API: as fontes podem trazer mais) |
| data_compra | date | a data real no manual e na Pluggy; estimada no OFX |
| data_compra_estimada | boolean | `false` no manual; `server_default false` |
| criado_em, atualizado_em | timestamptz | |

**transacao** ganha:

| coluna | tipo | nota |
|---|---|---|
| compra_parcelada_id | uuid FK → compra_parcelada, null | indexado |
| parcela_numero | smallint null | `CHECK parcela_numero >= 1` |

- `CHECK (compra_parcelada_id IS NULL) = (parcela_numero IS NULL)`: os dois juntos ou nenhum.
- `parcela_numero <= qtd_parcelas` é regra do service (um `CHECK` não enxerga outra tabela).
- **Sem unique em `(compra_parcelada_id, parcela_numero)`** *(minha decisão)*: quando a mesma parcela chegar por duas fontes (OFX e Pluggy), as duas linhas existem até a revisão decidir (`possivel_duplicata_de`), e podem apontar para a mesma compra. O lançamento manual garante a unicidade por construção.
- **Migration que só acrescenta** (tabela nova e duas colunas nulas em `transacao`): o código da versão anterior continua funcionando enquanto o deploy roda a migration. Os `CHECK` são escritos à mão (o autogenerate não os enxerga em coluna acrescentada).
- O model `CompraParcelada` fica em `modulos/transacoes/models.py` (compra parcelada é um agrupamento de transações, não um módulo próprio); `Transacao` ganha o relacionamento com ela, para a saída mostrar o total de parcelas sem consulta por linha.

### API

| Rota | Tag | O quê |
|---|---|---|
| `POST /transacoes/parceladas` | transacoes | Lança a compra parcelada; 201 com a compra e as parcelas. |

- Fica no router de transações *(minha decisão)*: o operationId `transacoes_lancar_parcelada` vira `TransacoesApi.lancarParcelada()` no cliente, sem tag nem classe nova, e o repositório de transações do app já usa essa API.
- **Entrada** `CompraParceladaEntrada`: `conta_id`, `valor_total` (`DinheiroPositivo`), `qtd_parcelas` (2–24), `data_compra`, `descricao` (1–200). O tipo é sempre `despesa` e não vem no corpo.
- **Recusas** (422 com `campos`, pelo `CampoInvalido`): conta inexistente ou desativada (`conta_id`, mesmas mensagens do lançamento comum); conta que não é cartão ("Só compra no cartão de crédito pode ser parcelada.", em `conta_id`); total menor que N centavos (`valor_total`, "Cada parcela precisa ser de pelo menos R$ 0,01.").
- **Saída** `CompraParceladaSaida`: `id`, `descricao`, `valor_total`, `qtd_parcelas`, `data_compra`, `data_compra_estimada` e `parcelas` (lista de `TransacaoSaida`, da 1ª à última).
- Cada parcela entra como o lançamento manual comum: `tipo = despesa`, `fonte = manual`, `status = confirmada`, `descricao_original = descricao` = a descrição digitada (sem "1/3" no texto: o número vem do campo).
- Tudo numa transação de banco: ou a compra entra com todas as parcelas, ou nada entra.
- **`TransacaoSaida` ganha `parcela`**: `{compra_parcelada_id, numero, total}`, nulo fora de compra parcelada. Aparece em `GET /transacoes`, `GET /transacoes/{id}` e no detalhe da fatura, que já usam esse schema.
- Regerar o cliente (`bash scripts/gerar-cliente-api.sh`) no PR que muda o contrato.

### App

Conforme o artboard "Lançamento · Compra no cartão":

- **Lançamento, conta cartão:** o campo de valor passa a se chamar "Valor total" e o campo **Parcelas** (hoje desabilitado, "em breve") vira um seletor ao lado da data: "À vista", "2x" … "24x", com "À vista" como padrão. Com 2x ou mais:
  - ajuda do campo: "3x de R$ 333,33; a 1ª parcela fica com R$ 333,34." (divisão exata: "3x de R$ 100,00."); sem valor válido, sem texto;
  - o quadro "Entra na fatura de …" ganha "A última parcela cai na fatura de janeiro de 2027." (competência da fatura da compra, que já vem de `para-compra`, + N−1 meses);
  - salvar chama `lancarParcelada`; à vista continua chamando o lançamento comum.
- A divisão para o texto é calculada **no app** *(minha decisão)*, numa função pura em Dart com os mesmos casos de teste da função do backend, para o texto acompanhar a digitação sem uma chamada por tecla. O servidor continua sendo quem grava os valores.
- Receita, conta corrente e carteira: sem campo de parcelas (como hoje, ele só aparece com cartão).
- **Detalhe da fatura:** a linha da parcela mostra "15 out · Parcela 3/10" (data da parcela e número). Na aba **Transações**, a linha mostra a conta e o número: "Cartão Exemplo · Parcela 3/10" *(minha decisão: o design não tem essa tela com parcela)*.
- Modelos do app: `Transacao` ganha `parcela` (`numero`, `total`); o repositório converte do cliente gerado, como já faz com os demais campos. Telas e cubits continuam sem importar tipos do cliente gerado.
- Widget tests: Lançamento com parcelas (seletor habilitado só em cartão, texto da divisão, última fatura, salvar parcelado), item com "Parcela N/M" na fatura e em Transações; teste do cubit e da função de divisão.

## Alternativas consideradas

- **Todas as parcelas com a data da compra:** mais simples, mas a aba Transações mostraria as N parcelas no mesmo dia e o mês da compra somaria o total; e ficaria diferente das parcelas importadas. Descartada pelo Yago.
- **Fatura da parcela pela data avançada** (competência de data + k−1 meses): com fechamento em dia útil, a data avançada pode cair duas competências adiante, pulando uma fatura.
- **Parcelas no `POST /transacoes`** (campo `parcelas` opcional): a resposta mudaria de forma conforme a entrada (uma transação ou várias), o que o cliente gerado não representa bem.
- **Rota com tag própria** (`POST /compras-parceladas`, `ParceladasApi`): mais uma classe no cliente sem ganho; não há outras operações de compra parcelada neste card.
- **Prévia da divisão por endpoint:** uma chamada por tecla no valor; a regra é pequena e determinística, e os testes iguais dos dois lados seguram a divergência.
- **Centavo na última parcela** ou distribuído (um centavo nas primeiras): o design decidiu pela 1ª, como os bancos costumam mostrar.
- **Unique `(compra_parcelada_id, parcela_numero)`:** protegeria o manual, mas bloquearia a mesma parcela vinda de duas fontes antes da revisão decidir.

## Consequências

- Nenhuma dependência nova, no backend ou no app.
- `realocar_compras` passa a tratar a compra parcelada como um bloco; os testes de editar fatura e editar cartão ganham casos com parcelas.
- `arquitetura.md` muda: `compra_parcelada` com os `CHECK`, data e fatura da parcela, realocação por compra. `CLAUDE.md` (Fontes de dados → Cartão) ganha a regra da data e da fatura da parcela.
- A importação (S5) e o sync (S7) criam `compra_parcelada` com `data_compra_estimada` conforme a fonte e ligam as parcelas que chegam; elas não passam pela divisão nem pela regra de fatura por deslocamento quando a fonte diz a fatura.
- Parcelas com data no futuro aparecem na aba Transações quando o mês delas chegar (a aba não navega para meses futuros); no mês corrente, uma parcela com dia ainda por vir já aparece, com a data dela.
