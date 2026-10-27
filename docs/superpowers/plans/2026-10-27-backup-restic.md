# Backup restic → B2 com restauração testada — plano de implementação

> **Para agentes:** use superpowers:executing-plans para executar tarefa por tarefa. Passos com checkbox (`- [x]`).

**Objetivo:** backup diário do Postgres de produção, cifrado com restic no servidor e enviado ao Backblaze B2, com retenção de 30 dias, alerta de falha e uma restauração testada num banco limpo antes do uso real (S5).

**Arquitetura:** `deploy/backup.sh` (pg_dump → restic backup → forget --prune → check), chamado por um systemd timer; restic no container `restic` do `compose.prod.yml` (profile `backup`); segredos em `/opt/financas/restic.env`; aviso ao healthchecks.io; `deploy/testar-restauracao.sh` restaura num Postgres temporário e compara com a produção.

**Spec:** `docs/superpowers/specs/2026-10-19-hospedagem-deploy-design.md`, seção "Backup em detalhe (2026-10-27)". Este plano não repete os motivos.

## Restrições globais

- Repositório público: nenhum segredo, endpoint/bucket real, nome da tailnet ou valor real em código, docs ou commits. Exemplos com `<bucket>`, `<endpoint-s3-do-b2>`.
- Sem dependência nova no projeto. Imagem `restic/restic:0.19.1` (oficial). O MinIO só existe no teste local, fora do repositório.
- O deploy continua idempotente: o `implantar.sh` não muda; o `deploy.yml` só copia mais arquivos.
- Comandos na VPS só com o Yago acompanhando. Contas e credenciais (B2, healthchecks.io) são do Yago; o Claude não cria conta nem digita credencial.

## PR 1 — scripts, compose, units e docs

- [x] `deploy/compose.prod.yml`: serviço `restic` (profile `backup`, `hostname` fixo, `env_file` `restic.env` com `required: false`, `./backup:/backup:ro`, volume `restic_cache`).
- [x] `deploy/restic.env.example`: `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `BACKUP_PING_URL`, sem valores, com o comando para gerar a senha. `deploy/.env.example` aponta para ele.
- [x] `deploy/backup.sh`: confere o `restic.env`; avisa `/start`; `pg_dump -Fc -Z0` para `backup/financas.dump` (pasta 700); `restic backup --tag diario`; `forget --tag diario --keep-daily 30 --prune`; `check`; `trap` apaga o dump e avisa `/<código de saída>`.
- [x] `deploy/testar-restauracao.sh [snapshot]`: `restic dump` → Postgres 16 temporário com `--network none` → `pg_restore --exit-on-error --no-owner --no-acl` → compara tabelas, contagens e `alembic_version` com a produção (`diff`) → `trap` remove container e arquivos.
- [x] `deploy/systemd/financas-backup.service` e `.timer` (03:30 `America/Fortaleza`, `Persistent=true`, `RandomizedDelaySec`).
- [x] `.github/workflows/deploy.yml`: o `scp` também copia `backup.sh`, `testar-restauracao.sh` e os units.
- [x] Teste local (scratchpad, fora do repo): stack `db` do `compose.prod.yml` com projeto isolado + MinIO na mesma rede + dados fictícios; rodar `backup.sh` duas vezes (a segunda deduplica), `testar-restauracao.sh` (passa), alterar uma linha e rodar de novo (acusa diferença), simular `pg_dump` falhando (sai ≠ 0, sem snapshot novo). `shellcheck` nos scripts (container, só local).
- [x] Docs: `docs/runbooks/backup-restauracao.md` (rotina, conferir, restaurar teste, desastre com VPS perdida); `CLAUDE.md` (Produção: preparação do servidor passo 8, comandos de backup; Environment Variables; Documentation Map); `docs/arquitetura.md` (§5 e §8).
- [x] PR, CI verde, card em "Em revisão (PR)".

## Na VPS (com o Yago, depois do merge e do deploy)

- [x] Yago: conta B2, bucket privado com "Keep only the last version", application key restrita ao bucket, conta sem cartão (limitada ao gratuito; Caps & Alerts só se houver cartão); conta healthchecks.io com check de 1 dia + 2 h de tolerância (passo a passo no runbook).
- [x] `restic.env` (600) na VPS com a senha gerada lá; senha copiada para o gerenciador de senhas.
- [x] `dc run --rm restic init`; instalar os units; `sudo systemctl start financas-backup`; conferir journal, `restic snapshots` e o ping no healthchecks.io.
- [x] `bash testar-restauracao.sh` logo depois do backup; registrar o resultado (data e "OK", sem números) no runbook.
- [x] Medir RAM do container restic durante o backup (`docker stats`).
- [x] Card em "Concluído"; nota de explicação e perguntas de entrevista na pasta de notas da sessão.
