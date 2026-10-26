# Pagamento de fatura e transferência entre contas

**Status:** aprovada pelo Yago em 2026-10-25 (spec e as três telas novas). Proposta em 2026-10-24, a partir do design aprovado em 21/10 (página "Cartões e faturas" do canvas: artboards "Lançamento · Transferência", "Lançamento · Pagamento de fatura" e "Fatura · paga", claro e escuro), dos três estados desenhados em 25/10 ("Fatura · Fechada com pagamento parcial", "Fatura · Aberta com pagamento adiantado", "Lançamento · Pagamento sem cartão") e do card "S3 · Pagamento de fatura e transferência entre contas".

## Contexto

Os cards anteriores da S3 (specs `2026-10-23-cartoes-faturas-design.md` e `2026-10-24-compra-parcelada-design.md`, em produção) trouxeram cartão, fatura e compras à vista e parceladas. Faltam os dois movimentos que tiram dinheiro de uma conta sem ser gasto:

- **Pagamento de fatura:** sai da conta corrente, mas as compras já foram contadas no cartão; contar de novo dobraria o gasto do mês.
- **Transferência entre contas próprias:** sai de uma conta e entra em outra; não é gasto nem renda.

O cálculo do aporte (S6) precisa dos dois: o pagamento diz quanto de cada fatura ainda vai sair da conta, e a transferência não pode inflar gasto nem renda. Hoje o app mostra Transferência, Pagamento de fatura e "Registrar pagamento" como "em breve".

O backend já está preparado em parte: os tipos `transferencia_saida`, `transferencia_entrada` e `pagamento_fatura` estão no `CHECK` de `transacao.tipo`; o valor calculado da fatura já deixa pagamento e transferência de fora; `realocar_compras` só mexe nas transações da conta do cartão. A coluna `transferencia_par_id`, prevista em `arquitetura.md`, **ainda não existe** no banco.

## Objetivos

- Lançar um pagamento de fatura: cartão, fatura, conta que paga, valor e data.
- Derivar o status `paga` da fatura a partir dos pagamentos ligados a ela.
- Mostrar a fatura paga (design "Fatura · paga") e habilitar "Registrar pagamento" na fatura fechada.
- Lançar uma transferência entre contas próprias como duas transações ligadas.
- Mostrar a transferência como uma linha só na aba Transações.
- Deixar o modelo pronto para as fontes (S5 OFX, S7 Pluggy) e para a revisão (S4) sem mudança de esquema.

## Fora do escopo

- Pagamento e transferência vindos das fontes (OFX na S5, Pluggy na S7) e a sugestão de par na revisão (S4). Aqui só o lançamento manual; o modelo serve para elas.
- A linha "Pagamento recebido" que as fontes trazem do lado do cartão: a S5/S7 decide como ela entra, desde que não conte duas vezes no status `paga` (ver "Caminho para as fontes").
- Editar ou excluir pagamento e transferência (ainda não há edição nem exclusão de transação no app).
- O que fazer com o crédito que sobra no cartão quando se paga a mais.
- Parcelamento da fatura e pagamento mínimo.

## Decisões

### Pagamento de fatura

*(Confirmado pelo Yago em 24/10.)* O Yago paga por débito automático no dia do vencimento e, em alguns meses, antes.

- **Uma transação só:** `tipo = pagamento_fatura`, na conta que paga, com `fatura_id` = a fatura paga. Não há transação do lado do cartão: o cartão não tem saldo (o app mostra a fatura), e uma segunda linha só criaria o risco de contar duas vezes.
- `fonte = manual`, `status = confirmada`, como todo lançamento manual.
- **Descrição gravada:** "Pagamento de fatura · <nome do cartão>" *(minha decisão: o design mostra "Pagamento de fatura" na lista; com mais de um cartão, o nome diz qual. Fica gravada como texto, então renomear o cartão depois não muda pagamentos antigos)*. Não há campo de descrição no formulário (como no design).
- **Conta que paga:** qualquer conta `corrente` ou `carteira` **ativa**; nunca cartão. O formulário vem com a conta de pagamento do cartão (`cartao.conta_pagamento_id`), e dá para trocar ("Conta de pagamento do cartão; dá para trocar.").
- **Fatura:** qualquer competência do cartão, gravada ou só calculada (a fatura é gravada se ainda não existe, como em `obter_ou_criar_fatura`). Pagar uma fatura ainda aberta é aceito (pagamento antecipado).
- **Cartão desativado:** a fatura dele ainda pode ser paga (a dívida continua). O formulário do Lançamento lista só cartões ativos; a tela da fatura de um cartão desativado continua com "Registrar pagamento".
- **Data = o dia em que o dinheiro sai da conta**, mesmo antes do vencimento *(Yago, 24/10)*. O formulário vem com **a menor entre o vencimento da fatura escolhida e hoje**: registrando depois do débito automático, fica o vencimento; pagando antes, fica hoje. A API aceita qualquer data, como no lançamento comum; uma data futura escolhida à mão já baixa o saldo da conta (o saldo conta toda transação confirmada), como acontece com qualquer lançamento.
- **Valor:** positivo (`DinheiroPositivo`). O formulário vem com **o que falta pagar** (valor da fatura − pago), para que o segundo de dois pagamentos parciais já venha certo. Sem nada a pagar (fatura aberta sem compras), vem vazio.
- **Pagamento a mais é aceito** e a fatura fica paga; o crédito que sobra não é tratado aqui.

### Status `paga`

O status continua derivado, sem coluna (spec de cartões):

1. `aberta` se hoje é antes do fechamento efetivo;
2. senão, `paga` se **valor pago > 0 e valor pago ≥ valor da fatura**;
3. senão, `fechada`.

- **Valor pago** = soma dos `pagamento_fatura` com aquele `fatura_id`, com status `confirmada` ou `rascunho` (`ignorada` fica fora), em contas que não são cartão. Rascunho conta, como no valor calculado e no aporte: o pagamento por débito automático vai chegar das fontes como rascunho, e o dinheiro já saiu. Quando existir `possivel_duplicata_de`, o pagamento marcado fica fora (como no calculado).
- **Valor da fatura** continua sendo o maior entre informado e calculado. Pagamento menor deixa a fatura `fechada` ("Fechada · a pagar"), como decidido no card "S2 · Design · Cartões e faturas".
- **Fatura aberta nunca aparece como paga**, nem com pagamento adiantado que cubra tudo: ela ainda recebe compras. Ao fechar, o status passa direto para `paga` se o que foi pago cobre o valor.
- Fatura fechada de valor zero, sem pagamento, fica `fechada` (o app mostra R$ 0,00 a pagar; caso raro, sem tratamento próprio).
- O status é calculado a cada leitura. Uma compra lançada depois numa fatura paga (ou um ajuste para o valor real maior) pode fazê-la voltar a `fechada`; é o retrato certo.

A função pura `status_da_fatura` (em `cartoes/datas.py`) passa a receber também o valor da fatura e o valor pago; testes de tabela antes do código (TDD), cobrindo os casos acima.

### Transferência entre contas próprias

*(Confirmado pelo Yago em 24/10.)*

- **Duas transações ligadas:** `transferencia_saida` na conta de origem e `transferencia_entrada` na de destino, com o mesmo valor, data e descrição, `fonte = manual`, `status = confirmada`. Cada uma aponta para a outra em `transferencia_par_id`. Entra o par inteiro ou nada.
- **Contas:** `corrente` ou `carteira`, ativas e diferentes. Saque (corrente → carteira) e depósito (carteira → corrente) são transferência. **Cartão é recusado** nos dois lados: pagar cartão é Pagamento de fatura (aviso do design: "Para pagar cartão, use Pagamento de fatura").
- **Descrição opcional**; vazia vira "Transferência" (o placeholder do design).
- Os saldos das duas contas mudam pela regra de sempre (entrada soma, saída subtrai). Não é gasto nem renda.

### Modelo de dados

**transacao** ganha:

| coluna | tipo | nota |
|---|---|---|
| transferencia_par_id | uuid FK → transacao, null | unique (cada lado tem no máximo um par) |

- `CHECK (transferencia_par_id IS NULL OR tipo IN ('transferencia_saida', 'transferencia_entrada'))`: só transferência tem par.
- `CHECK (transferencia_par_id <> id)`: ninguém é par de si mesmo.
- Que os dois lados apontem um para o outro, com sentidos opostos e contas diferentes, é regra do service (um `CHECK` não enxerga a outra linha).
- **Migration que só acrescenta** (coluna nula, unique e os dois `CHECK`, escritos à mão: o autogenerate não enxerga `CHECK`). O código da versão anterior continua funcionando enquanto o deploy roda a migration. Os tipos já estão no `CHECK` de `tipo`: nada a mudar ali.
- Como as duas FKs se referenciam, o service grava as duas linhas e só depois liga os pares (ou usa `post_update` no relacionamento); o como fica para a implementação.
- **`fatura_id` em conta que não é cartão:** passa a existir no `pagamento_fatura` (a fatura paga). Regra do service: em conta não cartão, só `pagamento_fatura` tem `fatura_id`, e o pagamento manual sempre tem. Sem `CHECK` *(minha decisão)*: um pagamento vindo das fontes pode chegar como rascunho antes de a revisão saber de que fatura ele é.
- Sem coluna nova em `fatura`: o valor pago é calculado numa consulta agregada, como o calculado (`valores_calculados`).

### API

Uma tag por rota, sem `_`.

| Rota | Tag | O quê |
|---|---|---|
| `POST /cartoes/{conta_id}/faturas/{competencia}/pagamentos` | faturas | Registra um pagamento da fatura; 201 com o detalhe da fatura. No cliente: `FaturasApi.pagar()`. |
| `POST /transacoes/transferencias` | transacoes | Lança a transferência; 201 com os dois lados. No cliente: `TransacoesApi.transferir()`. |

**Pagamento**

- Entrada `PagamentoEntrada`: `conta_id` (a conta que paga), `valor` (`DinheiroPositivo`), `data`.
- Recusas (422 com `campos`, pelo `CampoInvalido`): conta inexistente ou desativada (`conta_id`, mensagens do lançamento comum); conta que é cartão ("Pague com uma conta corrente ou carteira.", em `conta_id`). Cartão inexistente: 404 "Cartão não encontrado.", como nas outras rotas de fatura. Competência inválida: 422.
- Saída: `FaturaDetalheSaida` da competência, como o ajuste *(minha decisão: a tela da fatura atualiza com a resposta; o Lançamento só fecha)*.

**Transferência**

- Entrada `TransferenciaEntrada`: `conta_origem_id`, `conta_destino_id`, `valor` (`DinheiroPositivo`), `data`, `descricao` opcional (1–200).
- Recusas (422 com `campos`): conta inexistente ou desativada (no campo dela); cartão ("Para pagar o cartão, use Pagamento de fatura.", no campo dele); mesma conta nos dois lados ("Escolha uma conta diferente da de origem.", em `conta_destino_id`).
- Saída `TransferenciaSaida`: `saida` e `entrada` (`TransacaoSaida`).

**Mudanças nos schemas que já existem**

- `TransacaoSaida` ganha `transferencia`: `{par_id, conta_origem_id, conta_destino_id}`, nulo fora de transferência ligada *(minha decisão: com as duas contas, o app escreve "Conta principal → Carteira" mesmo filtrando por uma conta, quando o outro lado não veio na lista)*. Montado como o `parcela`, a partir do relacionamento com o par (carregado junto, sem consulta por linha).
- `FaturaResumo` ganha `valor_pago` (soma acima; zero na fatura só calculada). O status passa a poder ser `paga`; a descrição do campo muda.
- `FaturaDetalheSaida`:
  - `transacoes` continua sendo as compras, ajustes e estornos da conta do cartão (sem os pagamentos, que estão na conta que pagou);
  - ganha `pagamentos`: os `pagamento_fatura` ligados à fatura (sem os ignorados), do mais antigo para o mais recente.
- Contas (`ContaSaida.cartao.fatura_atual`) e a lista de faturas mostram o status novo sem mudança de rota.

**Compatibilidade:** a versão anterior do app não conhece `paga` no enum. Nenhuma fatura fica paga sem um pagamento, e pagamento só se lança pela rota nova (o app novo), então o app antigo não recebe `paga`. Campos novos na saída são ignorados por ele.

Regerar o cliente (`bash scripts/gerar-cliente-api.sh`) em cada PR que mudar o contrato.

### App

Conforme os artboards do canvas.

**Lançamento**

- Chips **Transferência** e **Pagamento de fatura** habilitados. Cada tipo mostra o seu formulário; Despesa e Receita continuam como estão.
- **Transferência:** De, botão "Inverter origem e destino", Para (sem a conta escolhida em De), Valor, Data, Descrição (opcional) e o aviso "Entre contas próprias: não conta como gasto nem como renda. Para pagar cartão, use Pagamento de fatura." As listas têm correntes e carteiras ativas. Salvar chama `transferir`.
- **Pagamento de fatura:** Cartão (cartões ativos), Fatura, Pagar com, Valor, Data e o aviso "Não conta como gasto: as compras já entraram no cartão." Botão "Salvar pagamento".
  - **Fatura:** a lista vem de `GET /cartoes/{id}/faturas`: as anteriores ainda `fechada` (não pagas) e a atual, como "Outubro · fechada · vence ter, 13 out". Padrão: a fechada mais antiga a pagar; sem nenhuma, a atual. Ajuda do campo: "Valor da fatura: R$ …".
  - **Pagar com:** correntes e carteiras ativas, com a conta de pagamento do cartão como padrão. Ajuda: "Conta de pagamento do cartão; dá para trocar."
  - **Valor:** preenchido com o que falta pagar (valor − pago) e atualizado quando a fatura muda. Ajuda: "Preenchido com o valor da fatura. Pagando menos, ela continua fechada."
  - **Data:** preenchida com a menor entre o vencimento da fatura escolhida e hoje, e atualizada quando a fatura muda.
  - **Sem cartão ativo** (artboard "Lançamento · Pagamento sem cartão"): o chip continua habilitado; o aviso "Nenhum cartão ativo — Para registrar um pagamento de fatura, cadastre o cartão primeiro." com o botão "Cadastrar cartão" (abre a Nova conta em Cartão de crédito), os campos desabilitados e "Salvar pagamento" desabilitado.
- Erros por campo vindos da API viram os campos do formulário, como hoje.

**Fatura**

- **Fechada:** botão "Registrar pagamento" habilitado. Abre o Lançamento já em Pagamento de fatura, com o cartão e a competência escolhidos; ao salvar, a fatura recarrega. Aberto assim, o cartão e a fatura vêm escolhidos mesmo fora das listas normais (cartão desativado, competência que não é fechada a pagar nem a atual): o cartão entra na lista como o único do campo, e a competência entra na lista de faturas *(minha decisão)*.
- **Paga:** chip "Paga" (estilo de sucesso), "Valor da fatura", o quadro de cada pagamento ("Paga em qua, 9 set" · conta que pagou · valor), "Fechou" e "Venceu", e as compras, como no artboard "Fatura · paga". Sem "Registrar pagamento".
- **Fechada com pagamento parcial** (artboard "Fatura · Fechada com pagamento parcial", desenhado em 25/10): continua "Fechada · a pagar"; o número grande passa a ser "Falta pagar R$ …", com "De R$ … da fatura. Pagando o restante, ela fica paga." e o quadro de cada pagamento ("Pagamento em …"). Mantém "Registrar pagamento".
- **Aberta com pagamento adiantado** (artboard "Fatura · Aberta com pagamento adiantado"): continua "Aberta" com "Total até agora"; abaixo, "Falta pagar R$ … até agora. Compras novas ainda entram nesta fatura." e o quadro "Pagamento adiantado em …".
- **Lista de faturas e Contas:** o status `paga` aparece com o chip "Paga".

**Transações**

- Transferência ligada aparece como **uma linha só**: título = descrição, subtítulo "Conta principal → Carteira" (origem → destino), valor sem sinal e neutro (como o item já faz para esse tipo).
  - Com o filtro "Todas", os dois lados vêm na lista; o lado de entrada é escondido e fica a linha do lado de saída.
  - Filtrando por uma conta, só vem o lado dela, e o subtítulo é o mesmo.
  - Conta desativada no subtítulo: o nome dela continua aparecendo (o app já tem todas as contas; hoje os chips usam só as ativas).
- Pagamento de fatura: subtítulo = conta que pagou, valor sem sinal (como já está).
- Transferência sem par (das fontes, antes da revisão ligar): linha comum, com a conta.

**Modelos do app:** `Transacao` ganha `transferencia` (par e as duas contas); `StatusFatura` ganha `paga`; o resumo da fatura ganha `valorPago`; o detalhe ganha `pagamentos`. O repositório converte do cliente gerado, como já faz. Telas e cubits continuam sem importar tipos do cliente gerado.

**Testes:** cubits (transferência, pagamento: padrões de fatura, valor e data, erros por campo), repositórios com o adaptador falso, widget tests do Lançamento nos dois tipos, da fatura paga, da fechada com "Registrar pagamento" e com pagamento parcial, e de Transações com a linha única da transferência.

### Caminho para as fontes (S4, S5, S7)

- **Pagamento por débito automático** vem da conta corrente (Pluggy `operationType = PAGAMENTO_FATURA` ou `category = Credit card payment`; OFX "Pagamento de fatura") como rascunho. A revisão o confirma como `pagamento_fatura` e escolhe a fatura (sugestão: a fechada do cartão cuja conta de pagamento é aquela, com vencimento mais próximo da data). Daí em diante conta no status `paga` como o manual.
- **"Pagamento recebido" do lado do cartão** (OFX do cartão, Pluggy no cartão): a S5/S7 decide como grava. Ele não pode entrar como estorno (baixaria o calculado) e não entra no valor pago, que só soma contas que não são cartão.
- **Pares de transferência** das fontes chegam como dois rascunhos soltos; a revisão sugere o par (mesmo valor, sentidos opostos, contas próprias diferentes, até ±2 dias) e grava `transferencia_par_id` nos dois só com confirmação. Nada aqui funde transações automaticamente.

## Alternativas consideradas

- **Pagamento como par de transferência** (saída na corrente, entrada no cartão): dois registros para um fato, e o lado do cartão precisaria ficar fora do calculado e do pago; o tipo `pagamento_fatura` já diz tudo com uma linha.
- **Coluna `status` ou `valor_pago` gravada na fatura:** precisaria ser mantida a cada pagamento, compra e ajuste; derivado não fica desatualizado.
- **Fatura aberta podendo ficar `paga`:** mudaria de volta para aberta a cada compra nova; confunde.
- **Pagamento só da fatura fechada:** o design lista a aberta, e o pagamento antecipado existe.
- **Transferência como uma transação só, com conta de destino:** quebraria a regra de cada linha ser de uma conta, o saldo por conta e a idempotência das fontes (cada lado chega da sua conta).
- **`transferencia_par_id` só num dos lados:** consultas e o app precisariam olhar nos dois sentidos.
- **Rota de pagamento em `/transacoes`** (com cartão e competência no corpo): a fatura já tem as rotas dela, pela competência, e o detalhe na resposta serve a tela da fatura.
- **Juntar as duas linhas da transferência no backend:** a lista deixaria de ser "uma transação por linha" e o filtro por conta ficaria diferente; o app junta com o `transferencia` da saída.

## Consequências

- Nenhuma dependência nova, no backend ou no app.
- Migration nova em `transacao` (coluna, unique, dois `CHECK`).
- `status_da_fatura` muda de assinatura; os testes de datas ganham os casos do `paga`.
- `arquitetura.md` muda: `transferencia_par_id` com as restrições, `fatura_id` no pagamento, status `paga` e valor pago. `CLAUDE.md` (Fontes de dados / Cartão) ganha a regra do pagamento.
- S6 (aporte) usa, para cada fatura que vence até o próximo salário, o que falta pagar: valor − pago, nunca negativo.
- S4/S5/S7 seguem o "Caminho para as fontes".
