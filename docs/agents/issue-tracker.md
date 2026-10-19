# Issue tracker: GitHub

Issues e specs deste repositório ficam nas GitHub Issues. Use o `gh` CLI em todas as operações.

O cronograma por semana fica num quadro do Trello (link no `CLAUDE.local.md`). O card da semana aponta para a issue; a issue não aponta para o Trello.

## Convenções

- **Criar issue**: `gh issue create --title "..." --body "..."`. Use heredoc para corpo com várias linhas.
- **Ler issue**: `gh issue view <number> --comments`, filtrando comentários com `jq` e buscando também os labels.
- **Listar issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` com os filtros `--label` e `--state` adequados.
- **Comentar**: `gh issue comment <number> --body "..."`
- **Aplicar / remover labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Fechar**: `gh issue close <number> --comment "..."`
- **PR que resolve uma issue**: incluir `Closes #<number>` na descrição do PR.

O repositório é inferido do `git remote -v`; o `gh` faz isso sozinho dentro do clone.

## Pull requests como superfície de triagem

**PRs como superfície de pedidos: não.** _(Mude para `sim` se este repositório tratar PRs externos como pedidos de funcionalidade; o `/triage` lê esta flag.)_

Com `sim`, PRs passam pelos mesmos labels e estados das issues, usando os equivalentes `gh pr`:

- **Ler PR**: `gh pr view <number> --comments` e `gh pr diff <number>` para o diff.
- **Listar PRs externos para triagem**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`, mantendo só `authorAssociation` igual a `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR` ou `NONE` (descartar `OWNER`/`MEMBER`/`COLLABORATOR`).
- **Comentar / label / fechar**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

O GitHub usa a mesma numeração para issues e PRs; um `#42` solto pode ser qualquer um dos dois: resolva com `gh pr view 42` e, se falhar, `gh issue view 42`.

## Quando um skill disser "publicar no issue tracker"

Crie uma GitHub issue.

## Quando um skill disser "buscar o ticket relevante"

Rode `gh issue view <number> --comments`.

## Operações de wayfinding

Usadas pelo `/wayfinder`. O **mapa** é uma única issue, com issues **filhas** como tickets.

- **Mapa**: uma issue com o label `wayfinder:map`, contendo o corpo Notes / Decisions-so-far / Fog. `gh issue create --label wayfinder:map`.
- **Ticket filho**: issue ligada ao mapa como sub-issue do GitHub (`gh api` no endpoint de sub-issues). Onde sub-issues não estiverem ativas, adicione o filho a uma task list no corpo do mapa e coloque `Part of #<mapa>` no topo do corpo do filho. Labels: `wayfinder:<tipo>` (`research`/`prototype`/`grilling`/`task`). Depois de assumido, o ticket é atribuído a quem conduz.
- **Bloqueio**: as **dependências nativas de issue** do GitHub, a representação canônica e visível na interface. Adicione uma aresta com `gh api --method POST repos/<owner>/<repo>/issues/<filho>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, onde `<blocker-db-id>` é o **database id** numérico do bloqueador (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _não_ o `#number` nem o `node_id`). O GitHub informa `issue_dependencies_summary.blocked_by` (só bloqueadores abertos, a trava real). Onde dependências não estiverem disponíveis, use uma linha `Blocked by: #<n>, #<n>` no topo do corpo do filho. Um ticket está desbloqueado quando todos os bloqueadores estão fechados.
- **Consulta de fronteira**: liste os filhos abertos do mapa (`gh issue list --state open`, restrito às sub-issues / task list do mapa), descarte os que têm bloqueador aberto (`issue_dependencies_summary.blocked_by > 0`, ou issue aberta na linha `Blocked by`) ou responsável atribuído; o primeiro na ordem do mapa vence.
- **Assumir**: `gh issue edit <n> --add-assignee @me`, a primeira escrita da sessão.
- **Resolver**: `gh issue comment <n> --body "<resposta>"`, depois `gh issue close <n>`, depois acrescente um ponteiro de contexto (resumo + link) em Decisions-so-far no mapa.
