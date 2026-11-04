#!/usr/bin/env bash
# Sync da Pluggy em produção: roda o job num container de vida curta da api,
# na pasta do compose.prod.yml. Chamado pelos timers do systemd:
#   financas-sync.timer             07:00 (America/Fortaleza)
#   financas-sync-repescagem.timer  13:00, com --repescagem (só as que falharam)
# À mão, pelo systemd, para o log ir para o mesmo lugar:
#
#   sudo systemctl start financas-sync
#   sudo journalctl -u financas-sync -e
#
# Credenciais da Pluggy (PLUGGY_CLIENT_ID e PLUGGY_CLIENT_SECRET) no .env.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

docker compose -f compose.prod.yml --env-file .env --env-file versao.env \
  run --rm -T --no-deps api python -m app.jobs.sync_pluggy "$@"
