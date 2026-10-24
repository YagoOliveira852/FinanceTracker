# Cartões e faturas: fechamento, vencimento e feriados

**Status:** proposta em 2026-10-23, a partir do design aprovado em 21/10 (página "Cartões e faturas" do canvas) e das decisões do card "S3 · Cartões e faturas".

## Contexto

Até a S2 o app só tinha conta corrente e carteira: o cadastro recusava `cartao_credito` e nenhuma transação de cartão existe no banco de produção. A S3 traz o cartão, e com ele as três datas que não podem se confundir: a data da compra, a competência da fatura e a data do pagamento. O cálculo do aporte (S6) depende das faturas que vencem até o próximo salário, então a fatura precisa ter vencimento confiável e valor que não subestime o que vai sair da conta.

Este card cobre cadastro do cartão, faturas (datas, valor, edição) e a compra à vista no cartão. **Compra parcelada** e **pagamento de fatura / transferência** são cards separados da S3: aqui o caminho fica aberto para eles, sem implementá-los.

## Objetivos

- Cadastrar um cartão (conta `cartao_credito`) com conta de pagamento, dia de fechamento, dia de vencimento e limite opcional; editar esses dados depois e desativar (ou reativar) o cartão.
- Toda transação de conta `cartao_credito` tem `fatura_id`, escolhida pela data da compra.
- Fechamento e vencimento calculados pela regra do cartão e ajustados para o próximo dia útil (fim de semana, feriado nacional e Carnaval).
- Ver a lista de faturas do cartão, o detalhe de cada uma (aberta ou fechada) e editar datas e valor informado.
- No lançamento de despesa num cartão, mostrar "entra na fatura de …" antes de salvar.

## Fora do escopo

- Compra parcelada (card próprio): no Lançamento o campo Parcelas aparece como "em breve".
- Pagamento de fatura e transferência (card próprio): o tipo aparece como "em breve" no Lançamento, e o botão "Registrar pagamento" da fatura fechada também. **O status `paga` e a tela da fatura paga entram com esse card**, porque dependem da transação de pagamento (data, conta e valor pago).
- Fatura vinda da Pluggy (`/bills`) ou do OFX: entra com a importação (S5) e o sync (S7); as regras abaixo dizem como elas se encaixam.

## Decisões

### Regra das datas

Valem para qualquer cartão; os dias são dados do cartão, nunca constantes no código.

1. **Competência = mês do vencimento.** A "fatura de novembro" é a que vence em novembro. Se o dia de fechamento é maior que o de vencimento (fecha 28, vence 5), o fechamento cai no mês anterior ao da competência; senão, no mesmo mês.
2. **Dia que não existe no mês** (31 em abril, 30 em fevereiro) vira o último dia do mês.
3. **Ajuste para dia útil:** fechamento e vencimento, se caírem em sábado, domingo ou feriado da tabela `feriado`, passam para o próximo dia útil. *(Decisão do Yago em 23/10; o design mostrava o fechamento sem ajuste e será atualizado.)*
4. **Uma compra entra na primeira fatura cujo fechamento é depois da data da compra.** Compra feita no próprio dia do fechamento (já ajustado) vai para a fatura seguinte, a regra do "melhor dia de compra" dos bancos.
5. Dia de fechamento e de vencimento vão de 1 a 31 e precisam ser diferentes.

Exemplo fictício (fecha dia 3, vence dia 10), competência outubro/2026: fechamento previsto em sáb, 3 out → seg, 5 out; vencimento previsto em sáb, 10 out, e seg, 12 out é feriado → ter, 13 out. Uma compra em 4 out entra na fatura de outubro; uma em 5 out, na de novembro.

As funções de data são **puras** (sem banco, sem I/O) em `backend/app/modulos/cartoes/datas.py`: recebem os dias do cartão, a competência ou a data da compra e o conjunto de feriados, e devolvem datas. Testes de tabela em `tests/unit/`, escritos antes do código (TDD).

### Feriados

- Tabela `feriado` (`data` PK, `descricao`, timestamps). Entram os **feriados nacionais** da biblioteca `holidays` (categoria `public`) **mais a segunda e a terça de Carnaval** (categoria `optional`, filtrada pelo nome): não são feriado nacional oficial, mas os bancos não abrem. Quarta-feira de Cinzas (banco abre ao meio-dia), Corpus Christi e as demais facultativas ficam fora.
- **Seed numa migration com a lista escrita por extenso** (2024 a 2040), gerada uma vez pela biblioteca. É o mesmo princípio das migrations de enum, que copiam os valores em vez de importar o código: a migration não muda quando a biblioteca é atualizada (o Dependabot atualiza dependências sozinho), e produção, dev e testes têm os mesmos feriados.
- Por isso `holidays` entra como **dependência de dev** (`uv add --dev holidays`), não de produção: um teste unitário confere que a lista da migration bate com a biblioteca. Para cobrir anos depois de 2040, gera-se uma migration nova com o mesmo script.
- **Sem falha silenciosa:** se um cálculo precisar de um ano que não está na tabela, o service levanta erro (500 com log), em vez de calcular sem feriados.

Isso refina a spec `2026-10-19-revisao-classificacao` ("só feriados nacionais"): o Carnaval entra porque vencimento segue o calendário bancário.

### Modelo de dados

**cartao** (1:1 com a conta `cartao_credito`)

| coluna | tipo | nota |
|---|---|---|
| conta_id | uuid PK/FK → conta | |
| conta_pagamento_id | uuid FK → conta | conta corrente ativa no cadastro (regra no service) |
| dia_fechamento | smallint | `CHECK` 1–31 |
| dia_vencimento | smallint | `CHECK` 1–31, diferente do fechamento (`CHECK`) |
| limite | numeric(14,2) null | `CHECK > 0` |

**fatura**

| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| cartao_id | uuid FK → cartao | indexado |
| competencia | date | primeiro dia do mês (`CHECK` dia = 1) |
| data_fechamento | date | calculada na criação, editável |
| data_vencimento | date | calculada na criação, editável; `CHECK` depois do fechamento |
| valor_informado | numeric(14,2) null | o que o banco mostra; `CHECK >= 0` |
| unique | (cartao_id, competencia) | |

**Sem coluna `status`** (diferente do que `arquitetura.md` previa): o status é derivado, para não precisar de cron virando "aberta" em "fechada" nem arriscar status desatualizado. Neste card: `aberta` se hoje é antes do fechamento, `fechada` a partir dele. O card de pagamento acrescenta `paga`, derivado dos pagamentos ligados à fatura (pagamento menor que o valor não marca paga).

**transacao** ganha `fatura_id` (uuid FK → fatura, null, indexado). Obrigatório em transação de conta `cartao_credito`: a regra fica no service, porque um `CHECK` não enxerga o tipo da conta. Como não existe transação de cartão em produção, a migration só acrescenta a coluna (compatível com o código da versão anterior, como o deploy exige).

**conta do cartão:** `saldo_inicial = 0` e `data_saldo_inicial` = hoje, sem pedir no formulário (decisão do design: cartão não tem saldo inicial). O `saldo_atual` de um cartão não aparece no app; o que aparece é a fatura atual.

### Fatura gravada só quando precisa

A fatura vira linha no banco quando recebe a primeira transação ou quando é editada. Antes disso, a API a **calcula** pela regra do cartão. Por isso as rotas de fatura usam a **competência** (`2026-11`) e não o id: o app pede "a fatura de novembro" sem saber se ela já existe. Uma `GET` nunca grava.

Quando a fatura existe, as datas gravadas valem; quando não existe, as calculadas. "Fechamento efetivo" de uma competência = o gravado, se houver, senão o calculado. A regra 4 usa o fechamento efetivo.

### Valor da fatura

- **Calculado** = soma das saídas menos soma das entradas das transações da fatura, com status `confirmada` ou `rascunho` (`ignorada` fica fora), sem contar `pagamento_fatura` e transferências (não são compra). Rascunho conta, como no design da fatura aberta e no cálculo do aporte. Quando existir `possivel_duplicata_de`, a transação marcada fica fora.
- **Valor da fatura = o maior entre informado e calculado**; sem informado, o calculado. É o padrão seguro para o aporte enquanto a diferença não é resolvida.
- **Diferença é sempre informada:** informado maior que calculado = lançamentos faltando ("Faltam R$ 45,90 em lançamentos"); calculado maior = provável lançamento a mais ou duplicado ("Lançado R$ 12,00 a mais que o banco informou").

### Ajuste para o valor real

Com diferença, o detalhe da fatura oferece **"Ajustar para o valor real"**: o usuário confirma o valor real (preenchido com o informado, editável) e uma descrição opcional (padrão "Ajuste da fatura") e a API:

1. grava `valor_informado` = valor real;
2. lança na fatura uma transação de ajuste da diferença entre o valor real e o calculado sem o ajuste anterior: `ajuste_saida` se faltava, `ajuste_entrada` se sobrava (`fonte = manual`, `status = confirmada`).

Assim calculado = informado = valor real, e a diferença não some sem rastro: o ajuste fica na lista de compras da fatura, com a descrição que explica a causa. A fatura tem **no máximo um ajuste**: ajustar de novo substitui o anterior, e ajustar quando a diferença já é zero o remove (é o que acontece quando a compra que faltava chega depois pela importação). Os ajustes servem de registro para o Yago ir trazendo os casos e, juntos, eliminar a causa (importação incompleta, duplicata entre fontes, IOF...).

O ajuste da fatura é a transação de tipo `ajuste_entrada`/`ajuste_saida` daquela fatura, com a data do dia em que foi feito; o lançamento manual comum não cria ajuste em cartão. Ajuste **nunca é realocado** quando um fechamento muda: pertence à fatura por definição, não pela data.

### Editar a fatura

`data_fechamento`, `data_vencimento` e `valor_informado` (vazio = não informado). Regras:

- O fechamento novo precisa ficar depois do fechamento efetivo da competência anterior e antes do da seguinte (a ordem das faturas não se inverte); o vencimento, depois do fechamento.
- **Mudar o fechamento realoca as compras** com data entre o fechamento antigo e o novo, aplicando a regra 4 de novo: antecipar o fechamento manda as compras posteriores à nova data para a fatura seguinte (decisão do design); adiar traz de volta para esta as que ficaram antes da nova data. A fatura seguinte é gravada se ainda não existir.
- "Voltar às datas calculadas" no app só preenche o formulário com as datas calculadas, que a API devolve no detalhe.
- Quando a importação e a Pluggy entrarem, uma transação ligada à fatura pela própria fonte (`billId`) fica onde a fonte diz; a realocação por data vale só para as demais.

### Editar e desativar o cartão

- **Editar:** nome, instituição, conta de pagamento, dias de fechamento e de vencimento e limite, com as mesmas validações do cadastro.
- **Mudar os dias vale a partir da fatura seguinte à atual**, como fazem os bancos: a fatura atual (aberta) mantém as datas, e as seguintes, gravadas ou não, passam a usar os dias novos. As faturas seguintes gravadas (ex.: com parcelas) têm as datas recalculadas, e as compras a partir do fechamento da atual são realocadas pela regra 4. Para mudar as datas da atual, edita-se a fatura. Se, com os dias novos, a fatura seguinte fechasse antes da atual, a API recusa (422 em `dia_fechamento`).
- **Desativar** (`conta.ativa = false`): o cartão deixa de aparecer no Lançamento e não recebe transação nova; continua em Contas, numa linha marcada "Desativado", e as faturas continuam visíveis. **Reativar** desfaz. Nada é excluído. Com fatura em aberto ou fechada com valor, o app avisa antes de desativar.
- Não há tela no design: **"Editar cartão" é desenhada no canvas** (página "Cartões e faturas", claro e escuro) e aprovada antes do PR do app que a implementa.

### Lançamento no cartão

`POST /transacoes` aceita conta `cartao_credito` só com tipo `despesa` (compra à vista). Receita num cartão é recusada (422 em `conta_id`); estorno chega com importação e revisão, e o ajuste só pela fatura ("Ajuste para o valor real"). A transação recebe o `fatura_id` da fatura da data (gravando a fatura se preciso) e a resposta passa a trazer `fatura_id`.

### API

Uma tag por rota, sem `_` (o cliente gera `CartoesApi` e `FaturasApi`). Competência na URL no formato `AAAA-MM`; formato inválido = 422.

| Rota | Tag | O quê |
|---|---|---|
| `POST /cartoes` | cartoes | Cadastra conta + cartão: `nome`, `instituicao`, `conta_pagamento_id`, `dia_fechamento`, `dia_vencimento`, `limite` opcional. 422 se a conta de pagamento não for corrente ativa. |
| `PUT /cartoes/{conta_id}` | cartoes | Edita os mesmos campos do cadastro e `ativa` (desativar/reativar). Mudança de dias conforme "Editar e desativar o cartão". Devolve a conta com o cartão. |
| `GET /cartoes/previa?dia_fechamento=&dia_vencimento=` | cartoes | Próxima fatura (a de uma compra feita hoje) para dias ainda não salvos: a prévia da Nova conta. |
| `GET /cartoes/{conta_id}/faturas` | faturas | Atual (a fatura de uma compra feita hoje, gravada ou calculada), próximas (gravadas depois da atual) e anteriores (gravadas antes, da mais recente para a mais antiga). |
| `GET /cartoes/{conta_id}/faturas/para-compra?data=` | faturas | Em que fatura entra uma compra nessa data ("entra na fatura de …"). |
| `GET /cartoes/{conta_id}/faturas/{competencia}` | faturas | Detalhe: datas efetivas e calculadas, explicação do ajuste, status, valores e transações. |
| `PUT /cartoes/{conta_id}/faturas/{competencia}` | faturas | Edita datas e valor informado (grava a fatura se preciso); devolve o detalhe. |
| `POST /cartoes/{conta_id}/faturas/{competencia}/ajuste` | faturas | Ajuste para o valor real: `valor_real`, `descricao` opcional. Cria, substitui ou remove o ajuste da fatura; devolve o detalhe. |

- `conta_id` que não existe ou não é cartão: 404 "Cartão não encontrado." O `PUT` recebe os três campos sempre (o formulário manda tudo; `valor_informado` pode ser `null`), o que evita distinguir "ausente" de "apagar".
- **Resumo de fatura** (lista, prévia, para-compra, Contas): `competencia`, `data_fechamento`, `data_vencimento`, `status`, `valor`, `valor_calculado`, `valor_informado`.
- **Detalhe** = resumo + `fechamento_calculado`, `vencimento_calculado`, `ajuste_fechamento` e `ajuste_vencimento` (`{data_prevista, feriados: [{data, descricao}]}`, nulo se a data prevista já era dia útil), e as transações da fatura (as mesmas de `GET /transacoes`, sem as ignoradas). A frase "Dia 10 caiu num sábado e 12 out é feriado" é montada no app (formatação de data fica na UI).
- `GET /contas` e `GET /contas/{id}`: `ContaSaida` ganha `cartao` (nulo se não for cartão) com `conta_pagamento_id`, os dois dias, `limite` e `fatura_atual` (resumo). A tela de Contas mostra "Fecha 3 nov · vence 10 nov · Fatura atual R$ …" sem outra chamada.
- `TransacaoSaida` ganha `fatura_id`.

Regerar o cliente (`bash scripts/gerar-cliente-api.sh`) a cada PR que mudar o contrato.

### App

Conforme a página "Cartões e faturas" do canvas:

- **Nova conta:** chip "Cartão de crédito" com nome, instituição, conta de pagamento (correntes ativas), dias de fechamento e de vencimento, limite opcional e a prévia "Próxima fatura: …" (pede `GET /cartoes/previa` quando os dois dias são válidos). Sem conta corrente ativa: o aviso "Falta a conta que paga a fatura" com o botão para cadastrar a conta, e o formulário desabilitado.
- **Contas:** seção "Cartões de crédito" com fechamento e vencimento da fatura atual e o valor dela; tocar abre a lista de faturas.
- **Faturas do cartão:** Próximas, Atual e Anteriores, com mês/ano, status, vencimento e valor.
- **Detalhe da fatura:** aberta ("Total até agora", fecha/vence) e fechada (valor da fatura, informado × calculado, aviso da diferença com o botão "Ajustar para o valor real", vencimento ajustado com a explicação). O ajuste aparece na lista de compras como as demais transações.
- **Editar cartão** (a desenhar): os campos do cadastro, aviso de que dias novos valem a partir da próxima fatura, e "Desativar cartão" / "Reativar cartão" com confirmação. Abre pela lista de faturas do cartão. Setas para a fatura anterior e a próxima, entre as da lista. Botão "Registrar pagamento" como "em breve".
- **Editar fatura:** as duas datas, valor informado, "Voltar às datas calculadas" e o aviso de que mudar o fechamento move compras.
- **Lançamento:** Tipo antes da Conta. Despesa lista correntes, carteira e cartões ativos; Receita não lista cartões. Com cartão: "Parcelas" desabilitado ("em breve") e o quadro "Entra na fatura de …" (pede `para-compra` quando a conta ou a data mudam). Transferência e Pagamento de fatura: "em breve".
- Feature nova `features/faturas/` (repositório, cubits, telas); cadastro do cartão fica em `features/contas/` junto da Nova conta.

## Alternativas consideradas

- **Fechamento sem ajuste** (como o design mostrava): descartado pelo Yago em 23/10.
- **Só feriados nacionais oficiais:** o vencimento no Carnaval cairia num dia em que o banco não abre.
- **Gerar o seed de feriados com a biblioteca dentro da migration:** a mesma migration produziria feriados diferentes conforme a versão instalada; um banco criado depois de uma atualização divergiria do de produção.
- **Calcular feriados em tempo de execução, sem tabela:** sem lugar para corrigir uma data à mão e com a biblioteca em produção.
- **Coluna `status` gravada:** precisaria de um job para fechar faturas e poderia ficar desatualizada.
- **Gravar todas as faturas ao cadastrar o cartão (ou por job mensal):** linhas vazias e um job a mais; a fatura calculada resolve.
- **Rotas por id da fatura:** o app precisaria criar a fatura antes de abrir ou editar uma que ainda não tem compras.
- **Ajuste como um campo "valor considerado" na fatura:** resolveria o número, mas a diferença sumiria sem rastro e o calculado continuaria errado para a revisão.
- **Dias novos valendo já para a fatura atual:** uma fatura aberta poderia passar a estar fechada no meio do ciclo, com as compras dela mudando de fatura sem aviso.
- **Cadastro do cartão dentro de `POST /contas`:** misturaria saldo inicial (que o cartão não tem) com dias e conta de pagamento num schema só.

## Consequências

- Dependência nova de dev: `holidays`. Nenhuma dependência nova no app.
- `arquitetura.md` muda: `fatura` sem `status` (derivado), regra das datas, Carnaval na tabela `feriado`, `ContaSaida.cartao`.
- O card de pagamento acrescenta o status `paga` e a ligação do pagamento com a fatura; o de parcelada usa `fatura_para_data` em cada parcela.
- O design da fatura fechada e o da Nova conta mostram o fechamento sem ajuste; o canvas é atualizado para o exemplo seguir a regra.
- Importação (S5) e Pluggy (S7) preenchem `valor_informado` e as datas da fatura a partir da fonte, gravando a fatura da competência certa.
