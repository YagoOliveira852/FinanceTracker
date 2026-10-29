# Revisão: classificação, transferências, feriados e amostras de importação

**Status:** decidida em 2026-10-19; atualizada em 2026-10-26 com as decisões do design da revisão (categorias, regras, par recusado, duplicata) e em 2026-10-27 com as decisões do código da revisão.

## Contexto

A tela de revisão é o coração do app: tudo que não é lançamento manual entra como rascunho e é confirmado ali. Para o uso não depender de disciplina, o app precisa sugerir bem (categoria, pares de transferência) e deixar a decisão final com o usuário.

## Decisão

### Regras de classificação aprendidas

- **Padrão = descrição original normalizada**, por uma função pura e testável (`modulos/categorias/classificacao.py`): sem acentos, minúsculas; saem datas (`12/11`, `12/11/2026`, `2026-11-12`) e toda palavra com dígito (números e códigos como `0349`, `24h`, `*1234`); pontuação vira espaço; saem os termos genéricos dos bancos, como palavra ou expressão inteira ("transferencia enviada pelo pix", "pix enviado", "compra no debito", "pagamento de fatura", "pagamento", "compra", "pix", "estorno", ...; a lista fica no código, com teste). Ex.: `PIX ENVIADO 12/11 PADARIA SAO JOSE LTDA 0349` → `padaria sao jose ltda`. O padrão digitado numa regra manual passa pela mesma função; padrão vazio depois dela é recusado.
- **Casamento:** a regra casa quando o padrão aparece **como palavras inteiras** na descrição normalizada: `posto` casa `posto ficticio`, `bar` não casa `barbearia`.
- **Ordem derivada, sem coluna `prioridade`:** entre as regras que casam, vence a manual antes da aprendida; depois a restrita a uma conta antes da geral; depois o padrão mais longo; por fim a ordem alfabética do padrão (só para o resultado ser sempre o mesmo). A ordem sai dos dados, como o status `paga` da fatura: não há número para manter em dia.
- **Compatibilidade com o tipo:** a regra só sugere se a categoria está ativa e o grupo combina com o tipo da transação: `despesa` e `estorno` ↔ `essencial`/`variavel`; `receita` ↔ `renda`; `aporte` e `resgate` ↔ `investimento`. Transferência, pagamento de fatura e ajuste não têm categoria. O estorno usa a categoria do gasto (o estorno de uma compra no mercado é Mercado). Isso evita o vaivém do Pix com a mesma pessoa nos dois sentidos ("pix enviado fulano" e "pix recebido fulano" viram `fulano`): pode haver uma regra `fulano` de renda e outra de gasto.
- **A sugestão não é gravada:** a revisão a calcula na leitura, então editar uma regra muda as sugestões dos rascunhos na hora. `transacao.categoria_id` só é preenchido quando a categoria é confirmada na revisão ou escolhida no lançamento manual.
- **Confirmar a categoria** de um rascunho (serviço `confirmar_categoria`, usado pela revisão; o "Confirmar em lote" é o caso 2 para cada rascunho):
  1. Nenhuma regra sugeria e o padrão da transação não é vazio → cria a regra **aprendida** com esse padrão, para todas as contas, `vezes_aplicada` = 0. A folha da revisão mostra: "Próximas de '<padrão>' vão sugerir X".
  2. Confirmou a sugestão como veio → `vezes_aplicada` + 1.
  3. **Correção de regra aprendida:** se o padrão da regra é o da transação, a categoria da regra é trocada e `vezes_aplicada` volta a zero ("A regra de '<padrão>' muda de A para B"). Se a regra casou só parte da descrição (padrão mais curto), ela fica como está e nasce uma aprendida com o padrão da transação, que passa a vencer por ser mais longa: corrigir um rascunho não muda a sugestão de todas as outras descrições que contêm o padrão curto.
  4. **Correção de regra manual:** a regra não muda; só a transação fica com a categoria escolhida, e a folha avisa que a regra manual continua (edita-se em Categorias e regras). Regra manual é decisão explícita do usuário.
  5. Padrão vazio (a descrição só tinha termos genéricos, ex.: "Pagamento recebido") → nenhuma regra.
- **Regras manuais** são criadas e editadas em Mais → Categorias e regras. Editar uma aprendida a torna manual (`vezes_aplicada` continua). Excluir apaga a regra: não é dado financeiro, e as transações já classificadas não mudam. Não pode haver duas regras com o mesmo padrão, a mesma conta (ou ambas gerais) e categorias do mesmo tipo de transação; o cadastro recusa no padrão.
- **"Casa com N rascunhos agora":** a tela da regra mostra quantos rascunhos sem categoria ela sugeriria hoje (é a vencedora para eles) e um exemplo; criar ou salvar uma regra devolve o mesmo número.

### Categorias

- Seed versionado com uma lista genérica, sem nada pessoal: **essencial** Mercado, Moradia, Saúde, Transporte; **variável** Alimentação, Assinaturas, Compras, Educação, Lazer; **renda** Salário, Outras receitas; **investimento** Investimento. O usuário renomeia, troca o grupo ou cria outras pelo app.
- **Nome único sem diferenciar maiúsculas.** Sem ícone próprio: o ícone da linha vem do tipo da transação.
- **Grupo editável.** Entre `essencial` e `variavel` (os dois são gasto) a troca é livre; para outro tipo de transação (renda, investimento) só enquanto nenhuma transação usa a categoria, para não deixar uma despesa com categoria de renda.
- **Desativar** tira a categoria das opções (revisão, lançamento, regras novas) e as regras dela param de sugerir; as transações antigas continuam com ela. Categoria nunca é excluída; reativar devolve tudo.
- **Lançamento manual** aceita categoria opcional (ativa e compatível com o tipo), à vista ou parcelada; não cria regra, porque a descrição é do usuário, não do banco.

### Transferências entre contas próprias

- **Sugestão automática de par:** mesmo valor, sentidos opostos, contas próprias diferentes, datas até ±2 dias. O par aparece na revisão e só é ligado (`transferencia_par_id`) com confirmação.
- Depósito de dinheiro físico (`carteira` → `corrente`) também é transferência.
- Nunca fundir automaticamente; mesmo princípio da deduplicação entre fontes.

### Decisões do design da revisão (2026-10-26)

Telas aprovadas na página "Revisão" do canvas. Valem para o card da tela de revisão:

- **Lista:** decisões no topo ("Precisam de você": par, pagamento de fatura, duplicata, sumiu da origem) e os rascunhos comuns por data. O contador (aba e cabeçalho) conta linhas: um par conta 1.
- **Lote:** "Confirmar N sugeridos" confirma só os rascunhos com categoria sugerida; sem categoria e decisões ficam para um a um.
- **Ignorar, remover e descartar** são sempre `status = ignorada`, nunca DELETE: a linha fica no histórico e a idempotência (`conta_id, fonte, id_externo`) impede que volte na próxima importação.
- **Par de transferência:** "Ligar" confirma os dois lados e grava `transferencia_par_id`; "Não é par" grava em `par_recusado` (`saida_id`, `entrada_id`, unique no par) e a sugestão não volta, mas a saída ainda pode parear com outra entrada. Um booleano na transação não serviria: ele bloquearia todos os pares dela, não só aquele.
- **Rascunho marcado como transferência** (campo "Para"): para uma conta sem Open Finance (ex.: carteira), o app cria o outro lado, confirmado e ligado; para uma conta com Open Finance, liga com o rascunho que veio de lá, sem criar (senão o outro lado chegaria duplicado). O critério exato para contas alimentadas só por OFX fica para o card da revisão.
- **Pagamento vindo das fontes:** o usuário escolhe a fatura (sugerida: a fechada do cartão pago por aquela conta, com o vencimento mais próximo) e vê se ela fica paga; "É outra coisa" abre a folha comum.
- **Possível duplicata:** o usuário escolhe qual fica. Ficando com o rascunho, ele entra confirmado com a categoria e a descrição da que foi descartada (que vira `ignorada`).
- **Sumiu da origem:** "Manter" limpa `removida_na_origem_em`; "Remover" a torna `ignorada`.

### Decisões do código da revisão (2026-10-27)

- **Antes das fontes:** a revisão chega antes da importação (S5) e da Pluggy (S7). `transacao.possivel_duplicata_de` e `transacao.removida_na_origem_em` entram com ela e são preenchidas pelas fontes quando elas existirem.
- **Cada rascunho aparece uma vez**, na primeira situação que vale: duplicata pendente (a outra não está ignorada) > lado de um par sugerido > `pagamento_fatura` > rascunho comum. Transação confirmada com `removida_na_origem_em` é "sumiu da origem". O contador soma as decisões e os rascunhos comuns.
- **Par sugerido:** entre rascunhos sem par e sem duplicata pendente, em corrente ou carteira; saída `despesa`/`transferencia_saida` × entrada `receita`/`transferencia_entrada`. Cada transação entra em um par só: vence a menor diferença de dias, depois a data e o id, para o resultado ser sempre o mesmo. Função pura (`revisao/pareamento.py`), calculada na leitura como a sugestão de categoria. "Ligar" troca os tipos para os de transferência, tira a categoria e confirma os dois.
- **O efeito na regra vem do servidor:** ele só depende de a categoria escolhida ser a sugerida ou outra, então cada rascunho traz os dois efeitos possíveis (`prever_efeito`, a mesma função que `aprender` usa) e o app mostra o da escolha. A sugestão depende do tipo (cada tipo combina com outros grupos), então a entrada traz também, em `outros_tipos`, a sugestão e os dois efeitos se for confirmada com o outro tipo (receita ↔ estorno); ao trocar o tipo na folha, a categoria passa à sugestão do tipo novo e o aviso continua certo (2026-10-29).
- **Confirmar exige categoria** quando o tipo tem categoria; a revisão existe para classificar (o lançamento manual continua com categoria opcional). O tipo pode mudar no mesmo sentido entre os que não pedem vínculo: saída → `despesa`; entrada → `receita` ou `estorno`. Transferência e pagamento de fatura têm ações próprias; `aporte`/`resgate` (o Cofrinho do CSV do Mercado Pago) só se confirmam como eles mesmos, com categoria de investimento, e os investimentos os ligam depois (2026-10-29, spec de importação).
- **Conta alimentada por fonte** = tem ao menos uma transação com `fonte` diferente de `manual` (a carteira nunca tem). É o critério do campo "Para": destino sem fonte → o app cria o outro lado, confirmado e ligado; destino com fonte → liga com o rascunho de lá (mesmo valor, sentido oposto, até ±2 dias, sem par, par não recusado, o de data mais próxima) e, se ele ainda não chegou, recusa até chegar. Assim o outro lado nunca entra duplicado.
- **Pagamento das fontes:** as candidatas são, de cada cartão ativo, a fatura atual e as duas anteriores; a sugerida é a fechada do cartão pago pela conta do pagamento com vencimento mais perto da data dele.
- **Duplicata:** ficar com o rascunho só herda categoria e descrição (e o par de transferência ou a fatura paga) se a descartada estava confirmada; se as duas eram rascunho, o que fica vai para a lista comum. "Manter as duas" limpa `possivel_duplicata_de`.
- **Remover um lado de transferência que sumiu da origem** desfaz o par e devolve o outro lado a rascunho, para parear com o que chegou no lugar.
- **Lote:** o app manda os ids que viu; o servidor confirma os que ainda são rascunho comum com sugestão e pula os demais.

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

O fluxo completo (tudo ou nada, desfazer, possível duplicata, fatura e saldo do extrato) está na spec `2026-10-28-importacao-design.md`.

- **Nubank só por OFX**, conta e cartão, com um parser OFX genérico. Não há parser de CSV do Nubank; CSV é usado só para o Mercado Pago. `fonte` passa a ser `manual | ofx | csv_mercadopago | pluggy`.
- **`id_externo` no OFX:** o `FITID`; a linha cujo `MEMO` começa com `IOF de` usa `FITID:iof`. Determinístico entre reimportações. Se ainda restar `FITID` repetido no mesmo arquivo, a importação falha com erro explícito em vez de descartar linha.
- **Dados de fatura vindos do OFX:** `valor_informado` = −`BALAMT`; `data_fechamento` = `DTEND`; vencimento continua calculado pela regra do cartão e editável.
- **Saldo da conta vindo do OFX:** `LEDGERBAL` vira `snapshot_saldo` com `fonte = ofx`, para conferência.
- **Parcelas:** `compra_parcelada.data_compra` é **estimada** recuando N−1 meses a partir da data de cobrança da parcela N, marcada como estimada (`data_compra_estimada = true`) e editável na revisão. Quando a mesma compra vem pela Pluggy, o `purchaseDate` real substitui a estimativa (spec `2026-10-19-pluggy-spike`).

## Alternativas consideradas

- **Padrão = descrição inteira:** nunca casa de novo por causa de datas e códigos.
- **Aprender só após 2 confirmações iguais:** menos sugestões erradas, mais trabalho manual no começo do uso.
- **Coluna `prioridade` nas regras:** o usuário teria de numerar regras e manter os números; a ordem derivada (manual > uma conta > mais longa) resolve os casos reais sem manutenção.
- **Casamento por trecho de texto (substring):** `bar` casaria `barbearia`; por palavras inteiras, não.
- **Gravar a sugestão na transação ao importar:** ficaria velha quando uma regra mudasse; calculada na leitura, está sempre em dia.
- **Correção de regra manual também mudar a regra:** uma escolha pontual na revisão desfaria uma regra que o usuário escreveu de propósito.
- **Booleano "não é par" na transação:** bloquearia todos os pares dela; `par_recusado` recusa só aquele par.
- **Pares de transferência ligados manualmente:** mais trabalhoso e fácil de esquecer, o que dobra gasto e renda.
- **Feriados de Ceará e Fortaleza:** não afetam o vencimento de bancos digitais.
- **Lista de feriados à mão:** sem dependência nova, mas precisa ser mantida todo ano.

## Consequências

- Normalização e pareamento são funções puras com testes de tabela.
- Novas tabelas: `categoria`, `regra_classificacao` (sem `prioridade`) e `par_recusado`; `transacao.categoria_id`, `transacao.possivel_duplicata_de` e `transacao.removida_na_origem_em`.
- `holidays` é dependência nova do backend.
- O cartão do Nubank tem exportação estruturada (OFX), então não depende só da Pluggy; o do Mercado Pago ainda será verificado.
- Um único parser OFX atende conta e cartão do Nubank, o que reduz parsers e fixtures na fase de importação.
- Importar CSV do Nubank fica fora do escopo; se for necessário depois, o `Identificador` do CSV é o mesmo `FITID` do OFX.
