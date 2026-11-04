# Conexões da Pluggy pelo app: cadastro de itemId, vínculo de contas e estado do sync

**Status:** decidida em 2026-10-20, revisando as telas antes da S2. Complementa a spec `2026-10-19-pluggy-spike-design.md`.

## Contexto

No uso pessoal do Meu Pluggy não existe endpoint para listar itens (`GET /v2/items`): o `itemId` de cada banco é copiado do dashboard da Pluggy e precisa ser guardado por nós. A spec do spike já previa um fluxo no app para a reautorização anual (o item renovado pode ter id novo), mas não dizia como a **primeira** conexão de um banco entra no backend, como as contas da Pluggy se ligam às contas do app, nem onde o usuário vê se o sync está funcionando.

## Decisão

### Cadastro do itemId pelo app

- A tela **Open Finance** (em Mais) tem "Adicionar conexão": o usuário cola o `itemId` e o backend valida com `GET /items/{id}` antes de salvar, mostrando o banco encontrado para confirmar.
- O mesmo campo serve para a **renovação anual**: o item novo é associado à `conexao_pluggy` existente (a conexão guarda o `item_id` atual; o antigo deixa de ser lido).
- A tela explica em texto curto onde achar o `itemId` (dashboard da Pluggy → Demo da aplicação → item do conector MeuPluggy).
- São endpoints de **escrita no nosso banco** (`conexao_pluggy`, vínculos em `conta`). A integração com a Pluggy continua **somente leitura**: o cliente em `modulos/pluggy/client.py` só faz GET (além do `/auth`).

### Vínculo de contas

Depois de validar o item, o backend lê `GET /accounts?itemId=` e o app mostra cada conta encontrada com duas opções:

- **Criar nova** (padrão): cria a `conta` já vinculada (`pluggy_account_id`).
- **Vincular a uma existente:** liga a conta da Pluggy a uma `conta` criada antes à mão (por exemplo, para importar OFX). O app sugere o vínculo quando os 4 últimos dígitos do número batem.

`conta` ganha `conexao_pluggy_id` (FK nula: de qual conexão a conta recebe dados) e `pluggy_numero_final` (text, nulo): os 4 últimos dígitos do `number` da Pluggy, gravados no vínculo. Servem para sugerir o casamento na renovação, quando o item antigo já não responde. O número completo não é guardado; a decisão final é sempre do usuário na tela.

### Desativar e reativar, sem excluir

- Uma conexão pode ser **desativada**: o sync para de lê-la e o histórico fica. Não há exclusão pelo app (irreversível e quase nunca necessária).
- As contas vinculadas **continuam ativas**, só sem sync; a conta mostra "sem Open Finance" e segue aceitando OFX/CSV e lançamento manual. Desativar a conta é decisão separada (`conta.ativa`).
- `conexao_pluggy` ganha `ativa` (bool, padrão verdadeiro).
- A conexão desativada pode ser **reativada** pelo app (decidido em 2026-10-31, no design da tela Open Finance). Reativar revalida o item com `GET /items/{id}` e volta `ativa` para verdadeiro; as contas vinculadas voltam a receber dados no próximo sync (ou no "Buscar agora"), e a janela de 40 dias cobre o que faltou se a pausa foi curta. Se o item não responde mais (por exemplo, a renovação gerou um id novo) ou o consentimento venceu durante a pausa, o app leva ao fluxo de renovação, que associa o item novo à mesma conexão.

### "Buscar agora"

- O item proxy **não pode ser atualizado** via API; a Pluggy atualiza os dados uma vez por dia. O botão "Buscar agora" roda só o **nosso** sync (relê a janela de 40 dias), útil logo depois de cadastrar ou renovar uma conexão.
- Limite de **1 vez por hora** por conexão, com o texto "A Pluggy atualiza os dados uma vez por dia". Não é polling: o cron continua às 07:00, com nova tentativa às 13:00.

### Estado do sync

- **Tela Open Finance**, uma linha por conexão: banco, status, último sync bem-sucedido, próximo horário, último erro em linguagem simples, validade do consentimento e contas vinculadas.
- **Card no Início só quando há problema**, nunca para dizer que está tudo bem:

| Gatilho | Condição |
|---|---|
| Consentimento vencido | `consentimento_expira_em` já passou |
| Sync com erro | o sync das 07:00 e a nova tentativa das 13:00 falharam |
| Sem dados novos | mais de 30 h sem sync bem-sucedido (24 h + folga para a nova tentativa) |
| Consentimento vencendo | vence em 30 dias ou menos |

Com mais de um problema, o card mostra só o mais grave, nessa ordem (vencido > erro > sem dados novos > vencendo); a tela Open Finance mostra todos.

### Decisões do código (2026-11-04)

Tomadas ao implementar o card "S7 · Vínculo de contas e aviso de consentimento", sobre o design aprovado (página Open Finance do canvas) e o sync do PR anterior. API conferida no MCP `pluggy-docs`.

- **Rotas** em `/pluggy`, tag `pluggy`: `GET /conexoes` (lista com o estado e o problema mais grave), `POST /conexoes/previa` (valida o `itemId` e lista as contas da Pluggy com a sugestão de vínculo, sem gravar), `POST /conexoes` (cria a conexão com os vínculos), `POST /conexoes/{id}/renovacao` (item novo na mesma conexão, com os vínculos), `PUT /conexoes/{id}` (`ativa`: desativar ou reativar) e `POST /conexoes/{id}/sync` ("Buscar agora").
- **Prévia:** `GET /items/{id}` e `GET /accounts?itemId=`. Item que não existe é 422 no campo `item_id`; item já cadastrado em outra conexão também. Cada conta vem com os 4 últimos dígitos e a sugestão: a conta do app ativa, do mesmo tipo, com o mesmo `pluggy_numero_final`, ou, na primeira conexão, com o mesmo final no nome (ainda não há número gravado). Conta da Pluggy já vinculada a outra conexão não aparece de novo.
- **Tipos:** `BANK` (corrente ou poupança) vira `corrente`; `CREDIT` vira `cartao_credito`. Cartão novo usa os dias de `creditData.balanceCloseDate` e `balanceDueDate` e o `creditLimit`, e paga pela primeira corrente do mesmo vínculo (criada ou vinculada); sem as datas na Pluggy, ou sem corrente no vínculo, a opção "criar nova" fica fora para o cartão e a tela pede o vínculo a um cartão existente.
- **Conta nova** recebe o nome da Pluggy, a instituição do conector, saldo inicial zero na data de hoje e o vínculo. Vincular a uma existente grava o vínculo e o final; o tipo precisa bater.
- **Renovação:** grava o item novo e os vínculos (as contas casam pelo final, confirmadas na tela) e marca `renovada_em`. No primeiro sync depois dela, uma transação nova que casa com uma da mesma conta, da Pluggy, por (data local, valor, descrição original) só troca o `id_externo`; depois desse sync, vale de novo a regra de que id novo é transação nova.
- **Reativar** confere o item (`GET /items/{id}`); item que não responde é 422 e a tela leva à renovação.
- **Problema** de cada conexão ativa, nesta ordem: `vencido` (consentimento já passou), `erro` (as duas tentativas do dia falharam: `ultimo_erro` e nenhum sucesso desde as 07:00 de hoje, passada a repescagem das 13:00), `sem_dados` (mais de 30 h desde o último sucesso) e `vencendo` (consentimento em 30 dias ou menos). A lista devolve o de cada conexão e o mais grave entre todas, que o Início mostra.
- **"Buscar agora"** roda o sync daquela conexão; com menos de 1 hora desde `ultima_tentativa_em`, responde 429 com o horário a partir do qual pode buscar de novo, que a lista também traz.

## Alternativas consideradas

- **Comando de terminal (`python -m app.adicionar_conexao`):** em produção exige ssh na VPS a cada conexão e a cada renovação anual.
- **Variável de ambiente com a lista de itemIds:** editar o `.env` na VPS e reiniciar; e não resolve o vínculo de contas.
- **Criar uma `conta` automaticamente para cada conta da Pluggy:** duplicaria as contas criadas à mão para importar OFX antes da S7.
- **Guardar o número completo da conta:** mais dado pessoal no banco sem ganho; 4 dígitos bastam para sugerir.
- **Excluir conexão:** irreversível; desativar cobre o caso de deixar de usar um banco.
- **Card de sync sempre visível no Início:** ocupa a tela principal para dizer que nada mudou.
- **"Buscar agora" sem limite:** convida a polling, que não traz dado novo (o proxy só muda a cada ~24 h).

## Consequências

- O `itemId` sozinho não dá acesso a nada sem o client id/secret, que ficam só no backend; digitá-lo no celular não expõe segredo.
- Novos endpoints protegidos por `UsuarioDep`: listar, cadastrar/renovar, desativar e reativar conexões; vincular contas; "buscar agora". Entram no card da S7.
- `conexao_pluggy.ultimo_sync_em` passa a significar "último sync bem-sucedido"; a tabela ganha `ultima_tentativa_em` (timestamptz, nulo), a última execução com ou sem sucesso, que o limite do "Buscar agora" e o gatilho "sync com erro" usam.
- O app da S2 já mostra a entrada Open Finance em Mais como "em breve".
