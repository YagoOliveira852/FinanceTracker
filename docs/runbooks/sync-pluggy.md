# Runbook: sync da Pluggy em produção

**Use quando:** for ligar o sync na VPS pela primeira vez, conferir se ele está rodando, rodar uma vez à mão ou investigar uma conexão com erro.

Decisões e motivos: plano `docs/superpowers/plans/2026-11-04-sync-pluggy.md` e specs `2026-10-19-pluggy-spike-design.md` e `2026-10-20-conexoes-pluggy-design.md`. Comandos gerais do servidor: `CLAUDE.md`, "Produção (VPS)".

## Como funciona

| Quando | O quê |
|---|---|
| 07:00 (`America/Fortaleza`) | `financas-sync.timer` → `sync.sh` → `python -m app.jobs.sync_pluggy`: todas as conexões ativas |
| 13:00 | `financas-sync-repescagem.timer` → `sync.sh --repescagem`: só as conexões cuja última tentativa falhou |

O job roda num container de vida curta da api (`dc run --rm api`), sem serviço permanente. Para cada conta vinculada, relê os últimos 40 dias: transações novas viram rascunho; o que sumiu da janela é apagado (rascunho) ou marcado como removido na origem (confirmada). O estado de cada conexão fica em `conexao_pluggy` (`ultimo_sync_em`, `ultima_tentativa_em`, `ultimo_erro`) e aparece no app em Mais → Open Finance.

| O quê | Onde |
|---|---|
| Script e units | `/opt/financas/{sync.sh,financas-sync*.service,financas-sync*.timer}`, copiados a cada deploy |
| Units instalados | `/etc/systemd/system/` (instalação à mão, abaixo) |
| Credenciais | `PLUGGY_CLIENT_ID` e `PLUGGY_CLIENT_SECRET` no `/opt/financas/.env` |
| Log | `sudo journalctl -u financas-sync -u financas-sync-repescagem` |

Nos comandos abaixo, `dc` é o alias de `CLAUDE.md`:

```bash
cd /opt/financas
alias dc='docker compose -f compose.prod.yml --env-file .env --env-file versao.env'
```

## Preparação (uma vez)

1. No dashboard da Pluggy, copie o client id e o client secret da aplicação de uso pessoal e acrescente ao `.env` da VPS (`PLUGGY_CLIENT_ID=` e `PLUGGY_CLIENT_SECRET=`). Não cole os valores em nenhum outro lugar.
2. Depois do deploy que trouxe o `sync.sh`, instale os units:

   ```bash
   sudo cp /opt/financas/financas-sync.service /opt/financas/financas-sync.timer \
     /opt/financas/financas-sync-repescagem.service /opt/financas/financas-sync-repescagem.timer \
     /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now financas-sync.timer financas-sync-repescagem.timer
   ```

3. Rode uma vez à mão e confira a saída (abaixo). Sem conexão cadastrada, a saída é "Nenhuma conexão para sincronizar."

## Conferir que está funcionando

```bash
systemctl list-timers 'financas-sync*'                  # última e próxima execução
systemctl status financas-sync                          # resultado da última (status=0/SUCCESS)
sudo journalctl -u financas-sync --since yesterday      # resumo por conexão
```

Cada conexão gera uma linha: "N novas, N atualizadas, N removidas, N marcadas como removidas", ou "erro — mensagem". O job sai com código 1 se alguma conexão falhou.

## Rodar à mão

```bash
sudo systemctl start financas-sync                      # o mesmo das 07:00, com log no journal
bash /opt/financas/sync.sh --repescagem                 # só as que falharam, saída no terminal
```

Não rode em laço: o item MeuPluggy é um proxy que a Pluggy atualiza uma vez por dia, e reler não traz dado novo.

## Conexão com erro

1. `dc exec db psql -U financas -d financas -c "select item_id, status, ultimo_sync_em, ultima_tentativa_em, ultimo_erro from conexao_pluggy;"`
2. Pela mensagem:
   - **"credenciais da Pluggy foram recusadas"**: confira `PLUGGY_CLIENT_ID`/`PLUGGY_CLIENT_SECRET` no `.env`;
   - **"não encontrou esta conexão"**: o item mudou (renovação anual) ou foi apagado no Meu Pluggy; renove a conexão pelo app;
   - **"sem resposta"** ou **"respondeu com erro"**: instabilidade da Pluggy; a repescagem das 13:00 tenta de novo;
   - **"Erro inesperado no sync"**: veja o traceback em `sudo journalctl -u financas-sync`.
