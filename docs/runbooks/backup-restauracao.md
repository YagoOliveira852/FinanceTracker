# Runbook: backup e restauração do banco de produção

**Use quando:** for conferir se o backup está rodando, testar uma restauração, voltar o banco de produção para um backup (dado apagado, migration que estragou dados) ou reconstruir tudo depois de perder a VPS.

Decisões e motivos: spec `docs/superpowers/specs/2026-10-19-hospedagem-deploy-design.md`, seção "Backup em detalhe". Comandos gerais do servidor: `CLAUDE.md`, "Produção (VPS)".

## Como funciona

Todo dia às 03:30 (`America/Fortaleza`), o `financas-backup.timer` (systemd) roda `/opt/financas/backup.sh` como `deploy`:

```
pg_dump (container db) → backup/financas.dump → restic backup (cifra no servidor) → bucket B2
                                              → restic forget --keep-daily 30 --prune
                                              → restic check
                                              → apaga o dump local; avisa o healthchecks.io
```

| O quê | Onde |
|---|---|
| Scripts e units | `/opt/financas/{backup.sh,testar-restauracao.sh,financas-backup.*}`, copiados a cada deploy |
| Units instalados | `/etc/systemd/system/financas-backup.{service,timer}` (instalação à mão, abaixo) |
| Segredos | `/opt/financas/restic.env` (600): repositório, senha do restic, application key do B2, URL de ping |
| Senha do restic | **também no gerenciador de senhas.** Sem ela, nenhum backup pode ser lido |
| Restic | container `restic` do `compose.prod.yml` (profile `backup`): `dc run --rm restic <comando>` |
| Log | `sudo journalctl -u financas-backup` (sem `sudo`, o `deploy` não vê as linhas do próprio systemd) |
| Alerta | e-mail do healthchecks.io quando o backup falha ou não roda em 26 h |

Nos comandos abaixo, `dc` é o alias de `CLAUDE.md`:

```bash
cd /opt/financas
alias dc='docker compose -f compose.prod.yml --env-file .env --env-file versao.env'
```

## Conferir que está funcionando

```bash
systemctl list-timers financas-backup.timer       # última e próxima execução
systemctl status financas-backup                  # resultado da última (status=0/SUCCESS)
sudo journalctl -u financas-backup --since yesterday   # saída completa
dc run --rm restic snapshots                      # um snapshot por dia, até 30 dias
dc run --rm restic stats --mode raw-data          # espaço ocupado no B2
```

O painel do healthchecks.io mostra o último aviso. Para rodar um backup fora de hora (antes de algo arriscado, por exemplo):

```bash
sudo systemctl start financas-backup              # espera terminar; log no journal
```

## Preparação (uma vez)

### 1. Backblaze B2 (Yago, no navegador)

1. Criar a conta B2 (backblaze.com, "B2 Cloud Storage"). Os primeiros 10 GB são gratuitos.
2. **Buckets → Create a Bucket:** nome único, *Files in Bucket* **Private**, *Object Lock* desativado. Anotar o **Endpoint** que aparece no bucket (`s3.<região>.backblazeb2.com`).
3. No bucket, **Lifecycle Settings → "Keep only the last version of the file"**. Sem isso, o `prune` só esconde arquivos e o espaço nunca é liberado.
4. **Application Keys → Add a New Application Key:** acesso só a esse bucket, *Read and Write*. Anotar o `keyID` e a `applicationKey`, que aparece uma vez só.
5. **Sem cartão cadastrado:** a conta fica limitada ao plano gratuito (10 GB) e não há cobrança. Se um limite gratuito for atingido, o B2 recusa a operação, o backup falha e o healthchecks.io avisa. Ao cadastrar um cartão, configure antes o **Caps & Alerts** com limite diário baixo para armazenamento, download e transações, com alerta por e-mail.

### 2. healthchecks.io (Yago, no navegador)

1. Criar a conta (plano gratuito) e um check `financas-backup`: *Period* **1 day**, *Grace* **2 hours**.
2. Copiar a *ping URL* (`https://hc-ping.com/<uuid>`). O e-mail da conta já vem como integração.

### 3. `restic.env` na VPS (Yago digita os segredos)

```bash
cd /opt/financas
umask 077                                         # o arquivo nasce com permissão 600
cat > restic.env <<EOF
RESTIC_REPOSITORY=s3:https://<endpoint-s3-do-b2>/<bucket>
RESTIC_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
BACKUP_PING_URL=
EOF
nano restic.env                                   # endpoint, bucket, keyID, applicationKey e ping URL
ls -l restic.env                                  # -rw------- deploy deploy
```

**Agora:** copie o `RESTIC_PASSWORD` para o gerenciador de senhas (com o nome do bucket e o endpoint). É a única cópia fora da VPS.

### 4. Criar o repositório e instalar o timer

```bash
dc run --rm restic init                           # "created restic repository ..."
sudo install -m 644 financas-backup.service financas-backup.timer /etc/systemd/system/
sudo systemd-analyze verify /etc/systemd/system/financas-backup.service
systemd-analyze calendar '*-*-* 03:30:00 America/Fortaleza'   # próxima execução em UTC
sudo systemctl daemon-reload
sudo systemctl enable --now financas-backup.timer
sudo systemctl start financas-backup              # primeiro backup, agora
sudo journalctl -u financas-backup -e --no-pager  # termina em "Backup concluído."
```

Quando os units mudarem no repositório, repita o `install` e o `daemon-reload` (o deploy só copia os arquivos para `/opt/financas`).

## Testar uma restauração

Refaça depois de mudar o backup e, no mínimo, a cada três meses. Logo depois de um backup, para as contagens baterem:

```bash
cd /opt/financas
sudo systemctl start financas-backup && bash testar-restauracao.sh
```

O script baixa o dump do snapshot (`restic dump`), sobe um Postgres 16 temporário **sem rede**, restaura com `pg_restore --exit-on-error` e compara com a produção as tabelas, as contagens de linhas e o `alembic_version`. No fim, apaga o container e o dump. Sucesso:

```
OK: snapshot latest restaurado; N tabelas (com as contagens) e migrations em <revisão>, iguais à produção.
```

Se aparecer `DIFERENTE`, o `diff` mostra a tabela. Uma escrita no banco depois do snapshot explica a diferença: rode de novo. Se a diferença continuar, o backup não está completo; investigue antes de confiar nele. Registre o resultado na tabela do fim deste arquivo, com data e "OK", sem números.

## Restaurar o banco de produção

Para voltar a produção a um snapshot (dado apagado por engano, migration que estragou dados). **Apaga o banco atual**, então antes guarde o estado de agora.

```bash
cd /opt/financas
dc run --rm restic snapshots                      # escolha o snapshot (ID) ou use latest
snapshot=latest

dc stop api                                       # ninguém escreve durante a troca
dc exec -T db pg_dump -U financas -d financas -Fc > backup/antes-da-restauracao.dump
dc run --rm -T restic dump "$snapshot" /backup/financas.dump > backup/restaurar.dump

dc exec -T db psql -U financas -d postgres \
  -c 'drop database financas with (force)' \
  -c 'create database financas owner financas'
dc exec -T db pg_restore -U financas -d financas --no-owner --exit-on-error < backup/restaurar.dump

# Sobe a api da versão no ar; aplica migrations se o snapshot for de antes da última.
bash implantar.sh "$(sed -n 's/^TAG=//p' versao.env)"
curl -fsS https://<maquina>.<tailnet>.ts.net/saude
rm backup/restaurar.dump                          # o antes-da-restauracao.dump só depois de conferir no app
```

Se o `pg_restore` falhar no meio, o banco fica incompleto: repita do `drop database` (com o mesmo dump ou com o `antes-da-restauracao.dump`).

## Desastre: a VPS foi perdida

Precisa só do que está fora dela: o login do B2 e a senha do restic no gerenciador de senhas.

1. **Servidor novo:** siga a "Preparação do servidor" de `CLAUDE.md` (passos 1 a 6). Antes do `tailscale up`, remova a máquina antiga no painel da Tailscale, para o nome `<maquina>` ficar livre e o `VPS_HOST` do GitHub continuar valendo. O `.env` novo pode ter segredos novos: a senha do Postgres é a do banco novo, e um `JWT_SECRET` novo só obriga a fazer login de novo no app.
2. **Primeiro deploy:** `gh workflow run deploy`. Ele copia os arquivos, cria um banco vazio com as migrations e sobe a api. **Não** rode o `criar_usuario`: o usuário vem no backup.
3. **`restic.env`:** como no passo 3 da preparação, mas com o `RESTIC_PASSWORD` **do gerenciador de senhas** (uma senha nova não abre o repositório). A application key pode ser a mesma ou uma nova, criada no painel do B2.
4. **Restaurar:** siga "Restaurar o banco de produção" (o banco vazio do passo 2 é o que será apagado). Os snapshots continuam na mesma série, porque o `hostname` do container restic é fixo.
5. **Timer:** passo 4 da preparação, sem o `init` (o repositório já existe).
6. Conferir no app: login, contas e últimos lançamentos.

**Ver os backups sem servidor nenhum** (do PC, com Docker), por exemplo para conferir que o repositório abre:

```bash
docker run --rm --env-file restic.env restic/restic:0.19.1 snapshots
docker run --rm --env-file restic.env restic/restic:0.19.1 dump latest /backup/financas.dump > financas.dump
```

O `restic.env` e o `financas.dump` no PC têm segredos e dados reais: apague os dois ao terminar. Os dumps estão no `.gitignore`, mas não deixe nenhum dos dois dentro do repositório.

## Problemas comuns

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `restic.env não encontrado` | Preparação não feita, ou arquivo em outra pasta | Passo 3 da preparação |
| `Fatal: wrong password or no key found` | `RESTIC_PASSWORD` diferente da usada no `init` | Copiar a senha do gerenciador de senhas |
| `A pasta .../backup não é do usuário deploy` | Um `dc run restic` antes do primeiro deploy fez o Docker criar a pasta como root | `sudo chown deploy: /opt/financas/backup` |
| `service "db" is not running` | Banco parado | `dc ps`, `dc up -d --wait` |
| `Access Denied` / `403` do B2 | Application key apagada, sem acesso ao bucket ou limite gratuito (ou do Caps & Alerts) atingido | Painel do B2: chave, bucket e uso em *Reports* |
| `repository is already locked` | Uma execução interrompida deixou trava | Confirmar que nenhum backup roda (`systemctl status financas-backup`) e `dc run --rm restic unlock` |
| Aviso do healthchecks.io sem erro no journal | Timer parado ou VPS desligada | `systemctl list-timers`; acesso pelo console da Locaweb |

## Registro de restaurações testadas

| Data | Onde | Snapshot | Resultado |
|---|---|---|---|
| 27/10/2026 | PC, repositório local e dados fictícios (teste dos scripts) | latest | OK; diferença detectada depois de uma escrita; `pg_dump` falhando não cria snapshot |
| 27/10/2026 | VPS, bucket do B2, banco de produção (`testar-restauracao.sh` logo após um backup) | latest | OK: 13 tabelas, contagens e `alembic_version` iguais à produção. Alerta do healthchecks.io conferido com uma falha real no primeiro backup |
