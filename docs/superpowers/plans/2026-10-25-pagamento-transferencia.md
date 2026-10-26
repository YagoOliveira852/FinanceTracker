# Pagamento de fatura e transferência — plano de implementação

> **Para agentes:** use superpowers:executing-plans (ou subagent-driven-development) para executar tarefa por tarefa. Passos com checkbox (`- [ ]`).

**Objetivo:** lançar transferência entre contas próprias (par ligado) e pagamento de fatura, derivar o status `paga` e mostrar tudo no app (Lançamento, Transações, fatura).

**Arquitetura:** `transferencia_par_id` em `transacao` (migration que só acrescenta); `POST /transacoes/transferencias` no módulo `transacoes`; `POST /cartoes/{id}/faturas/{competencia}/pagamentos` em `cartoes/faturas.py`, com `valor_pago` agregado como o `valor_calculado` e `status_da_fatura` puro decidindo `paga`. No app, dois formulários novos no Lançamento (cada um com o seu cubit), a linha única da transferência em Transações e os estados paga/parcial/adiantada na fatura.

**Stack:** FastAPI síncrono, SQLAlchemy 2.0, Alembic, Pydantic v2, pytest + testcontainers; Flutter, flutter_bloc (Cubit), freezed, decimal, go_router, cliente gerado `dart-dio`.

**Spec:** `docs/superpowers/specs/2026-10-24-pagamento-transferencia-design.md` (aprovada em 25/10). Leia junto; este plano não repete os motivos.

## Restrições globais

- Dinheiro: `Dinheiro`/`DinheiroPositivo` em todo schema, `NUMERIC(14,2)`, `Decimal` no Dart. Nunca `float`/`double`.
- Migration só acrescenta (coluna nula, unique, dois `CHECK` escritos à mão); `down_revision = "c50e7388d2b1"`.
- Uma tag por rota, sem `_`: `transacoes_transferir` → `TransacoesApi.transferir()`; `faturas_pagar` → `FaturasApi.pagar()`.
- Erros: `CampoInvalido("campo", "mensagem")` → 422, com os textos exatos da spec: "Pague com uma conta corrente ou carteira.", "Para pagar o cartão, use Pagamento de fatura.", "Escolha uma conta diferente da de origem."; conta inexistente/desativada com as mensagens de `lancar` ("Conta não encontrada.", "Esta conta está desativada.").
- Descrições gravadas: "Pagamento de fatura · <nome do cartão>"; transferência sem descrição = "Transferência".
- Nenhuma dependência nova. Dados fictícios ("Cartão Exemplo", "Banco Exemplo", "Conta principal", "Carteira").
- Regerar o cliente (`bash scripts/gerar-cliente-api.sh`) em cada PR que muda o contrato; `flutter analyze` e `flutter test` verdes; telas e cubits não importam o cliente gerado.

## Exemplo de referência dos testes

`HOJE = 2026-10-20` (`tests/utils.py`). Cartão "Cartão Exemplo" fecha dia 3 e vence dia 10, pago pela "Conta principal" (corrente): **outubro** fechou seg 05/10 e vence ter 13/10 (fechada em HOJE); **novembro** fecha ter 03/11 e vence ter 10/11 (a atual, aberta); dezembro fecha qui 03/12. Uma compra em 01/10 entra em outubro.

## Review focus

1. Pagamento numa conta corrente com `fatura_id` não pode aparecer nas compras do detalhe, entrar no `valor_calculado` nem ser movido por `realocar_compras` quando o fechamento de outubro é editado.
2. `pagamento_fatura` gravado na **conta do cartão** (o "Pagamento recebido" que as fontes trarão) não soma no `valor_pago`; `ignorada` também não; `rascunho` soma.
3. Fatura paga que recebe compra nova (ou ajuste para valor real maior) volta a `fechada`; fatura aberta totalmente paga continua `aberta` e, no dia do fechamento, vira `paga`.
4. Transferência recusada (mesma conta, cartão num dos lados, conta desativada) não grava nenhum dos dois lados.
5. No app, em Transações com "Todas", a transferência aparece **uma** vez (lado da saída, "Conta principal → Carteira"); filtrando pela Carteira, aparece o lado da entrada com o mesmo subtítulo, mesmo que a outra conta esteja desativada.

Cada item tem teste na tarefa dona do código (marcado "RF n").

---

## PR 1 — `feat/transferencia-api`: transferência entre contas

### Task 1: coluna `transferencia_par_id`

**Files:**
- Modify: `backend/app/modulos/transacoes/models.py`
- Create: `backend/alembic/versions/2026_10_25_1000-<rev>_transferencia_par.py`
- Test: `backend/tests/integration/test_transferencias_modelo.py`
- Docs: commitar a spec e este plano neste PR

**Interfaces:**
- Produces: `Transacao.transferencia_par_id: Mapped[uuid.UUID | None]` (FK `transacao.id`, unique `uq_transacao_transferencia_par_id`); `Transacao.transferencia_par: Mapped["Transacao | None"]` (relacionamento para o par, carregado junto, sem consulta por linha; `post_update=True` para gravar as duas FKs cruzadas). CHECKs: `ck_transacao_par_so_em_transferencia` (`transferencia_par_id IS NULL OR tipo IN ('transferencia_saida', 'transferencia_entrada')`), `ck_transacao_par_nao_e_ela_mesma` (`transferencia_par_id <> id`).

- [ ] **Step 1: testes que falham**, com a `sessao`: `test_par_em_despesa_e_recusado`, `test_par_igual_a_si_mesma_e_recusado`, `test_dois_lados_nao_apontam_para_o_mesmo_par` (unique), `test_par_ligado_nos_dois_sentidos` (grava saída e entrada, liga as duas, relê e confere `t.transferencia_par.id`).
- [ ] **Step 2:** `cd backend && uv run pytest tests/integration/test_transferencias_modelo.py` → FAIL.
- [ ] **Step 3:** model + `uv run alembic revision --autogenerate -m "transferencia par"`; renomear para o padrão de data, escrever à mão a unique e os dois `CHECK`; docstring "Só acrescenta…" como a migration de compra parcelada; `downgrade` na ordem inversa.
- [ ] **Step 4:** `uv run pytest tests/integration/test_transferencias_modelo.py tests/integration/test_migrations.py` → PASS.
- [ ] **Step 5: commit** `feat: par de transferência na transação` (+ `docs: spec e plano de pagamento e transferência`).

### Task 2: `POST /transacoes/transferencias` e `transferencia` na saída

**Files:**
- Modify: `backend/app/modulos/transacoes/service.py`, `schemas.py`, `router.py`
- Test: `backend/tests/integration/test_transferencias.py`, `backend/tests/integration/test_transacoes.py`
- Regerar: `bash scripts/gerar-cliente-api.sh`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `service.conta_ativa(sessao, conta_id: uuid.UUID, campo: str = "conta_id") -> Conta` (o `_conta_ativa` de hoje, público e com o campo do erro; `lancar` e `lancar_parcelada` passam a usá-lo).
  - `service.transferir(sessao, *, conta_origem_id, conta_destino_id, valor: Decimal, data: date, descricao: str | None) -> tuple[Transacao, Transacao]` (saída, entrada; commit no fim, tudo ou nada). Ordem das recusas: origem (existe, ativa, não cartão), destino (idem), destino ≠ origem.
  - `TransferenciaEntrada` (`extra="forbid"`, `str_strip_whitespace`): `conta_origem_id`, `conta_destino_id`, `valor: DinheiroPositivo`, `data: date`, `descricao: str | None = Field(default=None, max_length=200)`; vazia ou nula → "Transferência".
  - `TransferenciaParSaida`: `par_id`, `conta_origem_id`, `conta_destino_id`; `TransacaoSaida.transferencia: TransferenciaParSaida | None` (montado no mesmo `model_validator` do `parcela`, a partir de `transferencia_par`; origem = a conta do lado `transferencia_saida`).
  - `TransferenciaSaida`: `saida: TransacaoSaida`, `entrada: TransacaoSaida`. Rota `transferir`: `POST /transacoes/transferencias`, 201.

- [ ] **Step 1: testes que falham** (fixtures `corrente`, `carteira`, `cartao` como em `test_faturas.py`):
  - `test_transfere_entre_contas`: "Conta principal" → "Carteira", `"200.00"`, `2026-10-19`, "Saque para a carteira" → 201; `saida.tipo == "transferencia_saida"` na origem, `entrada.tipo == "transferencia_entrada"` no destino, mesmos valor/data/descrição, `manual`/`confirmada`; os dois com `transferencia == {par_id: <o outro>, conta_origem_id, conta_destino_id}`; `GET /contas`: origem −200, destino +200.
  - `test_descricao_padrao` (parametrize sem campo, `null`, `"   "`) → "Transferência".
  - `test_deposito_da_carteira_na_corrente` → 201.
  - `test_transferencia_recusada` (parametrize, RF 4): mesma conta → `conta_destino_id` "Escolha uma conta diferente da de origem."; cartão na origem → `conta_origem_id` "Para pagar o cartão, use Pagamento de fatura."; cartão no destino → `conta_destino_id` (mesma mensagem); origem desativada → `conta_origem_id` "Esta conta está desativada."; destino inexistente → `conta_destino_id` "Conta não encontrada."; `valor` `"0.00"` → 422 em `valor`. Em todos, a contagem de `transacao` não muda.
  - `test_listagem_traz_o_par`: `GET /transacoes` traz os dois lados com `transferencia`; filtrando pela carteira, só a entrada.
  - `test_transferencia_exige_token` → 401.
  - Em `test_transacoes.py`: lançamento comum devolve `"transferencia": None`.
- [ ] **Step 2:** `uv run pytest tests/integration/test_transferencias.py` → FAIL.
- [ ] **Step 3:** implementar; atualizar o comentário de `TransacaoEntrada.tipo` (transferência e pagamento têm rotas próprias).
- [ ] **Step 4:** `uv run pytest` → PASS; `uv run ruff check . && uv run ruff format --check .`; `tests/unit/test_operation_ids.py` verde.
- [ ] **Step 5:** `bash scripts/gerar-cliente-api.sh`; conferir no Dart `TransacoesApi.transferir`, `TransferenciaEntrada.valor` como `String`, `TransacaoSaida.transferencia`.
- [ ] **Step 6: docs** — `docs/arquitetura.md` §7.3 (`transferencia_par_id`: unique, os dois `CHECK`, os dois lados apontam um para o outro; lançamento manual pela rota nova).
- [ ] **Step 7: commit** `feat: transferência entre contas próprias`. Abrir o PR 1.

---

## PR 2 — `feat/pagamento-api`: pagamento e status `paga`

### Task 3: `status_da_fatura` com `paga` (TDD)

**Files:**
- Modify: `backend/app/modulos/cartoes/datas.py`
- Test: `backend/tests/unit/test_datas_fatura.py`

**Interfaces:**
- Produces: `StatusFatura.paga = "paga"`; `status_da_fatura(data_fechamento: date, hoje: date, valor: Decimal, pago: Decimal) -> StatusFatura`.

- [ ] **Step 1: teste de tabela que falha** (fechamento 05/10):

| hoje | valor | pago | status |
|---|---|---|---|
| 04/10 | 100.00 | 100.00 | aberta |
| 05/10 | 100.00 | 0.00 | fechada |
| 05/10 | 100.00 | 100.00 | paga |
| 20/10 | 100.00 | 150.00 | paga |
| 20/10 | 100.00 | 99.99 | fechada |
| 20/10 | 0.00 | 0.00 | fechada |
| 20/10 | 0.00 | 10.00 | paga |

- [ ] **Step 2:** `uv run pytest tests/unit/test_datas_fatura.py` → FAIL.
- [ ] **Step 3:** implementar; os chamadores em `faturas.py` passam `pago = 0` por enquanto (a Task 4 troca).
- [ ] **Step 4:** `uv run pytest` → PASS.
- [ ] **Step 5: commit** `feat: status paga da fatura`.

### Task 4: rota de pagamento, `valor_pago` e `pagamentos`

**Files:**
- Modify: `backend/app/modulos/cartoes/faturas.py`, `faturas_router.py`, `schemas.py`
- Test: `backend/tests/integration/test_pagamentos.py`
- Regerar: `bash scripts/gerar-cliente-api.sh`

**Interfaces:**
- Consumes: Task 3; `transacoes.service.conta_ativa` (Task 2); `service.obter_ou_criar_fatura`.
- Produces:
  - `valores_pagos(sessao, fatura_ids) -> dict[uuid.UUID, Decimal]`: soma dos `pagamento_fatura` `confirmada`/`rascunho` com esse `fatura_id`, só em contas que não são `cartao_credito` (join com `conta`), numa consulta.
  - `ResumoFatura.valor_pago: Decimal` (zero na calculada); `_resumo` passa valor e pago para `status_da_fatura`; `listar` busca os pagos de todas as gravadas numa consulta, como os calculados.
  - `DetalheFatura.pagamentos: list[Transacao]` (os `pagamento_fatura` da fatura, sem ignorados, do mais antigo ao mais recente); `DetalheFatura.transacoes` passa a filtrar `conta_id == cartao.conta_id`.
  - `pagar(sessao, cartao, competencia, *, conta_id, valor: Decimal, data: date, hoje: date) -> DetalheFatura`: `conta_ativa(...)`; conta `cartao_credito` → `CampoInvalido("conta_id", "Pague com uma conta corrente ou carteira.")`; grava a fatura se preciso e a transação (`pagamento_fatura`, `manual`, `confirmada`, descrição "Pagamento de fatura · " + `cartao.conta.nome`); commit; devolve o detalhe. Cartão desativado é aceito.
  - `PagamentoEntrada` (`extra="forbid"`): `conta_id`, `valor: DinheiroPositivo`, `data: date`. `FaturaResumo.valor_pago: Dinheiro`; descrição de `status` atualizada ("Aberta antes do fechamento; depois dele, paga se os pagamentos cobrem o valor, senão fechada."); `FaturaDetalheSaida.pagamentos: list[TransacaoSaida]`.
  - Rota `pagar`: `POST /cartoes/{conta_id}/faturas/{competencia}/pagamentos`, 201, devolve `FaturaDetalheSaida`.

- [ ] **Step 1: testes que falham** (fixtures de `test_faturas.py`, compra de `"100.00"` em 01/10 "Mercado do bairro"):
  - `test_pagamento_total_deixa_paga`: pagar outubro `"100.00"` em 13/10 com a corrente → 201, `status == "paga"`, `valor_pago == "100.00"`, `pagamentos[0]` com `tipo == "pagamento_fatura"`, `conta_id` da corrente e descrição "Pagamento de fatura · Cartão Exemplo"; `transacoes` só com a compra; `valor_calculado == "100.00"`; saldo da corrente −100.
  - `test_pagamento_parcial_continua_fechada`: 40 → `fechada`, `valor_pago == "40.00"`; mais 60 → `paga` e dois em `pagamentos`, em ordem de data.
  - `test_pagar_a_mais_deixa_paga`.
  - `test_pagamento_adiantado_na_aberta` (RF 3): compra de 50 em 20/10 (novembro), pagar novembro 50 → `aberta`, `valor_pago == "50.00"`; com `HOJE` sobrescrito para 03/11 (`app.dependency_overrides[get_hoje]`), `GET` novembro → `paga`.
  - `test_compra_nova_volta_para_fechada` (RF 3): depois do pagamento total de outubro, gravar no banco uma despesa do cartão em 02/10 (`fatura_id` de outubro) → `GET` outubro `fechada`; idem com `POST .../ajuste` `valor_real` 150.
  - `test_pagar_fatura_so_calculada_grava_a_fatura`: dezembro sem compras → 201, fatura gravada, `aberta`.
  - `test_pagamento_fora_das_compras_e_da_realocacao` (RF 1): depois de pagar outubro, `PUT` outubro mudando o fechamento para 02/10 → o pagamento continua com o `fatura_id` de outubro e fora de `transacoes`.
  - `test_valor_pago_conta_rascunho_e_nao_ignorada_nem_cartao` (RF 2): gravar no banco pagamentos de outubro: rascunho 30 na corrente (conta), ignorado 20 na corrente (não conta), confirmado 50 na conta do cartão (não conta) → `valor_pago == "30.00"`.
  - `test_lista_e_contas_mostram_paga`: após pagar outubro, `GET /cartoes/{id}/faturas` traz outubro em `anteriores` com `status == "paga"`; `GET /contas` traz `cartao.fatura_atual.valor_pago == "0.00"`.
  - `test_cartao_desativado_pode_ser_pago`.
  - `test_pagamento_recusado` (parametrize): conta do próprio cartão → `conta_id` "Pague com uma conta corrente ou carteira."; corrente desativada → `conta_id` "Esta conta está desativada."; conta inexistente → `conta_id` "Conta não encontrada."; `valor` `"0.00"` → 422 em `valor`. Nada gravado.
  - `test_pagamento_cartao_inexistente_404`, `test_pagamento_competencia_invalida_422` (`2026-13`), `test_pagamento_exige_token`.
- [ ] **Step 2:** `uv run pytest tests/integration/test_pagamentos.py` → FAIL.
- [ ] **Step 3:** implementar; atualizar o docstring do módulo `faturas.py` (valor pago e status).
- [ ] **Step 4:** `uv run pytest` → PASS (os testes de fatura que já existiam continuam verdes); ruff.
- [ ] **Step 5:** `bash scripts/gerar-cliente-api.sh`; conferir `FaturasApi.pagar`, `FaturaResumo.valorPago` como `String`, `StatusFatura.paga`.
- [ ] **Step 6: docs** — `docs/arquitetura.md`: §6 (pagamento de fatura: uma transação na conta que paga, com `fatura_id`), §7.2 `fatura` (status `paga` derivado, valor pago; tirar "virá dos pagamentos"), §7.3 (`fatura_id` em conta não cartão só no `pagamento_fatura`); `CLAUDE.md` (Fontes de dados → Cartão: pagamento e status `paga`, spec `2026-10-24-pagamento-transferencia-design.md`; "Specs já decididas": pagamento e transferência).
- [ ] **Step 7: commit** `feat: pagamento de fatura e status paga` + `docs: pagamento e transferência na arquitetura`. Abrir o PR 2.

---

## PR 3 — `feat/app-transferencia`: transferência no app

### Task 5: modelo, repositório e cubit da transferência

**Files:**
- Modify: `app/lib/features/transacoes/data/transacao.dart`, `transacoes_repositorio.dart`, `app/test/apoio/transacoes_falso.dart`
- Create: `app/lib/features/transacoes/cubit/transferencia_cubit.dart`
- Test: `app/test/features/transacoes/transacoes_repositorio_test.dart`, `transacoes_cubits_test.dart`

**Interfaces:**
- Produces:
  - freezed `ParTransferencia({required String parId, required String contaOrigemId, required String contaDestinoId})`; `Transacao.transferencia: ParTransferencia?`.
  - freezed `NovaTransferencia({contaOrigemId, contaDestinoId, valor: Decimal, data: DateTime, String? descricao})`.
  - `TransacoesRepositorio.transferir(NovaTransferencia dados) -> Future<Transacao>` (o lado da saída); descrição em branco vai `null`.
  - `TransferenciaCubit(TransacoesRepositorio)`, estado freezed `TransferenciaEstado({enviando, erros: Map<String,String>, erroGeral, Transacao? salva})`; `salvar({String? origemId, String? destinoId, required String valor, required DateTime data, required String descricao})`. Validação local: origem nula → `origem` "Escolha a conta de origem."; destino nulo → `destino` "Escolha a conta de destino."; valor via `validarDinheiro(exigePositivo: true)`. Campos da API → formulário: `conta_origem_id` → `origem`, `conta_destino_id` → `destino`, `valor`, `data`, `descricao`.
  - `TransacoesRepositorioFalso.transferencias` (as recebidas) e `transacaoExemplo(transferencia: ...)`.
  - `TransacoesCubit._agruparPorDia` recebe o filtro: com `contaId == null`, pula `transferenciaEntrada` que tem `transferencia`. `TransacoesEstado.contas` passa a guardar **todas** as contas (nome no subtítulo); os chips de filtro usam só as ativas.
- [ ] **Step 1: testes que falham:** repositório envia `conta_origem_id`/`conta_destino_id`/`valor`/`data` (e `descricao: null` em branco) e lê `transferencia`; cubit chama `transferir`, valida os campos e mapeia o 422 em `conta_destino_id` para `erros['destino']`; `TransacoesCubit` com "Todas" devolve um item para o par e, filtrado pela carteira, o lado da entrada (RF 5).
- [ ] **Step 2:** `dart run build_runner build` + `flutter test test/features/transacoes` → FAIL; implementar → PASS.
- [ ] **Step 3: commit** `feat(app): transferência no repositório e no cubit`.

### Task 6: formulário da transferência e linha única

**Files:**
- Create: `app/lib/features/transacoes/ui/formulario_transferencia.dart`
- Modify: `app/lib/features/transacoes/ui/lancamento_tela.dart`, `item_transacao.dart`, `transacoes_tela.dart`, `app/lib/features/transacoes/cubit/lancamento_cubit.dart` (o `assert` de `escolherTipo` aceita os quatro tipos), `app/lib/app/router.dart` (a rota do Lançamento cria também o `TransferenciaCubit`)
- Test: `app/test/features/transacoes/transacoes_telas_test.dart`

**Interfaces:**
- Consumes: Task 5; `ContasCubit` (correntes e carteiras ativas).
- Produces: chip "Transferência" habilitado; `FormularioTransferencia` com De, `IconButton` "Inverter origem e destino" (`Icons.swap_vert_rounded`), Para (sem a conta de De), Valor, Data, "Descrição (opcional)" com dica "Transferência", o aviso da spec e "Salvar". Pagamento de fatura continua "em breve" até o PR 4. `ItemTransacao` aceita o subtítulo pronto; `TransacoesTela` monta "Conta principal → Carteira" pelo `transferencia` (nome por `estado.nomeDaConta`, que agora cobre desativadas).
- [ ] **Step 1: widget tests que falham:** escolher Transferência mostra De/Para e o aviso; Para não oferece a conta de De; inverter troca as duas; salvar chama `transferir` com a descrição em branco como `null` e fecha devolvendo `true`; erro da API em `conta_destino_id` aparece no Para; Transações "Todas" com o par mostra uma linha "Conta principal → Carteira" sem sinal; filtro Carteira mostra a mesma linha; conta de destino desativada continua com o nome (RF 5).
- [ ] **Step 2:** `flutter test` → FAIL; implementar → PASS; `flutter analyze` limpo. Atualizar o docstring do Lançamento.
- [ ] **Step 3: commit** `feat(app): transferência no lançamento e linha única em Transações`. Abrir o PR 3.

---

## PR 4 — `feat/app-pagamento`: pagamento e fatura paga no app

### Task 7: modelo, repositório, regras e cubit do pagamento

**Files:**
- Modify: `app/lib/features/faturas/data/fatura.dart`, `faturas_repositorio.dart`, `app/test/apoio/faturas_falso.dart`
- Create: `app/lib/features/faturas/data/pagamento.dart`, `app/lib/features/faturas/cubit/pagamento_cubit.dart`
- Test: `app/test/features/faturas/faturas_repositorio_test.dart`, `app/test/features/faturas/pagamento_test.dart`

**Interfaces:**
- Produces:
  - `StatusFatura.paga`; `ResumoFatura.valorPago: Decimal` e getter `aPagar` (= `valor − valorPago`, nunca negativo); `DetalheFatura.pagamentos: List<Transacao>`.
  - freezed `NovoPagamento({contaId, valor: Decimal, data: DateTime})`; `FaturasRepositorio.pagar(String cartaoId, DateTime competencia, NovoPagamento dados) -> Future<DetalheFatura>`.
  - Em `pagamento.dart`, funções puras: `List<ResumoFatura> faturasParaPagar(ListaFaturas lista, {DateTime? incluir})` (as anteriores `fechada`, da mais antiga para a mais recente, depois a atual; `incluir` acrescenta essa competência de `lista.emOrdem` se faltar); `ResumoFatura faturaPadrao(List<ResumoFatura> opcoes, {DateTime? incluir})` (a de `incluir`, senão a 1ª `fechada`, senão a atual); `DateTime dataPadraoDoPagamento(ResumoFatura f, DateTime hoje)` (a menor entre `dataVencimento` e `hoje`).
  - `PagamentoCubit(FaturasRepositorio, {DateTime Function()? hoje})`, estado freezed `PagamentoEstado({String? cartaoId, List<ResumoFatura> faturas, DateTime? competencia, carregando, enviando, erros, erroGeral, DetalheFatura? salvo})`, getter `fatura`; métodos `escolherCartao(String cartaoId, {DateTime? competencia})` (carrega a lista, escolhe a padrão), `escolherFatura(DateTime competencia)`, `salvar({String? contaId, required String valor, required DateTime data})`. Validação: sem conta → `conta_id` "Escolha a conta que paga."; valor positivo. A tela preenche Valor (`aPagar`, vazio se zero) e Data (`dataPadraoDoPagamento`) quando a fatura escolhida muda.
- [ ] **Step 1: testes que falham:** repositório envia `conta_id`/`valor`/`data` à rota da competência e lê `valor_pago`, `paga` e `pagamentos`; `faturasParaPagar` (outubro fechada + novembro atual; paga fica fora; `incluir` de uma paga a acrescenta); `faturaPadrao`; `dataPadraoDoPagamento` (vencimento 13/10 com hoje 20/10 → 13/10; vencimento 10/11 com hoje 20/10 → 20/10); cubit escolhe outubro por padrão, troca de fatura, salva chamando `pagar` e mapeia 422 em `conta_id`.
- [ ] **Step 2:** build_runner + `flutter test test/features/faturas` → FAIL; implementar → PASS.
- [ ] **Step 3: commit** `feat(app): pagamento de fatura no repositório e no cubit`.

### Task 8: telas do pagamento e da fatura paga

**Files:**
- Create: `app/lib/features/faturas/ui/formulario_pagamento.dart`, `app/lib/features/faturas/ui/quadro_pagamento.dart`
- Modify: `app/lib/features/transacoes/ui/lancamento_tela.dart`, `app/lib/features/faturas/ui/fatura_tela.dart`, `chip_status.dart`, `app/lib/features/contas/ui/nova_conta_tela.dart` (`tipoInicial`), `app/lib/app/router.dart`
- Test: `app/test/features/faturas/faturas_telas_test.dart`, `app/test/features/transacoes/transacoes_telas_test.dart`

**Interfaces:**
- Consumes: Task 7; `ContasCubit`.
- Produces:
  - `LancamentoTela({contaInicial, PagamentoInicial? pagamentoInicial})`, com `class PagamentoInicial { cartaoId; competencia }`: abre em Pagamento de fatura com o cartão fixo (mesmo desativado).
  - Rota nova `/mais/contas/cartao/:id/fatura/:competencia/pagar` (`parentNavigatorKey: chaveRaiz`), que cria `LancamentoCubit`, `TransferenciaCubit` e `PagamentoCubit` como a rota do Lançamento e devolve `true` ao salvar; a fatura recarrega.
  - `FormularioPagamento`: Cartão (cartões ativos), Fatura ("Outubro · fechada · vence ter, 13 out"), ajuda "Valor da fatura: R$ …", Pagar com (correntes e carteiras ativas, padrão `cartao.contaPagamentoId`) com a ajuda da spec, Valor com a ajuda da spec, Data, o aviso "Não conta como gasto: as compras já entraram no cartão." e "Salvar pagamento". Sem cartão ativo: o aviso "Nenhum cartão ativo" com "Cadastrar cartão" (`context.push(rotaNovaConta, extra: TipoConta.cartaoCredito)`), campos e botão desabilitados.
  - `NovaContaTela({TipoConta? tipoInicial})`; a rota `contas/nova` lê o `extra`.
  - `QuadroPagamento(Transacao pagamento, {required String nomeDaConta, required String rotulo})`: "Paga em qua, 9 set" / "Pagamento em …" / "Pagamento adiantado em …" · conta · valor.
  - `FaturaTela`: paga = chip "Paga", "Valor da fatura", "Confere com o valor informado pelo banco." quando informado = calculado, um `QuadroPagamento` por pagamento, "Fechou"/"Venceu", sem botão; fechada com `valorPago > 0` = "Falta pagar" grande, "De R$ … da fatura. Pagando o restante, ela fica paga.", quadros; aberta com pagamento = "Falta pagar R$ … até agora. Compras novas ainda entram nesta fatura." e quadros "Pagamento adiantado em …". "Registrar pagamento" vira `FloatingActionButton.extended` (fechada, inclusive parcial) e abre a rota `pagar`; sai o `SeloEmBreve`. `ChipStatus` ganha `paga` ("Paga", estilo de sucesso, ícone `check_circle`).
- [ ] **Step 1: widget tests que falham:** Lançamento → Pagamento de fatura mostra outubro por padrão com "Valor da fatura: R$ 100,00", Valor 100,00 e Data 13/10; trocar para novembro muda Valor e Data (hoje); salvar chama `pagar` com a conta de pagamento do cartão; sem cartão ativo mostra "Nenhum cartão ativo" e "Salvar pagamento" desabilitado; fatura paga mostra "Paga", "Paga em ter, 13 out" e não tem "Registrar pagamento"; fechada com pagamento parcial mostra "Falta pagar", "R$ 60,00" e o botão; aberta com pagamento mostra "Pagamento adiantado em"; "Registrar pagamento" abre o formulário com o cartão e a fatura escolhidos; lista de faturas mostra o chip "Paga"; "Cadastrar cartão" abre a Nova conta em Cartão de crédito.
- [ ] **Step 2:** `flutter test` → FAIL; implementar → PASS; `flutter analyze` limpo; docstrings do Lançamento e da fatura sem "em breve" para pagamento.
- [ ] **Step 3: commit** `feat(app): pagamento de fatura e fatura paga`. Abrir o PR 4.

## Fechamento

- [ ] Depois de cada merge (pelo Yago): `gh run list --workflow deploy --limit 3` verde (o PR 1 aplica a migration).
- [ ] Card "S3 · Pagamento de fatura e transferência entre contas" em "Concluído" com comentário-resumo (PRs, decisões, telas novas do canvas).
- [ ] Explicação curta e perguntas de entrevista anotadas na pasta de notas (`s3-pagamento-transferencia.md`).
