# Cartões e faturas — plano de implementação

> **Para agentes:** use superpowers:executing-plans (ou subagent-driven-development) para executar tarefa por tarefa. Passos com checkbox (`- [ ]`).

**Objetivo:** cadastrar, editar e desativar cartões; calcular fechamento e vencimento das faturas ajustados para dia útil; ligar toda compra no cartão a uma fatura; ver, editar e ajustar faturas no app.

**Arquitetura:** módulo `backend/app/modulos/cartoes/` com as funções puras de data (`datas.py`), os feriados (`feriados.py`), as regras de cartão e de alocação (`service.py`), as de fatura (`faturas.py`) e dois routers (tag `cartoes` e tag `faturas`). A fatura só vira linha no banco quando recebe transação ou é editada; até lá é calculada. No app, feature nova `features/faturas/` e cadastro/edição do cartão em `features/contas/`.

**Stack:** FastAPI síncrono, SQLAlchemy 2.0, Alembic, Pydantic v2, pytest + testcontainers; Flutter, flutter_bloc (Cubit), go_router, freezed, decimal, cliente gerado `dart-dio`.

**Spec:** `docs/superpowers/specs/2026-10-23-cartoes-faturas-design.md` (aprovada em 24/10). Leia junto; este plano não repete os motivos.

## Restrições globais

- Dinheiro: `Dinheiro`/`DinheiroPositivo` em todo schema, `NUMERIC(14,2)`, `Decimal` no Dart. Nunca `float`/`double`.
- Enums `text` + `CHECK` escritos à mão na migration; datas de negócio `date`; "hoje" sempre de `HojeDep` (backend) ou do relógio injetado no cubit (app).
- Migrations só acrescentam (o deploy roda a migration com o código anterior ainda no ar).
- Cada rota com uma tag só, sem `_`: `cartoes` e `faturas`. Competência na URL `AAAA-MM`; no JSON, `date` do primeiro dia do mês.
- Erros: `CampoInvalido("campo", "mensagem")` → 422; não encontrado → 404 "Cartão não encontrado."; textos em pt-BR.
- `holidays` só como dependência de **dev**; nenhuma dependência nova no app.
- Dados fictícios em testes, seed, prints e design (ex.: "Cartão Exemplo", "Banco Exemplo", fecha dia 3, vence dia 10).
- Regerar o cliente (`bash scripts/gerar-cliente-api.sh`) em todo PR que muda o contrato; `flutter analyze` e `flutter test` verdes.
- O que é de outro card aparece como "em breve": parcelas, transferência, pagamento de fatura, "Registrar pagamento".

## Exemplo de referência dos testes

`HOJE = 2026-10-20` (já em `tests/utils.py`). Cartão fecha dia 3 e vence dia 10:

| competência | fechamento previsto → efetivo | vencimento previsto → efetivo |
|---|---|---|
| 2026-10 | sáb 03/10 → seg 05/10 | sáb 10/10 → ter 13/10 (12/10 feriado) |
| 2026-11 | ter 03/11 | ter 10/11 |
| 2026-12 | qui 03/12 | qui 10/12 |

Fatura atual em HOJE = novembro (aberta); outubro está fechada. Compra em 04/10 → outubro; em 05/10 → novembro.

## Review focus

1. Compra no próprio dia do fechamento já ajustado → fatura seguinte (sábado 03/10 fica em outubro; segunda 05/10 vai para novembro).
2. Competência malformada na URL (`2026-13`, `11-2026`, `abc`) → 422, nunca 500; competência válida sem fatura gravada → 200 calculada, e a `GET` não grava nada.
3. `conta_id` de conta corrente, de carteira ou inexistente nas rotas de cartão e fatura → 404; conta de pagamento que é cartão, carteira ou desativada → 422.
4. Ajustar duas vezes deixa um ajuste só; ajustar com diferença zero remove o ajuste; o calculado mostrado desconta o ajuste ao calcular o próximo.
5. Data fora dos anos com feriado na tabela (ex.: 2041) → erro explícito (`FeriadosAusentes`), nunca cálculo sem feriados.

---

## PR 1 — `feat/cartoes-datas`: feriados e regra das datas

### Task 1: tabela `feriado` com seed

**Files:**
- Create: `backend/app/modulos/cartoes/__init__.py`, `backend/app/modulos/cartoes/models.py` (só `Feriado` nesta task), `backend/app/modulos/cartoes/feriados.py`
- Create: `backend/alembic/versions/<gerado>_cria_feriado.py`
- Modify: `backend/alembic/env.py` (importar `app.modulos.cartoes.models`), `backend/tests/integration/test_migrations.py` (importar o mesmo), `backend/pyproject.toml` + `uv.lock` (`uv add --dev holidays`)
- Test: `backend/tests/integration/test_feriados.py`
- Docs: commitar a spec e este plano neste PR

**Interfaces:**
- Produces: `Feriado(data: date PK, descricao: str)` com `ComTimestamps`; `class FeriadosAusentes(Exception)`; `feriados_entre(sessao: Session, de: date, ate: date) -> dict[date, str]` (inclusivo; levanta `FeriadosAusentes` se `ate.year` for maior que o maior ano da tabela ou `de.year` menor que o menor).

- [ ] **Step 1:** `cd backend && uv add --dev holidays`.
- [ ] **Step 2: testes que falham** em `test_feriados.py`:
  - `test_tabela_bate_com_a_biblioteca`: lê todas as linhas de `feriado` e compara com `_bancarios(range(2024, 2041))`, função do próprio teste = `holidays.Brazil(years=..., categories=("public",))` mais as datas de `categories=("optional",)` cujo nome é `"Carnaval"`. Igualdade de `{data: descricao}`.
  - `test_carnaval_entra_e_cinzas_nao`: `date(2026, 2, 16)` e `date(2026, 2, 17)` na tabela; `date(2026, 2, 18)` e `date(2026, 6, 4)` fora.
  - `test_feriados_entre` devolve `{date(2026,10,12): "Nossa Senhora Aparecida"}` para 01/10–31/10/2026.
  - `test_ano_sem_feriados_levanta`: `feriados_entre(sessao, date(2041,1,1), date(2041,1,31))` levanta `FeriadosAusentes`.
- [ ] **Step 3:** `uv run pytest tests/integration/test_feriados.py -v` → falha (tabela não existe).
- [ ] **Step 4:** modelo `Feriado`, `uv run alembic revision --autogenerate -m "cria feriado"` e, na mesma migration, `op.bulk_insert` com a lista **escrita por extenso** (2024–2040), gerada uma vez com o mesmo critério do teste. Docstring da migration: por que a lista é literal e como gerar anos novos (o snippet do critério). `downgrade` apaga a tabela.
- [ ] **Step 5:** `feriados_entre` com uma consulta por intervalo e outra para `min/max(extract(year))`.
- [ ] **Step 6:** `uv run pytest -v` (inclui `test_migrations.py`) → verde; `uv run ruff check . && uv run ruff format --check .`.
- [ ] **Step 7: commit** `feat: tabela de feriados nacionais e Carnaval com seed`.

### Task 2: funções puras de data (TDD)

**Files:**
- Create: `backend/app/modulos/cartoes/datas.py`
- Test: `backend/tests/unit/test_datas_fatura.py`

**Interfaces:**
- Produces (todas puras; `feriados: Collection[date]`, um `dict[date, str]` serve):
  - `mes_seguinte(competencia: date) -> date`, `mes_anterior(competencia: date) -> date`, `competencia_de(dia: date) -> date` (primeiro dia do mês).
  - `proximo_dia_util(dia: date, feriados) -> date`
  - `@dataclass(frozen=True) DatasFatura(competencia: date, fechamento_previsto: date, fechamento: date, vencimento_previsto: date, vencimento: date)`
  - `datas_da_fatura(competencia: date, dia_fechamento: int, dia_vencimento: int, feriados) -> DatasFatura`
  - `competencia_da_compra(dia: date, fechamento_de: Callable[[date], date]) -> date` — primeira competência, a partir de `mes_anterior(mes_anterior(competencia_de(dia)))`, cujo `fechamento_de(c) > dia`; levanta `ValueError` se não achar até 3 meses depois.
  - `class StatusFatura(StrEnum): aberta, fechada`; `status_da_fatura(data_fechamento: date, hoje: date) -> StatusFatura` (aberta se `hoje < data_fechamento`).

- [ ] **Step 1: testes de tabela que falham** (`pytest.mark.parametrize`), com feriados reais escritos no teste (`{date(2026,10,12), date(2026,12,25), date(2026,2,16), date(2026,2,17), date(2027,1,1)}`):
  - `proximo_dia_util`: ter 20/10/2026 → 20/10; sáb 10/10 → ter 13/10; dom 11/10 → ter 13/10; sex 25/12 → seg 28/12; seg 16/02/2026 → qua 18/02.
  - `datas_da_fatura` (fecha 3, vence 10): as três linhas da tabela "Exemplo de referência".
  - Fechamento no mês anterior (fecha 28, vence 5, comp 2026-11): fechamento qua 28/10, vencimento qui 05/11.
  - Dia inexistente (fecha 31, vence 10, comp 2027-03): previsto 28/02/2027 (dom) → efetivo seg 01/03/2027; (fecha 3, vence 31, comp 2026-04): vencimento previsto 30/04/2026.
  - Virada de ano (fecha 25, vence 2, comp 2027-01): fechamento sex 25/12/2026 → seg 28/12; vencimento sáb 02/01/2027 → seg 04/01.
  - `competencia_da_compra` com `fechamento_de` do exemplo (fecha 3, vence 10): 03/10 → 2026-10; 04/10 → 2026-10; 05/10 → 2026-11; 20/10 → 2026-11; 03/11 → 2026-12; 30/09 → 2026-10.
  - `status_da_fatura`: (05/10, hoje 04/10) → aberta; (05/10, hoje 05/10) → fechada.
- [ ] **Step 2:** `uv run pytest tests/unit/test_datas_fatura.py -v` → falha (módulo não existe).
- [ ] **Step 3:** implementar `datas.py` (clamp com `calendar.monthrange`; fechamento no mês anterior quando `dia_fechamento > dia_vencimento`).
- [ ] **Step 4:** testes verdes; ruff.
- [ ] **Step 5: commit** `feat: datas de fechamento e vencimento ajustadas para dia útil`.
- [ ] **Step 6:** push, PR "Cartões: feriados e regra das datas", CI verde, merge pelo Yago.

---

## PR 2 — `feat/cartoes-cadastro`: cartão, fatura e compra no cartão

### Task 3: tabelas `cartao`, `fatura` e `transacao.fatura_id`

**Files:**
- Modify: `backend/app/modulos/cartoes/models.py` (+ `Cartao`, `Fatura`), `backend/app/modulos/transacoes/models.py` (+ `fatura_id`)
- Create: `backend/alembic/versions/<gerado>_cria_cartao_e_fatura.py`
- Test: `backend/tests/integration/test_cartoes_modelo.py`

**Interfaces:**
- Produces: `Cartao(conta_id PK/FK conta, conta_pagamento_id FK conta, dia_fechamento: int, dia_vencimento: int, limite: Decimal | None)`, relationships `conta` e `conta_pagamento` (lazy="joined"); `Fatura(id, cartao_id FK cartao.conta_id indexado, competencia, data_fechamento, data_vencimento, valor_informado: Decimal | None)`, unique `(cartao_id, competencia)`; `Transacao.fatura_id: uuid | None` (FK fatura, indexado). CHECKs com nome: `dia_fechamento_valido` (1–31), `dia_vencimento_valido`, `dias_diferentes`, `limite_positivo`, `competencia_primeiro_dia` (`extract(day from competencia) = 1`), `vencimento_depois_do_fechamento`, `valor_informado_nao_negativo`.

- [ ] **Step 1: testes que falham:** cada CHECK recusa o valor inválido (`IntegrityError`) — dia 0 e 32, dias iguais, limite 0, competência 2026-11-02, vencimento igual ao fechamento, informado −1; unique de `(cartao_id, competencia)`.
- [ ] **Step 2:** rodar → falha.
- [ ] **Step 3:** modelos + `alembic revision --autogenerate`; conferir que os CHECKs entraram (escrever à mão os que faltarem). Só `create_table`/`add_column`.
- [ ] **Step 4:** `uv run pytest -v` verde (inclui `alembic check` e upgrade/downgrade).
- [ ] **Step 5: commit** `feat: tabelas de cartão e fatura e fatura_id na transação`.

### Task 4: alocação de fatura e cadastro do cartão

**Files:**
- Create: `backend/app/modulos/cartoes/service.py`, `schemas.py`, `router.py` (tag `cartoes`)
- Modify: `backend/app/modulos/contas/service.py` (`_obter_ou_criar_instituicao` vira `obter_ou_criar_instituicao`), `backend/app/main.py` (incluir o router)
- Test: `backend/tests/integration/test_cartoes.py`

**Interfaces:**
- Consumes: Task 1 (`feriados_entre`), Task 2 (`datas_da_fatura`, `competencia_da_compra`, `status_da_fatura`).
- Produces (service):
  - `class CartaoNaoEncontrado(Exception)`; `obter_cartao(sessao, conta_id) -> Cartao` (404 se a conta não existe ou não é cartão).
  - `datas_calculadas(sessao, cartao, competencia) -> DatasFatura` (carrega feriados de ±3 meses).
  - `fatura_gravada(sessao, cartao, competencia) -> Fatura | None`
  - `fechamento_efetivo(sessao, cartao, competencia) -> date` (gravado, senão calculado)
  - `competencia_para_data(sessao, cartao, dia: date) -> date` (= `competencia_da_compra(dia, lambda c: fechamento_efetivo(...))`)
  - `obter_ou_criar_fatura(sessao, cartao, competencia) -> Fatura` (grava com as datas calculadas; sem commit)
  - `criar_cartao(sessao, *, nome, nome_instituicao, conta_pagamento_id, dia_fechamento, dia_vencimento, limite, hoje) -> Cartao` — conta `cartao_credito` com `saldo_inicial=0`, `data_saldo_inicial=hoje`.
  - `previa(sessao, *, dia_fechamento, dia_vencimento, hoje) -> DatasFatura` (a fatura de uma compra feita hoje, só pela regra).
- Produces (schemas): `CartaoEntrada(nome, instituicao, conta_pagamento_id, dia_fechamento: int = Field(ge=1, le=31), dia_vencimento: idem, limite: DinheiroPositivo | None = None)`; `DatasFaturaSaida(competencia, data_fechamento, data_vencimento)`.
- Rotas: `POST /cartoes` → 201 `ContaSaida` (com `cartao`, Task 5); `GET /cartoes/previa?dia_fechamento&dia_vencimento` → `DatasFaturaSaida`.

- [ ] **Step 1: testes que falham:**
  - `test_cria_cartao`: 201, `tipo == "cartao_credito"`, `saldo_inicial == "0.00"`, `data_saldo_inicial == "2026-10-20"`; a linha de `cartao` tem os dias 3 e 10 (o campo `cartao` da resposta entra na Task 5).
  - `test_conta_de_pagamento_precisa_ser_corrente_ativa`: carteira, cartão, desativada e id inexistente → 422 com `campos[0].campo == "body.conta_pagamento_id"`.
  - `test_dias_iguais` → 422 em `body.dia_vencimento`; `dia_fechamento=32` → 422.
  - `test_previa`: `?dia_fechamento=3&dia_vencimento=10` → `{"competencia": "2026-11-01", "data_fechamento": "2026-11-03", "data_vencimento": "2026-11-10"}`.
  - `test_competencia_para_data_respeita_fatura_editada` (service): grava outubro com `data_fechamento=2026-10-08`; compra em 06/10 → outubro (pela regra seria novembro).
  - `test_post_contas_continua_recusando_cartao`: `POST /contas` com `tipo=cartao_credito` → 422.
- [ ] **Step 2:** rodar → falha.
- [ ] **Step 3:** service, schemas e router. Mensagens: `"Escolha uma conta corrente ativa para pagar a fatura."`, `"O vencimento precisa ser num dia diferente do fechamento."`.
- [ ] **Step 4:** testes verdes; `tests/unit/test_operation_ids.py` verde.
- [ ] **Step 5: commit** `feat: cadastro de cartão e prévia da próxima fatura`.

### Task 5: cartão em Contas e compra no cartão

**Files:**
- Modify: `backend/app/modulos/contas/schemas.py` (+ `CartaoSaida`, `FaturaResumo`; `ContaSaida.cartao`), `contas/router.py` (`HojeDep` em `listar`/`obter`/`criar`), `backend/app/modulos/cartoes/service.py` (+ resumo), `backend/app/modulos/transacoes/service.py`, `transacoes/schemas.py`
- Create: `backend/app/modulos/cartoes/faturas.py` (só o resumo nesta task)
- Test: `backend/tests/integration/test_cartoes.py`, `test_transacoes.py`, `test_contas.py`
- Regenerate: `app/packages/api_client/`

**Interfaces:**
- Produces (`faturas.py`):
  - `@dataclass(frozen=True) ResumoFatura(competencia, data_fechamento, data_vencimento, status: StatusFatura, valor: Decimal, valor_calculado: Decimal, valor_informado: Decimal | None, fatura: Fatura | None)`
  - `valores_calculados(sessao, fatura_ids: Collection[uuid.UUID]) -> dict[uuid.UUID, Decimal]` — uma consulta agregada: saídas − entradas, status `confirmada`/`rascunho`, sem `pagamento_fatura`, `transferencia_entrada`, `transferencia_saida`.
  - `resumo(sessao, cartao, competencia, hoje) -> ResumoFatura` (valor = `max(informado, calculado)` ou calculado).
  - `resumo_atual(sessao, cartao, hoje) -> ResumoFatura` (competência = `competencia_para_data(hoje)`).
- Produces (schemas, em `contas/schemas.py` para `ContaSaida` não importar de cartões em ciclo): `FaturaResumo` (os campos do dataclass, sem `fatura`), `CartaoSaida(conta_pagamento_id, dia_fechamento, dia_vencimento, limite: Dinheiro | None, fatura_atual: FaturaResumo)`, `ContaSaida.cartao: CartaoSaida | None`. `TransacaoSaida.fatura_id: uuid.UUID | None`.
- `transacoes.service.lancar`: conta `cartao_credito` + `receita` → `CampoInvalido("conta_id", "Num cartão de crédito, lance só despesas.")`; despesa → `fatura_id = obter_ou_criar_fatura(competencia_para_data(data)).id`.

- [ ] **Step 1: testes que falham:**
  - `test_compra_no_cartao_entra_na_fatura`: despesa em 04/10 → `fatura_id` da fatura de outubro; em 05/10 → novembro (grava a fatura); duas compras em novembro → mesma `fatura_id`.
  - `test_receita_no_cartao_recusada` → 422 em `body.conta_id`.
  - `test_cria_cartao_devolve_fatura_atual`: `cartao.dia_fechamento == 3`, `cartao.fatura_atual.competencia == "2026-11-01"`, `valor == "0.00"`.
  - `test_contas_mostra_fatura_atual`: cartão com despesas de 120.00 (confirmada) e 30.00 (rascunho via sessão) em novembro e uma ignorada de 50.00 → `cartao.fatura_atual.valor == "150.00"`, `status == "aberta"`, `data_vencimento == "2026-11-10"`; conta corrente tem `cartao is None`.
  - `test_total_disponivel_ignora_cartao` continua verde.
- [ ] **Step 2:** rodar → falha.
- [ ] **Step 3:** implementar; o router de contas monta `cartao` chamando `cartoes.service`/`faturas.resumo_atual` para as contas de tipo cartão.
- [ ] **Step 4:** `uv run pytest -v` verde; ruff.
- [ ] **Step 5:** `bash scripts/gerar-cliente-api.sh`; em `app/`: build_runner do cliente e do app, `flutter analyze`, `flutter test` (o mapeamento `_conta` ignora `cartao` por enquanto; nada quebra).
- [ ] **Step 6: commit** `feat: compra no cartão ligada à fatura e fatura atual em contas`; push, PR, CI, merge.

---

## PR 3 — `feat/faturas-api`: faturas, edição, ajuste e edição do cartão

### Task 6: listar, detalhar e "para compra"

**Files:**
- Modify: `backend/app/modulos/cartoes/faturas.py`, `schemas.py`
- Create: `backend/app/modulos/cartoes/faturas_router.py` (tag `faturas`); incluir em `main.py`
- Test: `backend/tests/integration/test_faturas.py`

**Interfaces:**
- Produces (service): `listar(sessao, cartao, hoje) -> ListaFaturas(atual: ResumoFatura, proximas: list[ResumoFatura], anteriores: list[ResumoFatura])`; `detalhe(sessao, cartao, competencia, hoje) -> DetalheFatura(resumo, datas_calculadas: DatasFatura, ajuste_fechamento: AjusteData | None, ajuste_vencimento: AjusteData | None, transacoes: list[Transacao])`; `AjusteData(data_prevista: date, feriados: dict[date, str])` — nulo quando previsto == efetivo calculado; `feriados` = os dias pulados que são feriado.
- Schemas: `ListaFaturasSaida`, `FaturaDetalheSaida` (= `FaturaResumo` + `fechamento_calculado`, `vencimento_calculado`, `ajuste_fechamento`, `ajuste_vencimento: AjusteDataSaida | None` com `feriados: list[FeriadoSaida(data, descricao)]`, `transacoes: list[TransacaoSaida]`).
- Rotas (nesta ordem no arquivo): `GET /cartoes/{conta_id}/faturas` (`listar`), `GET .../faturas/para-compra?data=` (`para_compra` → `DatasFaturaSaida`), `GET .../faturas/{competencia}` (`obter`). `competencia: Annotated[str, Path(pattern=r"^\d{4}-(0[1-9]|1[0-2])$")]`, convertida para `date` no router.

- [ ] **Step 1: testes que falham:**
  - `test_lista`: compras em 04/10 e 20/10, e uma fatura de dezembro gravada → `atual.competencia == "2026-11-01"`, `proximas` = [dezembro], `anteriores` = [outubro] com `status == "fechada"`.
  - `test_lista_sem_compras` → `atual` calculada, listas vazias, e nenhuma linha em `fatura` depois da chamada.
  - `test_detalhe_outubro`: `fechamento_calculado == "2026-10-05"`, `ajuste_vencimento == {"data_prevista": "2026-10-10", "feriados": [{"data": "2026-10-12", "descricao": "Nossa Senhora Aparecida"}]}`, `ajuste_fechamento.feriados == []`; transações sem as ignoradas.
  - `test_detalhe_novembro_sem_ajuste` → `ajuste_fechamento is None` e `ajuste_vencimento is None`.
  - `test_competencia_invalida` (parametrizado `2026-13`, `11-2026`, `abc`) → 422.
  - `test_para_compra`: `data=2026-10-05` → novembro.
  - `test_rotas_de_fatura_404` (conta corrente, id inexistente) → 404 `"Cartão não encontrado."`.
- [ ] **Step 2:** rodar → falha. **Step 3:** implementar. **Step 4:** verde.
- [ ] **Step 5: commit** `feat: lista e detalhe das faturas do cartão`.

### Task 7: editar a fatura e realocar compras

**Files:** `faturas.py`, `faturas_router.py`, `schemas.py`, `service.py`; teste em `test_faturas.py`.

**Interfaces:**
- Produces: `realocar_compras(sessao, cartao, de: date, ate: date | None) -> None` (em `service.py`; transações do cartão com `de <= data < ate`, ou `data >= de` se `ate` é `None`, recebem a fatura de `competencia_para_data`; **ajustes de fatura (`ajuste_entrada`/`ajuste_saida`) nunca são realocados**: pertencem à fatura por definição); `editar(sessao, cartao, competencia, *, data_fechamento, data_vencimento, valor_informado, hoje) -> DetalheFatura`.
- Schema `FaturaEdicao(data_fechamento: date, data_vencimento: date, valor_informado: Dinheiro | None)` — os três obrigatórios no corpo.
- Rota `PUT /cartoes/{conta_id}/faturas/{competencia}` (`editar`) → `FaturaDetalheSaida`.

- [ ] **Step 1: testes que falham:**
  - `test_antecipar_fechamento_move_compras`: compras em 25/10 e 01/11 em novembro; PUT novembro com fechamento 28/10 → a de 01/11 vai para dezembro (fatura de dezembro gravada), a de 25/10 fica.
  - `test_adiar_fechamento_traz_compras`: compra em 06/10 (novembro); PUT outubro com fechamento 08/10 → a compra volta para outubro.
  - `test_fechamento_nao_inverte_ordem`: PUT novembro com fechamento 05/10 (igual ao de outubro) → 422 em `body.data_fechamento`; com 03/12 → 422.
  - `test_vencimento_antes_do_fechamento` → 422 em `body.data_vencimento`; `valor_informado = "-1.00"` → 422.
  - `test_editar_grava_fatura_calculada`: PUT dezembro sem compras → 200 e a linha existe; `valor_informado: null` limpa.
  - `test_valor_e_o_maior`: informado 200.00 e calculado 150.00 → `valor == "200.00"`; informado 100.00 → `valor == "150.00"`.
- [ ] **Step 2–4:** falha → implementar (gravar, depois `realocar_compras(min(antigo, novo), max(antigo, novo))`, commit) → verde.
- [ ] **Step 5: commit** `feat: editar fatura e realocar compras pelo fechamento`.

### Task 8: ajuste para o valor real

**Files:** `faturas.py`, `faturas_router.py`, `schemas.py`; teste em `test_faturas.py`.

**Interfaces:**
- Produces: `ajustar(sessao, cartao, competencia, *, valor_real: Decimal, descricao: str | None, hoje) -> DetalheFatura`. Ajuste = a transação da fatura com tipo `ajuste_entrada`/`ajuste_saida`; diferença = `valor_real − (calculado − efeito do ajuste atual)`; > 0 → `ajuste_saida`, < 0 → `ajuste_entrada` (valor absoluto), 0 → remove. `data` do ajuste = hoje (a realocação não o move; ver Task 7). `descricao` padrão `"Ajuste da fatura"`, `fonte = manual`, `status = confirmada`. Grava `valor_informado = valor_real`.
- Schema `AjusteEntrada(valor_real: Dinheiro, descricao: str | None = Field(None, min_length=1, max_length=200))`; `valor_real < 0` → 422.
- Rota `POST /cartoes/{conta_id}/faturas/{competencia}/ajuste` (`ajustar`) → `FaturaDetalheSaida`.

- [ ] **Step 1: testes que falham:**
  - `test_ajuste_cobre_o_que_falta`: calculado 986.25, real 1032.15 → `valor_calculado == valor_informado == "1032.15"`, uma transação `ajuste_saida` de 45.90 com descrição "Ajuste da fatura".
  - `test_ajuste_de_lancamento_a_mais`: calculado 150.00, real 138.00 → `ajuste_entrada` 12.00.
  - `test_ajustar_de_novo_substitui`: ajustar para 1032.15 e depois 1040.00 → um ajuste só, de 53.75.
  - `test_ajuste_zero_remove`: depois do ajuste, lançar a compra de 45.90 que faltava e ajustar para 1032.15 → nenhum ajuste na fatura.
  - `test_descricao_do_ajuste`: `descricao="IOF não veio no extrato"` fica na transação.
- [ ] **Step 2–4:** falha → implementar → verde.
- [ ] **Step 5: commit** `feat: ajuste da fatura para o valor real`.

### Task 9: editar e desativar o cartão

**Files:** `service.py`, `schemas.py`, `router.py`; teste em `test_cartoes.py`. Regenerate: cliente.

**Interfaces:**
- Produces: `editar_cartao(sessao, conta_id, *, nome, nome_instituicao, conta_pagamento_id, dia_fechamento, dia_vencimento, limite, ativa, hoje) -> Cartao`. Com dias novos: `atual = competencia_para_data(hoje)` (antes de mudar) e `obter_ou_criar_fatura(atual)` — gravar a atual é o que a faz manter as datas; grava os dias; recalcula as faturas gravadas com competência > atual; se `fechamento_efetivo(mes_seguinte(atual)) <= fechamento_efetivo(atual)` → `CampoInvalido("dia_fechamento", "Com esses dias, a próxima fatura fecharia antes da atual.")`; `realocar_compras(fechamento_efetivo(atual), None)`.
- Schema `CartaoEdicao(CartaoEntrada)` + `ativa: bool`. Rota `PUT /cartoes/{conta_id}` (`editar`) → `ContaSaida`.

- [ ] **Step 1: testes que falham:**
  - `test_editar_nome_e_limite`.
  - `test_dias_novos_valem_da_proxima_fatura`: compra em 25/11 (dezembro, fatura gravada); PUT com fecha 20, vence 27 → novembro mantém 03/11 e 10/11; dezembro passa a fechar 21/12 (20/12 é domingo) e vencer 28/12 (27/12 é domingo); a compra de 25/11 continua em dezembro.
  - `test_dias_que_inverteriam_ordem`: fecha 2, vence 1 → dezembro fecharia em 02/11 (Finados) → ter 03/11, igual ao fechamento de novembro → 422 em `body.dia_fechamento`, e nada muda.
  - `test_desativar_e_reativar`: `ativa=false` → `GET /contas` mostra `ativa == false`; lançar despesa → 422 em `body.conta_id`; faturas continuam em `GET .../faturas`; `ativa=true` volta a aceitar.
- [ ] **Step 2–4:** falha → implementar → verde.
- [ ] **Step 5:** regerar o cliente; build_runner + `flutter analyze` + `flutter test`.
- [ ] **Step 6: commit** `feat: editar e desativar cartão`; push, PR, CI, merge.

---

## Design — antes dos PRs 5 e 6

### Task 10: canvas atualizado e "Editar cartão"

Página "Cartões e faturas" do canvas (link no `CLAUDE.local.md`), claro e escuro, dados fictícios:

- [ ] Fatura fechada e Editar fatura: fechamento de outubro passa a "seg, 5 out" / `05/10/2026` (ajuste para dia útil); ajuda "Dia 3 caiu num sábado: passou para o próximo dia útil."
- [ ] Fatura fechada: botão "Ajustar para o valor real" no aviso de diferença; estado "Lançado R$ 12,00 a mais que o banco informou".
- [ ] Artboard novo "Ajustar fatura" (folha/diálogo: valor real, motivo opcional, "Ajustar").
- [ ] Artboards novos "Editar cartão" (campos do cadastro, aviso "Os dias novos valem a partir da próxima fatura", "Desativar cartão") e o diálogo de confirmação de desativar com fatura em aberto.
- [ ] Contas: linha de cartão "Desativado".
- [ ] Aprovação do Yago no chat antes do PR 6.

---

## PR 4 — `feat/app-cartoes`: Nova conta cartão, Contas e Lançamento

### Task 11: modelos e repositórios

**Files:**
- Create: `app/lib/features/faturas/data/fatura.dart`, `app/lib/features/faturas/data/faturas_repositorio.dart`, `app/test/apoio/faturas_falso.dart`
- Modify: `app/lib/features/contas/data/conta.dart`, `contas_repositorio.dart`, `app/lib/features/transacoes/data/transacao.dart` (+ `faturaId`), `transacoes_repositorio.dart`, `app/lib/app/injecao.dart`, `app/lib/app/app.dart`, `app/test/apoio/contas_falso.dart`
- Test: `app/test/features/faturas/faturas_repositorio_test.dart`, `app/test/features/contas/contas_repositorio_test.dart`

**Interfaces:**
- Produces (`fatura.dart`, freezed): `enum StatusFatura { aberta, fechada }`; `DatasFatura(competencia, dataFechamento, dataVencimento)`; `ResumoFatura(competencia, dataFechamento, dataVencimento, status, valor, valorCalculado, valorInformado?)` com `Decimal? get diferenca` (informado − calculado, nulo sem informado ou se zero); `AjusteData(dataPrevista, feriados: Map<DateTime, String>)`; `DetalheFatura(resumo, fechamentoCalculado, vencimentoCalculado, ajusteFechamento?, ajusteVencimento?, transacoes: List<Transacao>)`; `ListaFaturas(atual, proximas, anteriores)` com `List<ResumoFatura> get emOrdem` (próximas, atual, anteriores — usada pelas setas do detalhe).
- `conta.dart`: `Cartao(contaPagamentoId, diaFechamento, diaVencimento, limite?, faturaAtual: ResumoFatura)`; `Conta.cartao: Cartao?`; `aceitaLancamento` sai e entram `recebeDespesa` (ativa) e `recebeReceita` (ativa e não cartão); `NovoCartao(nome, instituicao, contaPagamentoId, diaFechamento, diaVencimento, limite?)`, `EdicaoCartao` (+ `ativa`).
- `ContasRepositorio` ganha `criarCartao(NovoCartao) -> Conta`, `editarCartao(String contaId, EdicaoCartao) -> Conta`, `previaFatura({required int diaFechamento, required int diaVencimento}) -> DatasFatura`.
- `FaturasRepositorio`: `listar(String contaId) -> ListaFaturas`, `obter(String contaId, DateTime competencia) -> DetalheFatura`, `editar(String contaId, DateTime competencia, {required DateTime dataFechamento, required DateTime dataVencimento, Decimal? valorInformado}) -> DetalheFatura`, `ajustar(String contaId, DateTime competencia, {required Decimal valorReal, String? descricao}) -> DetalheFatura`, `paraCompra(String contaId, DateTime data) -> DatasFatura`. Competência vai na URL como `AAAA-MM` (`competenciaParaApi` em `fatura.dart`).

- [ ] **Step 1: testes que falham** (adaptador falso do dio): `listar` converte `"544.80"` em `Decimal` e `"2026-11-01"` em `DateTime(2026, 11, 1)`; `obter` chama `/cartoes/c1/faturas/2026-11`; `editar` manda `valor_informado: null`; `ContasRepositorioApi.listar` preenche `cartao` só no cartão.
- [ ] **Step 2–4:** falha → implementar (+ falsos em `test/apoio/`) → verde; `flutter analyze`.
- [ ] **Step 5: commit** `feat(app): modelos e repositórios de cartões e faturas`.

### Task 12: Nova conta · cartão de crédito

**Files:** `app/lib/features/contas/cubit/nova_conta_cubit.dart`, `ui/nova_conta_tela.dart`; teste em `contas_cubits_test.dart` e `contas_telas_test.dart`.

**Interfaces:** `NovaContaEstado` ganha `DatasFatura? previa`; `NovaContaCubit` ganha `atualizarPrevia(String diaFechamento, String diaVencimento)` (só chama a API com dois dias válidos e diferentes; erro de rede = sem prévia) e `salvarCartao({nome, instituicao, contaPagamentoId, diaFechamento, diaVencimento, limite})`. Campos de erro da API: `nome`, `instituicao`, `conta_pagamento_id`, `dia_fechamento`, `dia_vencimento`, `limite`.

- [ ] **Step 1: testes que falham:**
  - cubit: dias 3 e 10 → `previa.competencia == DateTime(2026, 11)`; dia 0 ou dias iguais → erro local, sem chamada; 422 em `conta_pagamento_id` aparece no campo.
  - tela: chip "Cartão de crédito" mostra os campos do design e esconde saldo inicial; prévia "Próxima fatura: novembro" / "Fecha ter, 3 nov · vence ter, 10 nov"; sem conta corrente ativa → aviso "Falta a conta que paga a fatura" e "Salvar cartão" desabilitado.
- [ ] **Step 2–4:** falha → implementar (`formatarDiaCurto` = "ter, 3 nov" em `core/formatacao/datas.dart`, com teste em `datas_test.dart`) → verde.
- [ ] **Step 5: commit** `feat(app): cadastro de cartão de crédito`.

### Task 13: Contas e Lançamento no cartão

**Files:** `contas/ui/contas_tela.dart`, `transacoes/cubit/lancamento_cubit.dart`, `transacoes/ui/lancamento_tela.dart`, `app/router.dart` (rota `/mais/contas/cartao/:id` com placeholder até o PR 5); testes nas telas e cubits.

**Interfaces:** `LancamentoCubit(transacoes, faturas)` ganha `DatasFatura? faturaDaCompra` e `consultarFatura(Conta? conta, DateTime data)` (só para cartão; limpa ao trocar para conta comum).

- [ ] **Step 1: testes que falham:**
  - Contas: seção "Cartões de crédito" com "Cartão Exemplo", "Fecha 3 nov · vence 10 nov", "Fatura atual" e "R$ 544,80"; o item "em breve" some.
  - Lançamento: Tipo antes da Conta; Despesa lista o cartão, Receita não; com cartão aparece "Entra na fatura de novembro" e "Fecha ter, 3 nov · vence ter, 10 nov", e "Parcelas" desabilitado com "Em breve"; trocar a data para 05/10 consulta de novo.
- [ ] **Step 2–4:** falha → implementar → verde; `flutter analyze`.
- [ ] **Step 5: commit** `feat(app): cartões em contas e compra no cartão`; push, PR, CI, merge.

---

## PR 5 — `feat/app-faturas`: lista, detalhe, edição e ajuste

### Task 14: lista e detalhe

**Files:** Create `app/lib/features/faturas/cubit/faturas_cubit.dart`, `fatura_cubit.dart`, `ui/faturas_tela.dart`, `ui/fatura_tela.dart`, `ui/textos.dart` (`explicarAjuste(AjusteData) -> String`, `descreverDiferenca(Decimal) -> String`); modify `app/router.dart` (`/mais/contas/cartao/:id` e `/mais/contas/cartao/:id/fatura/:competencia`). Tests em `app/test/features/faturas/`.

- [ ] **Step 1: testes que falham:**
  - `explicarAjuste`: previsto sáb 10/10 com feriado 12/10 → "Dia 10 caiu num sábado e 12 out é feriado: passou para o próximo dia útil."; previsto sáb 03/10 sem feriados → "Dia 3 caiu num sábado: passou para o próximo dia útil."; previsto qua 12/10 feriado → "Dia 12 é feriado: passou para o próximo dia útil."
  - `descreverDiferenca`: +45.90 → "Faltam R$ 45,90 em lançamentos."; −12.00 → "Lançado R$ 12,00 a mais que o banco informou."
  - lista: seções Próximas, Atual, Anteriores com chips "Aberta"/"Fechada", "vence ter, 10 nov", valores; vazio → só Atual.
  - detalhe aberto: "Total até agora", "O banco ainda não informou o valor desta fatura."; fechado: "Valor da fatura", informado e calculado, aviso de diferença com "Ajustar para o valor real", explicação do vencimento; "Registrar pagamento" desabilitado com "Em breve"; setas seguem `ListaFaturas.emOrdem` e somem nas pontas.
- [ ] **Step 2–4:** falha → implementar → verde.
- [ ] **Step 5: commit** `feat(app): lista e detalhe das faturas`.

### Task 15: editar fatura e ajuste

**Files:** Create `cubit/editar_fatura_cubit.dart`, `ui/editar_fatura_tela.dart`, `ui/ajuste_folha.dart`; rota `.../fatura/:competencia/editar` (navigator raiz). Tests.

- [ ] **Step 1: testes que falham:**
  - editar: campos preenchidos com as datas efetivas e o informado; "Voltar às datas calculadas" preenche `fechamentoCalculado`/`vencimentoCalculado` sem salvar; 422 em `data_fechamento` aparece no campo; salvar volta ao detalhe recarregado.
  - ajuste: folha com o valor real preenchido com o informado; "Ajustar" chama `ajustar` com o valor e a descrição; o detalhe recarrega sem aviso de diferença.
- [ ] **Step 2–4:** falha → implementar → verde.
- [ ] **Step 5: commit** `feat(app): editar fatura e ajustar para o valor real`; push, PR, CI, merge.

---

## PR 6 — `feat/app-editar-cartao` (depois do design aprovado na Task 10)

### Task 16: Editar cartão

**Files:** Create `app/lib/features/contas/cubit/editar_cartao_cubit.dart`, `ui/editar_cartao_tela.dart`; rota `/mais/contas/cartao/:id/editar` (navigator raiz), aberta pelo ícone de editar da lista de faturas; Contas mostra "Desativado". Tests.

- [ ] **Step 1: testes que falham:** campos preenchidos com o cartão; aviso "Os dias novos valem a partir da próxima fatura." aparece ao mudar um dia; 422 em `dia_fechamento` no campo; "Desativar cartão" com fatura de valor > 0 pede confirmação e manda `ativa: false`; cartão desativado mostra "Reativar cartão"; Contas mostra "Desativado"; Lançamento não lista cartão desativado.
- [ ] **Step 2–4:** falha → implementar → verde.
- [ ] **Step 5: commit** `feat(app): editar e desativar cartão`; push, PR, CI, merge.

---

## Encerramento

### Task 17: docs, deploy e card

- [ ] `docs/arquitetura.md`: §6 (regra das datas e "melhor dia de compra"), §7.2 (`cartao` com CHECKs, `fatura` sem `status` e com competência = mês do vencimento, `feriado` com Carnaval e seed literal, valor calculado e ajuste), §7.3 (`transacao.fatura_id`), `ContaSaida.cartao`. Pode ir no PR 3, junto com a mudança de contrato.
- [ ] `CLAUDE.md`: specs decididas (2026-10-23 cartões e faturas); armadilha do seed de feriados (anos novos = migration nova).
- [ ] Depois de cada merge: `gh run list --workflow deploy --limit 3` verde.
- [ ] Trello: card "S3 · Cartões e faturas" para "Concluído" com comentário-resumo (PRs, decisões, o que ficou para os cards de parcelada e pagamento).
- [ ] Rodada de explicação e perguntas de entrevista.
