# Importação de OFX — plano de implementação

> **Para agentes:** use superpowers:executing-plans para executar tarefa por tarefa. Passos com checkbox (`- [ ]`).

**Objetivo:** importar o OFX do extrato da conta e o da fatura do cartão do Nubank como rascunhos, com idempotência por arquivo e por linha, possível duplicata contra o que já estava no app, dados da fatura e saldo do extrato gravados, e desfazer enquanto nada foi confirmado. No app, a tela "Importar extrato" (seletor e Compartilhar), o resumo, o histórico e as entradas em Mais e na Revisão.

**Arquitetura:** módulo novo `backend/app/modulos/importacao/` — `models.py` (`Importacao`), `parsers/ofx.py` (puro: bytes → `ExtratoOfx`), `duplicatas.py` (puro: `marcar_duplicatas`), `service.py` (importar, listar, obter, desfazer), `schemas.py`, `router.py` (tag `importacoes`). `snapshot_saldo` em `contas/models.py`. No app, feature `lib/features/importacao/` (data, cubit, ui).

**Stack:** FastAPI síncrono (`UploadFile`, `Form`), SQLAlchemy 2.0, Alembic, pytest + testcontainers; Flutter, flutter_bloc, freezed, go_router, cliente gerado `dart-dio` (multipart), `file_picker`, `receive_sharing_intent`.

**Spec:** `docs/superpowers/specs/2026-10-28-importacao-design.md`. Design: página "Importação" do canvas (11 telas). Este plano não repete os motivos.

## Restrições globais

- Migration só acrescenta (`down_revision = "2716d2f6a543"`): tabelas `importacao` e `snapshot_saldo`, coluna `transacao.importacao_id`.
- Fixtures OFX **fictícias**, escritas à mão no formato das amostras (`backend/tests/fixtures/ofx/`): "Banco Exemplo", "Padaria Pão Quente", "Mercado do Bairro", "Loja Fictícia", FITIDs UUID inventados. Amostras reais só pela estrutura mascarada.
- Uma tag por rota, sem `_`: `importacoes_importar` → `ImportacoesApi.importar()`.
- Erros: `CampoInvalido` → 422 (`arquivo` ou `conta_id`); FITID repetido → 422 com `linhas_repetidas`; importação inexistente → 404 "Importação não encontrada."; desfazer com confirmada → 409.
- Dependências novas só no app (`file_picker`, `receive_sharing_intent`), aprovadas em 28/10. Backend sem dependência nova (`python-multipart` já vem com `fastapi[standard]`).

## PR 1 — spec e plano (`docs/importacao-spec`)

- [x] Spec `2026-10-28-importacao-design.md`, arquitetura (§7.3, §7.5, relacionamentos, pastas), `CLAUDE.md` (fontes de dados, specs) e link na spec da revisão.
- [x] Este plano.

## PR 2 — backend (`feat/importacao-api`, empilhado no PR 1)

### Tarefa 1: parser OFX (TDD, `tests/unit/test_parser_ofx.py`)

- [x] Fixtures: `conta.ofx` (UTF-8 com acento, `BANKMSGSRSV1`, crédito, débito, "Pagamento de fatura", "Estorno", `LEDGERBAL`), `fatura.ofx` (`CREDITCARDMSGSRSV1`, compra + `IOF de "…"` com o mesmo FITID, parcela " - Parcela 3/10", "Pagamento recebido", estorno, `BALAMT` negativo), `fitid_repetido.ofx`, `sem_fechamento.ofx` (folhas sem `</TAG>`, cp1252).
- [x] Testes: tipo do extrato; período; data dos 8 dígitos; valor `Decimal` com sinal; `MEMO`/`NAME`; `FITID:iof`; repetido → `FitidRepetido` com as linhas; folhas abertas; cp1252; valor zero descartado; texto que não é OFX e OFX sem as duas marcas → `FormatoNaoReconhecido`; campo obrigatório faltando → idem, com a linha; `LEDGERBAL` (`BALAMT`, `DTASOF`); parcela (N, M, descrição base).
- [x] Implementar `parsers/ofx.py`: `ler_ofx(dados: bytes) -> ExtratoOfx` (`tipo`, `periodo_inicio`, `periodo_fim`, `saldo`, `linhas: list[LinhaOfx]` com `id_externo`, `data`, `valor` com sinal, `descricao`, `parcela`).

### Tarefa 2: possível duplicata (TDD, `tests/unit/test_duplicatas.py`)

- [x] Tabela de casos: mesmo valor/sentido ±2 dias casa; 3 dias não; sentido oposto não; um para um (duas novas iguais e uma existente → só a de data mais perto); desempate por data e id; resultado estável.
- [x] `duplicatas.py`: `marcar_duplicatas(novas, existentes) -> dict[indice_nova, id_existente]`, com `Protocol` como `pareamento.py`.

### Tarefa 3: modelo e migration

- [x] `Importacao` (spec, "Modelo de dados"), `SnapshotSaldo`, `Transacao.importacao_id`; `check_enum` de `fonte` e `status`.
- [x] Migration `cria_importacao_e_snapshot`; `test_migrations.py` continua passando (upgrade/downgrade).

### Tarefa 4: service de importação (TDD, `tests/integration/test_importacoes.py`)

- [x] `importar(sessao, conta_id, nome_arquivo, dados, hoje)`: tamanho; hash → já importada; parser; conta × tipo; linhas → transações (tipos da tabela da spec, `pagamento_fatura` sem fatura, "Pagamento recebido" fora); já importadas (qualquer status); duplicatas contra a conta; parcelas (reaproveitar compra ±3 dias); fatura (competência mais perto de `DTEND`, limites dos vizinhos, valor e fechamento, antes/gravado, realocar manuais); snapshot (substitui); um commit só no fim.
- [x] `realocar_compras` filtra `fonte = manual` (teste em `test_importacoes.py`: compra importada não muda de fatura ao editar o fechamento).
- [x] `listar`, `obter` (contagens de confirmadas/pendentes na leitura, `pode_desfazer`).
- [x] `desfazer`: 409 com confirmada; apaga transações, compras órfãs, snapshot, importação; restaura a fatura só se ainda estiver com os valores gravados; realoca manuais.

### Tarefa 5: rotas e contrato

- [x] `router.py` com `POST` multipart (`arquivo: UploadFile`, `conta_id: Annotated[uuid.UUID, Form()]`), `GET`, `GET {id}`, `DELETE {id}`; 201/200 no `POST`; `ErroImportacao` no 422; incluído em `main.py`.
- [x] Testes de rota: multipart feliz (conta e fatura), já importado (200), FITID repetido (422 com linhas, nada gravado), formato, conta incompatível, carteira, conta desativada, desfazer (204/409/404), arquivo grande.
- [x] `test_operation_ids.py` continua passando; `bash scripts/gerar-cliente-api.sh` (o contrato novo vai neste PR).
- [x] ruff, pytest, code review, PR.

## PR 3 — app (`feat/importacao-app`, empilhado no PR 2)

### Tarefa 6: dependências e Android

- [ ] `flutter pub add file_picker receive_sharing_intent`; intent-filter `ACTION_SEND` (`application/octet-stream`, `application/x-ofx`, `text/plain`) no `AndroidManifest.xml`; `test/android/manifesto_test.dart` cobre o filtro.

### Tarefa 7: dados

- [ ] `features/importacao/data/importacao.dart` (freezed: `Importacao`, `ResultadoImportacao` com `jaImportada`, `LinhaRepetida`), `importacoes_repositorio.dart` (multipart pelo cliente gerado; `ErroApi` com `linhasRepetidas`), `tipo_arquivo.dart` (puro: reconhece OFX de fatura pela marca, para sugerir a conta).
- [ ] Repositório falso em `test/apoio/importacoes_falso.dart`; testes do repositório com o adaptador falso.

### Tarefa 8: cubits

- [ ] `ImportarCubit` (arquivo escolhido ou compartilhado, conta sugerida pela última importação do mesmo tipo, enviando, erros por campo, FITID repetido, já importado) e `ImportacaoCubit` (resumo, desfazer). bloc_test.

### Tarefa 9: telas e entradas

- [ ] `ImportarTela` (vazio, arquivo escolhido, compartilhado, processando, erros), `ResumoImportacaoTela` (conta, cartão, sem desfazer), confirmação do desfazer.
- [ ] Rotas no go_router; Mais → "Importar extrato"; Revisão: ícone no cabeçalho e botão do vazio; Compartilhar → tela preenchida (após o login, se a sessão expirou) com o X voltando ao Início. Após importar/desfazer, recarregar a Revisão.
- [ ] Widget tests das telas e do fluxo no `app_test.dart`; `flutter analyze`, `flutter test`; `CLAUDE.md` (stack do app) e README se mudar algo de uso.
- [ ] Teste no aparelho com o ambiente local `financas-celular` e fixtures fictícias; code review, PR.
