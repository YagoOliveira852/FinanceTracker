# Importação de extratos OFX

**Status:** proposta em 2026-10-28, a partir do design aprovado em 27/10 (página "Importação" do canvas, 11 telas; card "S4 · Design · Importação") e do card "S5 · Importação OFX (Nubank conta e cartão) com deduplicação". Decisões em aberto respondidas pelo Yago em 28/10.

## Contexto

A revisão (S4) já trata rascunhos, duplicatas e pagamentos de fatura, mas nada ainda cria rascunhos: as fontes chegam agora. A spec `2026-10-19-revisao-classificacao-design.md` registrou os formatos das amostras do Nubank e as regras de `id_externo`; esta spec decide o resto: o fluxo de importação, o que cada linha do OFX vira, o critério de possível duplicata, o desfazer e o contrato da API e do app.

## Objetivos

- Importar o OFX do extrato da conta (`BANKMSGSRSV1`) e o da fatura do cartão (`CREDITCARDMSGSRSV1`) do Nubank, com um parser OFX genérico.
- Idempotência em dois níveis: o arquivo (`hash_arquivo`) e cada linha (`conta_id, fonte, id_externo`).
- Marcar possível duplicata contra o que já estava no app (lançamento manual ou outra fonte).
- Gravar os dados de fatura e o saldo do extrato que o arquivo traz.
- Desfazer uma importação enquanto nada dela foi confirmado.
- No app: escolher o arquivo pelo seletor ou recebê-lo pelo Compartilhar do Android, ver o resumo, o histórico e desfazer.

## Fora do escopo

- CSV do Mercado Pago: o formato ainda não foi coletado (arquitetura §9). A tela já o cita; até o card dele, um CSV recebe "formato não reconhecido".
- CSV e PDF do Nubank (decisão da spec da revisão: Nubank só por OFX).
- Sync da Pluggy (S7): reaproveita o critério de duplicata daqui; o `status = erro` de `importacao` fica para ele.
- Prévia antes de gravar (decisão do design: importa direto e oferece desfazer).

## Decisões

### Fluxo

*(Decisões do design, 27/10.)*

- **Uma chamada só:** `POST /importacoes` (multipart: `arquivo` + `conta_id`) lê o arquivo inteiro, grava e devolve o resumo. Não há prévia: o erro de conta se corrige com "Desfazer".
- **Tudo ou nada:** qualquer erro de leitura ou validação = nada gravado, nem a linha de `importacao` nem o `hash_arquivo`; o arquivo pode ser corrigido e reenviado.
- **Arquivo já importado** (mesmo SHA-256 dos bytes) é aviso, não erro: a resposta é `200` com `ja_importada = true` e o resumo daquela importação (data, conta, novas); o app oferece "Ver importação". O hash é global, independe da conta: se foi na conta errada, desfaz-se aquela.
- **Tamanho máximo:** 5 MB *(minha decisão; um extrato mensal tem ~20 KB, um ano inteiro ~250 KB)*. Maior que isso = 422 no campo `arquivo`.

### Arquivo × conta

- O app reconhece o OFX de fatura pela marca `CREDITCARDMSGSRSV1` **só para sugerir** a conta; o servidor valida de novo:
  - OFX de fatura (`CREDITCARDMSGSRSV1`) → só em conta `cartao_credito`; senão 422 em `conta_id`: "Este OFX é de fatura de cartão. Escolha um cartão."
  - OFX de conta (`BANKMSGSRSV1`) → só em conta `corrente`; senão "Este OFX é de extrato de conta. Escolha uma conta corrente." (a carteira não tem extrato).
  - Conta inexistente ou desativada → 422 em `conta_id`, como no lançamento.
- O tipo do arquivo não é gravado: sai de `fonte` + tipo da conta (OFX em cartão = fatura). É o que o app usa para pré-selecionar a conta da última importação do mesmo tipo.

### Leitura do OFX

Parser em `modulos/importacao/parsers/ofx.py`, **função pura** (bytes → `ExtratoOfx`), sem banco:

- **SGML do OFX 1.x**, com ou sem tag de fechamento nas folhas (o Nubank fecha todas; outros bancos não). Cabeçalho `OFXHEADER:100 … NEWFILEUID` antes de `<OFX>`.
- **Encoding:** UTF-8; se não decodificar, cp1252 (o cabeçalho do OFX de fatura diz `CHARSET:1252`, mas a amostra é ASCII puro e a da conta vem em UTF-8 com acentos).
- **Tipo:** `BANKMSGSRSV1` → extrato de conta; `CREDITCARDMSGSRSV1` → fatura; nenhum dos dois, ou arquivo que não é OFX → "formato não reconhecido" (422 em `arquivo`).
- **Data:** os 8 primeiros dígitos de `DTPOSTED`/`DTSTART`/`DTEND`/`DTASOF` (`aaaammdd`), que já são a data local do banco (`[-3:BRT]`, hora `000000` nas amostras). Sem conversão de fuso: diferente da Pluggy, o OFX não vem em UTC.
- **Valor:** `TRNAMT` com ponto decimal, em `Decimal`; o sentido vem do **sinal** (negativo = saída). O `TRNTYPE` é coerente com o sinal nas amostras e não é usado.
- **Descrição:** `MEMO` (ou `NAME`, se não houver `MEMO`), sem espaços nas pontas. `descricao_original` e `descricao` recebem o mesmo texto.
- **Linha com valor zero** é descartada pelo parser *(minha decisão: `transacao.valor > 0` e ela não muda saldo nem fatura)*.
- Campo obrigatório faltando (`FITID`, `DTPOSTED`, `TRNAMT`), data ou valor ilegível → "formato não reconhecido", com a linha.

### O que cada linha vira

| Arquivo | Linha | `tipo` | Observação |
|---|---|---|---|
| Conta | saída com `MEMO` começando por "Pagamento de fatura" | `pagamento_fatura` | sem `fatura_id`: a revisão escolhe a fatura (situação "pagamento de fatura") |
| Conta | outra saída | `despesa` | |
| Conta | entrada com `MEMO` começando por "Estorno" | `estorno` | |
| Conta | outra entrada | `receita` | transferências entre contas próprias ficam como despesa/receita; a revisão sugere o par |
| Fatura | saída (compra, IOF) | `despesa` | `fatura_id` = a fatura do arquivo |
| Fatura | entrada com `MEMO` começando por "Pagamento recebido" | — | **não importada** *(Yago, 28/10)*: o pagamento já vem do extrato da conta, e a spec de pagamento proíbe linha do lado do cartão; não entra no resumo |
| Fatura | outra entrada | `estorno` | |

Tudo entra com `status = rascunho`, `fonte = ofx`, `importacao_id` da importação e sem categoria (a sugestão é calculada na leitura, como na revisão).

### `id_externo` e FITID repetido

- `id_externo` = `FITID`; a linha cujo `MEMO` começa com `IOF de` usa `FITID:iof` (no Nubank, a compra e o IOF dela compartilham o FITID; o `MEMO` do IOF é `IOF de "<descrição da compra>"`).
- Se depois disso ainda houver `id_externo` repetido no arquivo, **nada é importado**: 422 com as linhas repetidas (data, descrição, valor e FITID de cada uma), para o app mostrar e orientar a baixar o extrato de novo. O app não escolhe sozinho qual descartar.
- **Já importada** = já existe transação com o mesmo `(conta_id, fonte, id_externo)`, **em qualquer status, inclusive ignorada**: a linha fica de fora e conta em "Já importadas".

### Fatura do cartão

- **Qual fatura:** a competência cujo fechamento (gravado, ou calculado pela regra) fica mais perto de `DTEND`, entre a competência de `DTEND` e as vizinhas; empate fica com a mais antiga. *(Minha decisão: a regra do cartão pode errar o fechamento por alguns dias, e `competencia_da_compra(DTEND)` cairia na fatura seguinte nesse caso.)*
- `data_fechamento` = `DTEND`; `valor_informado` = −`BALAMT`, ou 0 se o saldo for credor (`valor_informado >= 0`). Vencimento continua o gravado ou calculado; se ficar antes do novo fechamento, a importação falha com erro em `arquivo` ("O fechamento do arquivo não combina com o cartão").
- O novo fechamento precisa ficar entre os das faturas vizinhas, como na edição de fatura; senão, o mesmo erro.
- **Todas as linhas do arquivo vão para essa fatura**, qualquer que seja a data: é o banco que diz em que fatura a compra está.
- Mudar o fechamento realoca as compras **lançadas à mão** (`realocar_compras`), como a edição de fatura. **Compras das fontes não são realocadas** *(minha decisão)*: a fatura delas veio do banco, não da regra; a data estimada de uma parcela importada nem diria a fatura certa. `realocar_compras` passa a filtrar `fonte = manual`.

### Parcelas

- `MEMO` terminando em ` - Parcela N/M` (N ≤ M, M ≥ 2) é parcela. O `DTPOSTED` é a data da cobrança.
- A transação recebe `compra_parcelada_id` e `parcela_numero = N`. A compra (`compra_parcelada`) é reaproveitada se já existir uma do mesmo cartão com a mesma descrição (sem o sufixo), o mesmo M, sem parcela N e com data da compra até ±3 dias da estimada; senão nasce uma nova com:
  - `descricao` = `MEMO` sem o sufixo;
  - `data_compra` = `DTPOSTED` recuada N−1 meses (dia que não existe vira o último do mês, como `data_da_parcela`), `data_compra_estimada = true`;
  - `valor_total` = valor da parcela × M (também estimado: a 1ª parcela pode ter o centavo a mais).
- A data estimada é editável na revisão (quando a edição de transação existir); quando a mesma compra vier pela Pluggy, o `purchaseDate` real a substitui (spec `2026-10-19-pluggy-spike`).

### Saldo do extrato (`snapshot_saldo`)

*(Yago, 28/10.)*

- O OFX de conta traz `LEDGERBAL` (`BALAMT` + `DTASOF`): vira `snapshot_saldo` com `fonte = ofx` e **`importacao_id`** da importação, só para conferência. O OFX de fatura não gera snapshot (o cartão não tem saldo; o `BALAMT` dele é a fatura).
- Já existe snapshot da conta naquela data → o novo **substitui** o valor e passa a ser desta importação.
- A tabela nasce agora, só com `conta_id` (obrigatório): os investimentos ainda não existem. Quando chegarem, entram `investimento_id`, `conta_id` vira nulo, o `CHECK` de "um dos dois" e o unique passa a `(conta_id, investimento_id, data)` com `NULLS NOT DISTINCT` (Postgres 16).

### Possível duplicata

*(Yago, 28/10. É a spec de deduplicação entre fontes que estava prevista; a Pluggy, na S7, usa a mesma regra.)*

- Uma linha **nova** é possível duplicata de uma transação existente quando: **mesma conta**, **mesmo valor**, **mesmo sentido** (entrada/saída), **datas até ±2 dias**, a existente é de **outra fonte** (inclusive `manual`), **não está ignorada** e não é ela própria uma possível duplicata.
- **Um para um:** cada existente casa com uma nova só, e vice-versa; vence a menor diferença de dias, depois a data e o id (resultado sempre o mesmo). Função pura em `importacao/duplicatas.py`, nos moldes de `revisao/pareamento.py`.
- A nova entra como rascunho com `possivel_duplicata_de` = a existente e aparece na revisão como duplicata (já implementada). Nada é fundido automaticamente.
- Mesma fonte não é comparada: duas compras iguais no mesmo dia, com FITIDs diferentes, são duas compras.

### Desfazer

*(Decisões do design, 27/10; fatura e snapshot: Yago, 28/10.)*

- `DELETE /importacoes/{id}` só enquanto **nenhuma** transação da importação está confirmada; senão 409 "Não dá mais para desfazer: há transações desta importação já confirmadas."
- Apaga as transações da importação (rascunhos e ignoradas), as compras parceladas que ficaram sem parcela, o snapshot da importação e a linha de `importacao`, o que libera o `hash_arquivo`. É a única exceção ao "nada é apagado" da revisão: só rascunhos que vieram daquele arquivo, e a idempotência continua valendo porque o arquivo pode voltar inteiro.
- Referências de fora somem junto: `possivel_duplicata_de` de outras transações apontando para uma apagada vira nulo (FK `SET NULL`, já existe); `par_recusado` cai em cascata. Rascunho não tem par de transferência nem fatura paga (só a revisão grava isso, ao confirmar).
- **Fatura:** a importação guarda `fatura_id`, o valor e o fechamento que a fatura tinha **antes** e os que ela gravou. O desfazer restaura os anteriores (e realoca as compras manuais) **só se a fatura ainda estiver com os valores desta importação**; se algo mudou depois (edição manual, outra importação), fica como está. Fatura criada pela importação volta ao calculado (valor nulo, fechamento da regra) e continua gravada, sem efeito.

### Resumo e histórico

`ImportacaoSaida` (resposta do `POST`, do `GET /importacoes/{id}` e item de `GET /importacoes`):

- `id`, `criado_em`, `nome_arquivo`, `fonte`, `conta` (id, nome, tipo), `periodo_inicio`/`periodo_fim` (`DTSTART`/`DTEND`);
- `qtd_novas` (gravadas, sem as possíveis duplicatas), `qtd_possiveis_duplicatas`, `qtd_ja_importadas` (as três gravadas na importação), `qtd_parcelas`;
- `qtd_confirmadas` e `qtd_pendentes` (rascunhos), **calculadas na leitura**: o resumo aberto pelo histórico mostra "12 já confirmadas, 9 ainda na Revisão";
- `pode_desfazer` = nenhuma confirmada;
- `saldo_extrato` (valor e data do snapshot, se houver) e `fatura` (competência, valor informado e fechamento gravados), conforme o tipo do arquivo.

O `POST` devolve `201` com o resumo, ou `200` com `ja_importada = true` e o resumo da importação anterior. O histórico vem do mais recente para o mais antigo.

### API

| Rota | Resposta |
|---|---|
| `POST /importacoes` (multipart: `arquivo`, `conta_id`) | `201` resumo; `200` já importada; `422` arquivo/conta (formato único de erro) ou FITID repetido (com `linhas_repetidas`) |
| `GET /importacoes` | histórico |
| `GET /importacoes/{id}` | resumo; `404` "Importação não encontrada." |
| `DELETE /importacoes/{id}` | `204`; `409` com transação confirmada; `404` |

Tag `importacoes` (operationIds `importacoes_importar`, `importacoes_listar`, `importacoes_obter`, `importacoes_desfazer`). O 422 do FITID repetido é o formato único de erro mais `linhas_repetidas: [{fitid, data, valor, descricao}]` (`ErroImportacao`, declarado na rota): o app mostra as linhas como o design pede, e a formatação de dinheiro e data fica na UI. Upload pelo `UploadFile` do FastAPI; o `python-multipart` já vem com `fastapi[standard]` (sem dependência nova no backend).

### Modelo de dados

- **`importacao`** ganha: `qtd_possiveis_duplicatas`, `qtd_parcelas`; `fatura_id` (FK null), `fatura_valor_antes`, `fatura_fechamento_antes`, `fatura_valor_gravado`, `fatura_fechamento_gravado` (nulos fora do OFX de fatura). `qtd_duplicadas` passa a se chamar `qtd_ja_importadas` (o nome antigo confundia com possível duplicata). `status` (`ok`/`erro`) e `erro` ficam para o sync da Pluggy; a importação de arquivo só grava `ok`.
- **`transacao.importacao_id`** (FK null, indexada).
- **`snapshot_saldo`**: `id`, `conta_id`, `data`, `saldo`, `fonte` (`manual | ofx | pluggy`), `importacao_id` (FK null), unique `(conta_id, data)`.

### App

*(Design aprovado em 27/10.)*

- **Entradas:** Mais → "Importar extrato"; na Revisão, ícone de importar no cabeçalho (lista e vazio) e o botão do estado vazio (hoje "Em breve").
- **Tela "Importar extrato":** formulário único — Arquivo (seletor do Android pelo `file_picker`, filtrando `.ofx`) e Conta de destino, pré-selecionada pela última importação do mesmo tipo de arquivo (OFX de conta ou de fatura, reconhecido no app pela marca `CREDITCARDMSGSRSV1`), com a ajuda "A mesma da última importação de OFX de conta." Embaixo, o histórico; tocar abre o resumo.
- **Processando:** diálogo sem cancelar.
- **Resumo:** Novas, Possíveis duplicatas e Já importadas (linhas zeradas somem, menos Novas); conta: saldo do extrato; cartão: parcelas e fatura. "Ir para a Revisão" e "Desfazer importação" (com confirmação); sem desfazer, o aviso de quantas já foram confirmadas e "Revisar as N pendentes".
- **Erros:** já importado (aviso com "Ver importação"), FITID repetido (as linhas e a orientação), formato não reconhecido, conta incompatível (no campo).
- **Compartilhar:** o `receive_sharing_intent` recebe `ACTION_SEND` (intent-filter no `AndroidManifest` para OFX e `application/octet-stream`); o app abre a tela já preenchida depois da biometria (app bloqueado; quando ela existir, card próprio) ou do login (sessão expirada) — o `CompartilhadoCubit`, no topo do app, guarda o arquivo até a sessão estar conectada; o cartão do arquivo mostra "Recebido pelo Compartilhar" e o X volta ao Início.
- Dependências novas aprovadas pelo Yago em 28/10: `file_picker` e `receive_sharing_intent`.

## Alternativas consideradas

- **Prévia antes de gravar:** duas chamadas e um estado intermediário no servidor; o desfazer resolve o erro de conta com uma chamada só (decisão do design).
- **Descartar a linha com FITID repetido:** perderia uma compra real em silêncio; o erro explícito força olhar.
- **Gravar o `hash_arquivo` também no erro:** o arquivo corrigido não poderia ser reenviado.
- **Snapshot sem ligação com a importação:** um extrato na conta errada deixaria um saldo errado que o desfazer não tiraria.
- **Desfazer voltando a fatura ao calculado:** perderia uma edição manual feita antes da importação.
- **Duplicata só na mesma data:** o lançamento manual feito no dia seguinte à compra escaparia.
- **Duplicata exigindo descrição parecida:** o manual costuma ter descrição curta e diferente da do banco.
- **"Pagamento recebido" importado como ignorado:** guardaria uma linha que nada usa; o extrato da conta já tem o pagamento.
- **Fatura pela competência da compra em `DTEND`:** erra quando a regra do cartão difere do fechamento real por um ou dois dias.
- **Realocar também as compras importadas:** moveria pela data uma compra cuja fatura o banco já disse.

## Consequências

- Módulo novo `backend/app/modulos/importacao/` (`models.py`, `parsers/ofx.py`, `duplicatas.py`, `service.py`, `schemas.py`, `router.py`) e tabela `snapshot_saldo` (em `contas/models.py`).
- `realocar_compras` passa a mexer só em compras manuais.
- O sync da Pluggy (S7) reaproveita `duplicatas.py` e a tabela `importacao` (uma linha por execução, com `status`).
- No app, feature `importacao` e duas dependências novas (`file_picker`, `receive_sharing_intent`), com intent-filter no `AndroidManifest`.
