# Compra parcelada — plano de implementação

> **Para agentes:** use superpowers:executing-plans (ou subagent-driven-development) para executar tarefa por tarefa. Passos com checkbox (`- [ ]`).

**Objetivo:** lançar uma compra parcelada no cartão, gerando uma transação por parcela, cada uma na sua fatura, e mostrar "Parcela N/M" no app.

**Arquitetura:** `CompraParcelada` e as funções puras da parcela (`parcelas.py`) ficam no módulo `transacoes`; `POST /transacoes/parceladas` usa `competencia_para_data` e `obter_ou_criar_fatura` de `cartoes/service.py`; `realocar_compras` passa a mover a compra parcelada como um bloco. No app, o Lançamento ganha o seletor de parcelas e o item de transação mostra "Parcela N/M".

**Stack:** FastAPI síncrono, SQLAlchemy 2.0, Alembic, Pydantic v2, pytest + testcontainers; Flutter, flutter_bloc (Cubit), freezed, decimal, cliente gerado `dart-dio`.

**Spec:** `docs/superpowers/specs/2026-10-24-compra-parcelada-design.md` (aprovada em 24/10). Leia junto; este plano não repete os motivos.

## Restrições globais

- Dinheiro: `Dinheiro`/`DinheiroPositivo` em todo schema, `NUMERIC(14,2)`, `Decimal` no Dart. Nunca `float`/`double`.
- Migration só acrescenta (tabela nova e colunas nulas); `CHECK` escritos à mão.
- Rota nova na tag `transacoes` (operationId `transacoes_lancar_parcelada` → `TransacoesApi.lancarParcelada()`).
- Erros: `CampoInvalido("campo", "mensagem")` → 422; textos em pt-BR, exatamente os da spec.
- De 2 a 24 parcelas na API; no banco só `qtd_parcelas >= 2`.
- Nenhuma dependência nova. Dados fictícios ("Cartão Exemplo", "Banco Exemplo", "Fone de ouvido", "Notebook Loja Exemplo").
- Regerar o cliente (`bash scripts/gerar-cliente-api.sh`) no PR que muda o contrato; `flutter analyze` e `flutter test` verdes.

## Exemplo de referência dos testes

`HOJE = 2026-10-20` (`tests/utils.py`). Cartão fecha dia 3 e vence dia 10 (mesmo exemplo do plano de cartões): outubro fecha seg 05/10, novembro ter 03/11, dezembro qui 03/12, janeiro/2027 dom 03/01 → seg 04/01.

- R$ 1.000,00 em 3x, compra em 20/10/2026 ("Fone de ouvido"): parcelas 333,34 / 333,33 / 333,33, datas 20/10, 20/11, 20/12, faturas 2026-11, 2026-12, 2027-01. É o exemplo do design.
- Compra em 31/10/2026 em 4x: datas 31/10, 30/11, 31/12, 31/01/2027.

## Review focus

1. Fechamento antecipado para o dia de uma compra parcelada → a compra inteira vai uma fatura adiante (a 1ª para a seguinte e cada uma das outras junto), nunca só a 1ª.
2. Parcela cuja **data** cai no intervalo realocado, mas cuja **compra** não → fica onde está.
3. Total menor que N centavos (`"0.02"` em 3x) → 422 em `valor_total`, nada gravado; total exatamente N centavos (`"0.03"` em 3x) → três parcelas de 0,01.
4. Falha no meio (ex.: feriado ausente para uma parcela em 2041) → nenhuma parcela, compra ou fatura gravada.
5. No app, trocar a conta de cartão para corrente com "3x" escolhido → o seletor some e o salvar faz lançamento comum (à vista), não parcelado.

---

## PR 1 — `feat/parcelada-modelo`: tabela e regra da parcela

### Task 1: funções puras da parcela (TDD)

**Files:**
- Create: `backend/app/modulos/transacoes/parcelas.py`
- Test: `backend/tests/unit/test_parcelas.py`
- Docs: commitar a spec e este plano neste PR

**Interfaces:**
- Produces: `dividir_em_parcelas(total: Decimal, quantidade: int) -> list[Decimal]`; `data_da_parcela(data_compra: date, numero: int) -> date` (numero começa em 1).

- [ ] **Step 1: testes de tabela, que falham**

```python
@pytest.mark.parametrize(
    ("total", "quantidade", "parcelas"),
    [
        ("1000.00", 3, ["333.34", "333.33", "333.33"]),
        ("300.00", 3, ["100.00", "100.00", "100.00"]),
        ("1.00", 7, ["0.16"] + ["0.14"] * 6),        # resto máximo: N−1 centavos
        ("0.03", 3, ["0.01", "0.01", "0.01"]),        # o mínimo
        ("2499.90", 10, ["249.99"] * 10),
        ("100.01", 2, ["50.01", "50.00"]),
    ],
)
def test_dividir_em_parcelas(total, quantidade, parcelas):
    resultado = dividir_em_parcelas(Decimal(total), quantidade)
    assert resultado == [Decimal(p) for p in parcelas]
    assert sum(resultado) == Decimal(total)

@pytest.mark.parametrize(("data_compra", "numero", "esperada"), [
    (date(2026, 10, 20), 1, date(2026, 10, 20)),
    (date(2026, 10, 20), 3, date(2026, 12, 20)),
    (date(2026, 10, 31), 2, date(2026, 11, 30)),
    (date(2026, 10, 31), 4, date(2027, 1, 31)),
    (date(2027, 1, 31), 2, date(2027, 2, 28)),
    (date(2028, 1, 31), 2, date(2028, 2, 29)),
])
def test_data_da_parcela(data_compra, numero, esperada): ...
```

Mais: `dividir_em_parcelas(Decimal("0.02"), 3)` levanta `ValueError` (o service valida antes; a função não devolve parcela zero).

- [ ] **Step 2:** `cd backend && uv run pytest tests/unit/test_parcelas.py` → FAIL (import).
- [ ] **Step 3: implementar** em `parcelas.py`. Divisão: `base = (total / quantidade).quantize(Decimal("0.01"), rounding=ROUND_DOWN)`, 1ª = `total - base * (quantidade - 1)`. Data: mês somado com o dia limitado ao último do mês (reusar a ideia de `_dia_no_mes` de `cartoes/datas.py`, sem importar função privada).
- [ ] **Step 4:** mesmo comando → PASS; `uv run ruff check . && uv run ruff format --check .`.
- [ ] **Step 5: commit** `feat: divisão e data das parcelas`.

### Task 2: tabela `compra_parcelada` e colunas em `transacao`

**Files:**
- Modify: `backend/app/modulos/transacoes/models.py`
- Create: `backend/alembic/versions/<gerado>_cria_compra_parcelada.py` (down_revision `7b71de313332`)
- Test: `backend/tests/integration/test_compras_parceladas.py` (só modelo nesta task)

**Interfaces:**
- Produces: `CompraParcelada(id, descricao, valor_total, qtd_parcelas, data_compra, data_compra_estimada)` com `ComTimestamps`; `Transacao.compra_parcelada_id: Mapped[uuid.UUID | None]`, `Transacao.parcela_numero: Mapped[int | None]`, `Transacao.compra_parcelada: Mapped[CompraParcelada | None]` (relationship, `lazy="joined"`), `CompraParcelada.parcelas` (relationship ordenada por `parcela_numero`).
- CHECKs (nomes pelo naming convention): `ck_compra_parcelada_valor_total_positivo` (`valor_total > 0`), `ck_compra_parcelada_qtd_parcelas_valida` (`qtd_parcelas >= 2`), `ck_transacao_parcela_numero_valido` (`parcela_numero >= 1`), `ck_transacao_parcela_completa` (`(compra_parcelada_id IS NULL) = (parcela_numero IS NULL)`). `data_compra_estimada` com `server_default=false`.

- [ ] **Step 1: testes que falham**, com a `sessao`: `test_parcela_sem_numero_e_recusada` (transação com `compra_parcelada_id` e `parcela_numero=None` → `IntegrityError`), `test_numero_sem_compra_e_recusado`, `test_qtd_parcelas_menor_que_2_e_recusada`, `test_parcela_numero_zero_e_recusado`, `test_data_compra_estimada_nasce_false`.
- [ ] **Step 2:** `uv run pytest tests/integration/test_compras_parceladas.py` → FAIL.
- [ ] **Step 3:** models + `uv run alembic revision --autogenerate -m "cria compra_parcelada"`; conferir o arquivo e escrever à mão os `CHECK` da coluna acrescentada (o autogenerate não os põe no `add_column`), a FK e o índice `ix_transacao_compra_parcelada_id`; docstring "Só acrescenta…" como a migration de cartão. `downgrade` desfaz na ordem inversa.
- [ ] **Step 4:** `uv run pytest tests/integration/test_compras_parceladas.py tests/integration/test_migrations.py` → PASS (sobe/desce e `alembic check` sem diferença).
- [ ] **Step 5: commit** `feat: tabela compra_parcelada e parcela na transação`. Abrir o PR 1.

---

## PR 2 — `feat/parcelada-api`: lançamento e realocação

### Task 3: `POST /transacoes/parceladas` e `parcela` na saída

**Files:**
- Modify: `backend/app/modulos/transacoes/service.py`, `schemas.py`, `router.py`
- Test: `backend/tests/integration/test_compras_parceladas.py`, `backend/tests/integration/test_transacoes.py` (campo `parcela` nulo)
- Regerar: `bash scripts/gerar-cliente-api.sh` (commitar `openapi.json` e `app/packages/api_client/`)

**Interfaces:**
- Consumes: `dividir_em_parcelas`, `data_da_parcela` (Task 1); `CompraParcelada` (Task 2); `cartoes_service.obter_cartao`, `competencia_para_data`, `obter_ou_criar_fatura`; `mes_seguinte` de `cartoes/datas.py`.
- Produces:
  - `service.lancar_parcelada(sessao, *, conta_id: uuid.UUID, valor_total: Decimal, qtd_parcelas: int, data_compra: date, descricao: str) -> CompraParcelada` (commit no fim; tudo ou nada).
  - `CompraParceladaEntrada` (`extra="forbid"`, `str_strip_whitespace`): `conta_id`, `valor_total: DinheiroPositivo`, `qtd_parcelas: int = Field(ge=2, le=24)`, `data_compra: date`, `descricao: str = Field(min_length=1, max_length=200)`.
  - `ParcelaSaida`: `compra_parcelada_id: uuid.UUID`, `numero: int`, `total: int`.
  - `TransacaoSaida.parcela: ParcelaSaida | None` (montado de `compra_parcelada_id`, `parcela_numero` e `compra_parcelada.qtd_parcelas`; ex.: `model_validator(mode="before")` ou campo calculado — escolha do implementador, desde que o schema OpenAPI fique `ParcelaSaida | null`).
  - `CompraParceladaSaida`: `id`, `descricao`, `valor_total: Dinheiro`, `qtd_parcelas`, `data_compra`, `data_compra_estimada`, `parcelas: list[TransacaoSaida]`.
  - Rota `lancar_parcelada` em `router.py`: `POST /transacoes/parceladas`, 201.

- [ ] **Step 1: testes que falham** (fixtures `corrente` e `cartao` copiadas de `test_faturas.py`, como os outros arquivos fazem):
  - `test_lanca_parcelada_no_exemplo_do_design`: 3x de `"1000.00"` em `2026-10-20` → 201; `parcelas` com `valor` `333.34/333.33/333.33`, `data` `2026-10-20/2026-11-20/2026-12-20`, competências das faturas `2026-11-01/2026-12-01/2027-01-01`, `parcela` `{numero: k, total: 3}`, todas `despesa`, `manual`, `confirmada`, descrição "Fone de ouvido".
  - `test_fatura_da_parcela_e_por_deslocamento`: compra em 31/10 4x → datas da tabela do exemplo e competências 2026-11 … 2027-02 (sem pular nem repetir).
  - `test_compra_no_dia_do_fechamento_comeca_na_seguinte`: compra em 03/11 2x → 2026-12 e 2027-01.
  - `test_compra_antiga_gera_todas_as_parcelas`: compra em 2026-06-15 10x → 10 transações, a 1ª em fatura passada.
  - `test_faturas_mostram_as_parcelas`: `GET /cartoes/{id}/faturas/2026-12` lista a parcela 2 com `parcela.numero == 2`; `valor_calculado` da fatura inclui a parcela.
  - `test_parcelada_recusada` (parametrize): conta corrente → `conta_id` "Só compra no cartão de crédito pode ser parcelada."; cartão desativado → `conta_id` "Esta conta está desativada."; conta inexistente → `conta_id` "Conta não encontrada."; `"0.02"` em 3x → `valor_total` "Cada parcela precisa ser de pelo menos R$ 0,01."; `qtd_parcelas` 1 e 25 → 422 em `qtd_parcelas`. Em todos, nenhuma linha nova em `compra_parcelada` e `transacao`.
  - `test_falha_no_meio_nao_grava_nada`: compra em 2040-06-15 em 24x (parcelas em 2041+, sem feriados na tabela) → erro, e contagem de `compra_parcelada`, `transacao` e `fatura` igual à de antes.
  - `test_parcelada_exige_token` (client sem Bearer → 401).
  - Em `test_transacoes.py`: o lançamento comum devolve `"parcela": None`.
- [ ] **Step 2:** `uv run pytest tests/integration/test_compras_parceladas.py` → FAIL.
- [ ] **Step 3: implementar.** Validação de conta igual a `lancar` (extrair um auxiliar privado em vez de duplicar), depois `cartao_credito`, depois `valor_total >= qtd × 0,01`. Competência da compra uma vez; parcela k em `mes_seguinte` aplicado k−1 vezes. Sem commit até o fim; em erro, `sessao.rollback()` antes de propagar (o teste 4 do review focus confere; nos testes, a sessão em `create_savepoint` volta só até o último commit, então as fixtures continuam lá). Atualizar o docstring do módulo de schemas/serviço onde dizia "só despesa ou receita".
- [ ] **Step 4:** `uv run pytest` (tudo) → PASS; ruff; `uv run pytest tests/unit/test_operation_ids.py` confirma o operationId.
- [ ] **Step 5:** `bash scripts/gerar-cliente-api.sh`; conferir no Dart gerado `TransacoesApi.lancarParcelada`, `CompraParceladaSaida.valorTotal` como `String` e `TransacaoSaida.parcela`.
- [ ] **Step 6: commit** `feat: lançamento de compra parcelada no cartão`.

### Task 4: realocação leva a compra inteira

**Files:**
- Modify: `backend/app/modulos/cartoes/service.py` (`realocar_compras`)
- Test: `backend/tests/integration/test_compras_parceladas.py`

**Interfaces:**
- Consumes: `CompraParcelada`, `Transacao.compra_parcelada_id/parcela_numero`.
- Produces: `realocar_compras(sessao, cartao, de, ate)` com a mesma assinatura; agora (a) a consulta por data exclui transações com `compra_parcelada_id`; (b) busca as compras parceladas do cartão (via join com `transacao.conta_id`) com `data_compra` em [`de`, `ate`) e, para cada uma, põe a parcela k na fatura de `competencia_para_data(data_compra)` + (k−1) competências.

- [ ] **Step 1: testes que falham** (helper `_editar` como o de `test_faturas.py`):
  - `test_antecipar_fechamento_leva_a_compra_inteira`: compra em 02/11 3x (nov, dez, jan); editar novembro com fechamento 02/11 e vencimento 10/11 → competências dez, jan, fev; datas das parcelas inalteradas.
  - `test_parcela_no_intervalo_de_compra_fora_nao_se_move`: compra em 02/10 3x (out, nov, dez); parcela 2 tem data 02/11; editar novembro com fechamento 02/11 → as três ficam em out, nov, dez.
  - `test_adiar_fechamento_traz_a_compra_de_volta`: compra em 03/11 2x (dez, jan); editar novembro com fechamento 04/11 → nov, dez.
  - `test_dias_novos_do_cartao_movem_a_compra_parcelada`: com o cartão fechando dia 3, compra em 2026-12-13 2x (fecha 03/12 → jan/2027, fev/2027); `PUT /cartoes/{id}` com `dia_fechamento` 12 e `dia_vencimento` 20 (demais campos como em `test_dias_novos_valem_a_partir_da_proxima_fatura`) → competências 2026-12 e 2027-01 (dezembro passa a fechar seg 14/12, porque 12/12 é sábado).
- [ ] **Step 2:** → FAIL nos quatro (hoje cada parcela é realocada pela própria data).
- [ ] **Step 3: implementar** em `realocar_compras`; docstring diz "compra parcelada se move inteira, pela data da compra".
- [ ] **Step 4:** `uv run pytest` → PASS (inclui os testes de fatura e cartão que já existiam).
- [ ] **Step 5: docs** — `docs/arquitetura.md` §6 (compra parcelada: data e fatura da parcela) e §7 (`compra_parcelada` com os `CHECK`, `transacao.compra_parcelada_id`/`parcela_numero` e a regra do par; realocação por compra); `CLAUDE.md` (Fontes de dados → Cartão: "parcela k: data da compra + (k−1) meses, fatura da compra + (k−1) competências; fechamento que muda leva a compra inteira") e a lista "Specs já decididas" (2026-10-24: compra parcelada).
- [ ] **Step 6: commit** `feat: realocação move a compra parcelada inteira` + `docs: compra parcelada na arquitetura`. Abrir o PR 2.

---

## PR 3 — `feat/app-parcelada`: Lançamento com parcelas e "Parcela N/M"

### Task 5: divisão e textos no app (TDD)

**Files:**
- Create: `app/lib/features/transacoes/data/parcelas.dart`, `app/lib/features/transacoes/ui/textos.dart`
- Test: `app/test/features/transacoes/parcelas_test.dart`

**Interfaces:**
- Produces: `List<Decimal> dividirEmParcelas(Decimal total, int quantidade)` (mesma regra e **os mesmos casos** da Task 1); `String textoDaDivisao(Decimal total, int quantidade)` → `"3x de R$ 333,33; a 1ª parcela fica com R$ 333,34."` ou `"3x de R$ 100,00."`; `String textoDaUltimaParcela(DateTime competenciaDaCompra, int quantidade)` → `"A última parcela cai na fatura de janeiro de 2027."` (`nomeDoMes` + ano).

- [ ] **Step 1:** testes com a tabela da Task 1 e os dois textos (inclusive novembro/2026 + 3 → "janeiro de 2027") → `flutter test test/features/transacoes/parcelas_test.dart` FAIL.
- [ ] **Step 2:** implementar (truncar no centavo com `Decimal`, nunca `double`) → PASS.
- [ ] **Step 3: commit** `feat(app): divisão em parcelas e textos do lançamento`.

### Task 6: modelo, repositório e cubit

**Files:**
- Modify: `app/lib/features/transacoes/data/transacao.dart`, `transacoes_repositorio.dart`, `app/lib/features/transacoes/cubit/lancamento_cubit.dart`, `app/test/apoio/transacoes_falso.dart`
- Test: `app/test/features/transacoes/transacoes_repositorio_test.dart`, `transacoes_cubits_test.dart`

**Interfaces:**
- Produces:
  - freezed `Parcela({required int numero, required int total})`; `Transacao.parcela: Parcela?`; `transacaoDaApi` preenche a partir de `t.parcela`.
  - freezed `NovaCompraParcelada({contaId, valorTotal: Decimal, qtdParcelas: int, dataCompra: DateTime, descricao})`.
  - `TransacoesRepositorio.lancarParcelada(NovaCompraParcelada dados) -> Future<List<Transacao>>` (as parcelas, da 1ª à última).
  - `LancamentoCubit.salvar({..., int parcelas = 1})`: com `parcelas > 1` chama `lancarParcelada` e põe a 1ª parcela em `salva`; erros da API `valor_total` → chave `valor`, `data_compra` → `data`, `qtd_parcelas` → `parcelas` (acrescentar `parcelas` aos campos do formulário).
  - `TransacoesRepositorioFalso.parceladas` (lista de `NovaCompraParcelada` recebidas) e `transacaoExemplo(parcela: ...)`.
- [ ] **Step 1: testes que falham:** repositório (adaptador falso) envia `valor_total`/`qtd_parcelas`/`data_compra` e lê `parcela`; transação sem parcela → `parcela == null`; cubit com `parcelas: 3` chama `lancarParcelada` (e não `lancar`), com `parcelas: 1` chama `lancar`; 422 em `valor_total` aparece em `erros['valor']`.
- [ ] **Step 2:** `dart run build_runner build` + `flutter test test/features/transacoes` → FAIL; implementar → PASS.
- [ ] **Step 3: commit** `feat(app): compra parcelada no repositório e no cubit`.

### Task 7: telas

**Files:**
- Modify: `app/lib/features/transacoes/ui/lancamento_tela.dart`, `app/lib/features/transacoes/ui/item_transacao.dart`
- Test: `app/test/features/transacoes/transacoes_telas_test.dart`, `app/test/features/faturas/faturas_telas_test.dart`

**Interfaces:**
- Consumes: Tasks 5 e 6; `estado.faturaDaCompra.competencia`.
- Produces: no Lançamento, `DropdownButtonFormField<int>` "Parcelas" (`null`/1 = "À vista", 2…24 = "Nx") ao lado da data, só com cartão; com cartão o valor se chama "Valor total"; ajuda = `textoDaDivisao` quando N ≥ 2 e o valor é válido; o quadro da fatura ganha `textoDaUltimaParcela`; trocar para conta que não é cartão volta a parcela para 1. `ItemTransacao` acrescenta " · Parcela N/M" ao `subtitulo` quando `transacao.parcela != null` (vale para a fatura e para Transações). Atualizar o docstring da tela (parcelas deixam de ser "em breve").
- [ ] **Step 1: widget tests que falham:**
  - Lançamento com cartão: "Parcelas" habilitado; escolher 3x e digitar 1.000,00 mostra "3x de R$ 333,33; a 1ª parcela fica com R$ 333,34." e, com a fatura falsa de novembro/2026, "A última parcela cai na fatura de janeiro de 2027."; salvar chama `lancarParcelada` com `qtdParcelas: 3`.
  - Lançamento com conta corrente: sem "Parcelas"; com 3x escolhido no cartão e troca para a corrente, salvar chama `lancar` (review focus 5).
  - Detalhe da fatura com `transacaoExemplo(parcela: Parcela(numero: 3, total: 10), data: 15/10)` mostra "15 out · Parcela 3/10"; Transações mostra "Cartão Exemplo · Parcela 3/10".
- [ ] **Step 2:** `flutter test` → FAIL; implementar → PASS; `flutter analyze` limpo.
- [ ] **Step 3: commit** `feat(app): parcelas no lançamento e "Parcela N/M" nas listas`. Abrir o PR 3.

## Fechamento

- [ ] Depois de cada merge (pelo Yago): `gh run list --workflow deploy --limit 3` verde.
- [ ] Card "S3 · Compra parcelada" em "Concluído" com comentário-resumo (PRs, decisões).
- [ ] Rodada de explicação e perguntas de entrevista.
