# Categorias e regras de classificação — plano de implementação

> **Para agentes:** use superpowers:executing-plans (ou subagent-driven-development) para executar tarefa por tarefa. Passos com checkbox (`- [ ]`).

**Objetivo:** categorias editáveis (seed genérico), regras de classificação sem `prioridade` (normalização e escolha em funções puras), o serviço que aprende a regra na confirmação da revisão, categoria no lançamento manual e, no app, Mais → Categorias e regras com Editar categoria e Editar regra.

**Arquitetura:** módulo novo `backend/app/modulos/categorias/` — `models.py` (`Categoria`, `RegraClassificacao`), `classificacao.py` (puro: `normalizar`, `casa`, `grupos_do_tipo`, `escolher_regra`), `service.py` (categorias), `regras.py` (regras, rascunhos casados, `confirmar_categoria`), `router.py` (tag `categorias`) e `regras_router.py` (tag `regras`). `transacao.categoria_id` e o relacionamento `Transacao.categoria`. No app, feature nova `lib/features/categorias/` (data, cubit, ui).

**Stack:** FastAPI síncrono, SQLAlchemy 2.0, Alembic, Pydantic v2, pytest + testcontainers; Flutter, flutter_bloc (Cubit), freezed, go_router, cliente gerado `dart-dio`.

**Spec:** `docs/superpowers/specs/2026-10-19-revisao-classificacao-design.md`, seções "Regras de classificação aprendidas" e "Categorias" (atualizadas em 26/10). Leia junto; este plano não repete os motivos.

## Restrições globais

- Migration só acrescenta: tabelas novas e `transacao.categoria_id` nula; `down_revision = "964c3e10c6cc"`. CHECKs escritos à mão onde o autogenerate não pega; o seed é `op.bulk_insert` com nomes por extenso.
- Uma tag por rota, sem `_`: `categorias_listar` → `CategoriasApi.listar()`; `regras_editar` → `RegrasApi.editar()`.
- Erros de regra de negócio: `CampoInvalido("campo", "mensagem")` → 422. Mensagens: "Já existe uma categoria com esse nome.", "Categoria não encontrada.", "Esta categoria está desativada.", "Já existe uma regra com esse padrão.", "O padrão ficou vazio: use o nome do estabelecimento ou da pessoa.", "Esta categoria já tem transações; troque o grupo só entre essencial e variável.", e as de compatibilidade (`despesa`/`estorno`: "Escolha uma categoria de gasto (essencial ou variável)."; `receita`: "Escolha uma categoria de renda."; `aporte`/`resgate`: "Escolha uma categoria de investimento."; demais tipos: "Este tipo de transação não tem categoria."). 404 em pt-BR: "Categoria não encontrada.", "Regra não encontrada.".
- Sem dependência nova (acentos com `unicodedata`, da biblioteca padrão). Dados fictícios ("Padaria Pão Quente", "Posto Fictício", "Conta principal", "Cartão Exemplo").
- Regerar o cliente (`bash scripts/gerar-cliente-api.sh`) em cada PR que muda o contrato; `flutter analyze` e `flutter test` verdes; telas e cubits não importam o cliente gerado.

## Review focus

1. `escolher_regra`: manual > restrita a uma conta > padrão mais longo > alfabética; regra de outra conta nunca casa; casamento por palavras inteiras (`bar` não casa `barbearia`).
2. `confirmar_categoria`: os cinco casos da spec, em especial correção de aprendida com padrão igual (troca e zera) × mais curto (nasce outra) × manual (não muda).
3. Regra de categoria desativada ou incompatível com o tipo não sugere nem conta nos "rascunhos casados".
4. Editar uma regra aprendida a torna manual; recusa de duplicata considera padrão + conta + natureza (gasto/renda/investimento) e ignora a própria regra.
5. Trocar o grupo para outra natureza é recusado quando há transação com a categoria; entre essencial e variável, não.

Cada item tem teste na tarefa dona do código (marcado "RF n").

---

## PR 1 — `feat/categorias-api`: categorias, classificação pura e categoria no lançamento

### Task 1: tabelas, seed e `transacao.categoria_id`

**Files:** Create `backend/app/modulos/categorias/{__init__,models}.py`, `backend/alembic/versions/2026_10_26_1000-<rev>_categorias_e_regras.py`; Modify `backend/app/modulos/transacoes/models.py`, `backend/alembic/env.py` (se os models forem importados lá); Test `backend/tests/integration/test_categorias_modelo.py`; Docs: spec, arquitetura e este plano neste PR.

- `GrupoCategoria(StrEnum)`: essencial, variavel, renda, investimento. `Categoria`: `id`, `nome` (índice único `uq_categoria_nome_lower` em `lower(nome)`), `grupo` (`check_enum`), `ativa` (padrão true).
- `OrigemRegra(StrEnum)`: manual, aprendida. `RegraClassificacao`: `id`, `padrao` (`CHECK padrao <> ''`), `conta_id` FK null (indexado), `categoria_id` FK (indexado), `origem` (`check_enum`), `vezes_aplicada` (`CHECK >= 0`, padrão 0); `categoria` e `conta` com `lazy="joined"`.
- `Transacao.categoria_id` FK null indexado; `Transacao.categoria` com `lazy="joined"`.

- [ ] **Step 1: testes que falham:** seed tem as 12 categorias nos grupos da spec; nome repetido com outra caixa é recusado (IntegrityError); grupo inválido, padrão vazio e `vezes_aplicada` negativa recusados; transação aceita `categoria_id`.
- [ ] **Step 2:** `uv run pytest tests/integration/test_categorias_modelo.py` → FAIL.
- [ ] **Step 3:** models + `alembic revision --autogenerate -m "categorias e regras"`; renomear com data; revisar CHECKs e índice funcional; `op.bulk_insert` do seed com `uuid4()`; `downgrade` na ordem inversa.
- [ ] **Step 4:** PASS, incluindo `tests/integration/test_migrations.py`.
- [ ] **Step 5: commits** `docs: spec e plano de categorias e regras` e `feat: tabelas de categoria e regra de classificação`.

### Task 2: `classificacao.py` (TDD, testes de tabela)

**Files:** Create `backend/app/modulos/categorias/classificacao.py`; Test `backend/tests/unit/test_classificacao.py`.

- `normalizar(descricao: str) -> str` — NFKD sem marcas, minúsculas; tira datas e palavras com dígito; pontuação → espaço; tira `TERMOS_GENERICOS` (expressões antes das palavras soltas, sempre como palavras inteiras); espaços simples.
- `casa(padrao: str, descricao_normalizada: str) -> bool` — palavras inteiras.
- `grupos_do_tipo(tipo: TipoTransacao) -> frozenset[GrupoCategoria]` — vazio para transferência, pagamento de fatura e ajuste.
- `escolher_regra(descricao_normalizada, conta_id, regras: Iterable[R]) -> R | None`, `R` um `Protocol` com `padrao`, `conta_id`, `origem` (RF 1).

- [ ] Tabelas: `PIX ENVIADO 12/11 PADARIA SAO JOSE LTDA 0349` → `padaria sao jose ltda`; `Transferência enviada pelo Pix - Fulano de Tal` → `fulano de tal`; `Compra no débito - Mercado do Bairro` → `mercado do bairro`; `POSTO FICTICIO 0193 FORTALEZA BR`; `Pagamento recebido` → `` ; `Estorno - Padaria`; `NETFLIX.COM`; acentos e caixa; códigos `*1234`, `24h`; datas `12/11/2026` e `2026-11-12`; `Pix` dentro de palavra (`pixel`) fica.
- [ ] `escolher_regra`: manual vence aprendida mais longa; restrita vence geral; mais longa vence; empate total → alfabética; regra de outra conta não casa; nenhuma casa → `None`.
- [ ] **Commit** `feat: normalização e escolha da regra de classificação`.

### Task 3: CRUD de categorias

**Files:** Create `backend/app/modulos/categorias/{schemas,service,router}.py`; Modify `backend/app/main.py`; Test `backend/tests/integration/test_categorias.py`.

- `GET /categorias` → `list[CategoriaSaida]` (`id`, `nome`, `grupo`, `ativa`, `qtd_regras`, `qtd_transacoes`; uma consulta agregada), ordem grupo (essencial, variável, renda, investimento) e nome.
- `POST /categorias` (`nome` 1–60, `grupo`) → 201. `PUT /categorias/{id}` (`nome`, `grupo`, `ativa`) → 200; 404.
- `service.categoria_para_tipo(sessao, categoria_id, tipo, campo)` — existe, ativa e compatível (usada pelo lançamento e pelas regras).

- [ ] Testes: lista do seed com contagens; criar; nome repetido (outra caixa) → 422 em `body.nome`; desativar e reativar; renomear para o próprio nome com outra caixa é aceito; trocar grupo essencial↔variável com transação ok; variável→renda com transação → 422 em `body.grupo`, sem transação ok (RF 5); id malformado → 422; sem token → 401.
- [ ] **Commit** `feat: cadastro de categorias`.

### Task 4: categoria no lançamento e na saída da transação

**Files:** Modify `backend/app/modulos/transacoes/{schemas,service,router}.py`; Test `backend/tests/integration/test_transacoes.py`, `test_compras_parceladas.py`.

- `TransacaoEntrada.categoria_id` e `CompraParceladaEntrada.categoria_id` opcionais; todas as parcelas recebem a categoria.
- `TransacaoSaida.categoria: CategoriaResumo | None` (`id`, `nome`, `grupo`).

- [ ] Testes: despesa com Mercado → 201 e `categoria.nome`; receita com Mercado → 422 em `body.categoria_id`; categoria desativada → 422; inexistente → 422; parcelada leva a categoria a todas as parcelas; sem categoria continua igual.
- [ ] Regerar o cliente; `flutter analyze` (o app não usa o campo ainda).
- [ ] **Commit** `feat: categoria no lançamento manual` + `chore: regera o cliente da API`.

## PR 2 — `feat/regras-api`: regras e aprendizado

### Task 5: CRUD de regras e rascunhos casados

**Files:** Create `backend/app/modulos/categorias/{regras,regras_router}.py`; Modify `schemas.py`, `main.py`; Test `backend/tests/integration/test_regras.py`.

- `GET /regras` → `list[RegraSaida]` (`id`, `padrao`, `categoria`, `conta_id`, `origem`, `vezes_aplicada`, `criado_em`), manuais primeiro, depois mais usadas.
- `GET /regras/{id}`, `POST /regras` (201), `PUT /regras/{id}` → `RegraDetalheSaida` = `RegraSaida` + `rascunhos: RascunhosCasados` (`quantidade`, `exemplo: {descricao, data} | null`, o mais recente). `DELETE /regras/{id}` → 204.
- Entrada: `padrao` (normalizado no service; vazio → 422), `categoria_id` (ativa se mudou), `conta_id` opcional (ativa se mudou). `PUT` torna manual (RF 4). Duplicata → 422 em `body.padrao` (RF 4).
- `regras_candidatas(sessao)`: regras de categoria ativa. Rascunhos casados: rascunhos sem categoria, de tipo com categoria, em que a regra é a escolhida entre as compatíveis com o tipo (RF 3).

- [ ] Testes: criar manual e ver `padrao` normalizado; regra restrita a conta; duplicata na mesma natureza → 422, natureza diferente aceita, editar a própria sem mudar aceita; editar aprendida vira manual; excluir; rascunhos casados contam só os que ela vence, não contam confirmados, ignorados, com categoria, de outra conta, de tipo incompatível nem de categoria desativada; 404.
- [ ] **Commit** `feat: cadastro de regras de classificação`.

### Task 6: `confirmar_categoria` (TDD)

**Files:** Modify `backend/app/modulos/categorias/regras.py`; Test `backend/tests/integration/test_confirmar_categoria.py`.

- `regra_sugerida(sessao, transacao) -> RegraClassificacao | None` (para a revisão).
- `aprender(sessao, transacao, categoria) -> Aprendizado` (não faz commit; `efeito`: `criada` | `reforcada` | `corrigida` | `especializada` | `manual_mantida` | `nenhuma`, e a `regra`).
- `confirmar_categoria(sessao, transacao_id, categoria_id) -> Aprendizado` — valida compatibilidade, grava `categoria_id` e `status = confirmada`, aprende e faz commit.

- [ ] Testes (RF 2): sem regra → criada (padrão da transação, geral, 0); sugestão aceita → +1; correção de aprendida com padrão igual → troca e zera; com padrão mais curto → nova aprendida, a antiga intacta, e a próxima transação igual sugere a nova; correção de manual → manual intacta; padrão vazio → nenhuma; incompatível → 422; renda e gasto com o mesmo padrão coexistem.
- [ ] **Commit** `feat: regra aprendida na confirmação da categoria`.
- [ ] Regerar o cliente; arquitetura e CLAUDE.md conferidos; **commit** `chore: regera o cliente da API`.

## PR 3 — `feat/app-categorias`: categorias no app

### Task 7: modelo, repositório e cubits de categoria

**Files:** Create `app/lib/features/categorias/data/{categoria,categorias_repositorio}.dart`, `cubit/{categorias_cubit,editar_categoria_cubit}.dart`; Modify `app/lib/app/injecao.dart`; Test `app/test/features/categorias/categorias_repositorio_test.dart`, `categorias_cubits_test.dart`, `app/test/apoio/categorias_falso.dart`.

- `Categoria` (freezed): `id`, `nome`, `grupo` (`GrupoCategoria`), `ativa`, `qtdRegras`, `qtdTransacoes`. `GrupoCategoria.combinaCom(TipoTransacao)` espelha `grupos_do_tipo`.
- Repositório: `listar`, `criar`, `editar`; `DioException` → `ErroApi`.
- Cubits com bloc_test: carregar/erro/recarregar; salvar com erro de campo (`nome`, `grupo`).

### Task 8: telas de categorias, Mais e lançamento

**Files:** Create `app/lib/features/categorias/ui/{categorias_regras_tela,editar_categoria_tela}.dart`; Modify `app/lib/app/router.dart`, `app/lib/features/configuracoes/ui/mais_tela.dart`, `app/lib/features/transacoes/{data,cubit,ui}/…`; Test widget tests.

- Mais → "Categorias e regras" (`/mais/categorias`), abas Categorias e Regras (Regras como "em breve" até o PR 4), grupos com contagem de regras e "Desativada", FAB "Nova categoria".
- Editar categoria: nome, chips de grupo, nota "N regras e M transações usam esta categoria", Desativar/Reativar, Salvar.
- Lançamento: "Categoria (opcional)" filtrada pelo tipo (despesa/receita), só ativas; Transações: subtítulo "Mercado · Conta principal".
- [ ] `flutter analyze` + `flutter test`; **commit** `feat(app): categorias e regras em Mais` e `feat(app): categoria no lançamento`.

## PR 4 — `feat/app-regras`: regras no app

### Task 9: regras no app

**Files:** Create `app/lib/features/categorias/data/regra.dart`, `cubit/{regras_cubit,editar_regra_cubit}.dart`, `ui/editar_regra_tela.dart`; Modify repositório, `categorias_regras_tela.dart`, router; Tests.

- Aba Regras: texto da ordem, seções "Manuais" (categoria + "Só <conta>"/"Todas as contas") e "Aprendidas na revisão" (categoria + "Usada N vezes"), FAB "Nova regra".
- Editar regra: padrão (ajuda da normalização), categoria (ativas), conta ("Todas as contas" + ativas), nota "Casa com N rascunhos agora: <descrição>, <data>", nota "Aprendida na revisão em <data>, usada N vezes. Salvar uma mudança a torna manual." (só aprendida), Excluir (confirma) e Salvar; depois de salvar, snackbar com os rascunhos casados.
- [ ] `flutter analyze` + `flutter test`; **commit** `feat(app): regras de classificação`.

## Fechamento

- Docs: arquitetura §7.3, CLAUDE.md (features do app, specs), README se citar telas.
- Revisão final do diff; PRs empilhados abertos; card do Trello em "Em revisão (PR)".
- Nota na pasta de notas: explicação curta e perguntas de entrevista.
