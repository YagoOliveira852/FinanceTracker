#!/usr/bin/env bash
# Backup diário do banco de produção: pg_dump → restic (cifra aqui mesmo) →
# bucket do B2, com retenção de 30 dias. Roda no servidor, na pasta do
# compose.prod.yml, chamado pelo financas-backup.timer (systemd). À mão, pelo
# próprio systemd, para o log ir para o mesmo lugar:
#
#   sudo systemctl start financas-backup
#   sudo journalctl -u financas-backup -e
#
# Segredos em restic.env (ver restic.env.example). Motivos de cada passo na
# spec de hospedagem, "Backup em detalhe"; restauração em
# docs/runbooks/backup-restauracao.md.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

compose() {
  docker compose -f compose.prod.yml --env-file .env --env-file versao.env "$@"
}

# Avisa o healthchecks.io: `start` no início e o código de saída no fim. Sem
# BACKUP_PING_URL não avisa; uma falha do aviso não derruba o backup.
avisar() {
  [[ -n "$ping_url" ]] || return 0
  curl -fsS -m 10 --retry 3 -o /dev/null "$ping_url/$1" \
    || echo "Aviso: não consegui avisar o healthchecks.io ($1)." >&2
}

if [[ ! -f restic.env ]]; then
  echo "restic.env não encontrado em $PWD (ver restic.env.example)." >&2
  exit 1
fi
# Só esta variável é lida pelo shell; o resto do arquivo vai para o container.
ping_url="$(sed -n 's/^BACKUP_PING_URL=//p' restic.env | tail -n 1)"

dump=backup/financas.dump
terminar() {
  local codigo=$?
  # Não deixa cópia em claro do banco fora do volume do Postgres.
  rm -f "$dump"
  avisar "$codigo"
}
trap terminar EXIT
avisar start

# A pasta do dump, montada no container restic. O implantar.sh já a cria; se
# o Docker a tivesse criado para o bind mount (um `run` antes do primeiro
# deploy), ela seria do root e o dump não poderia ser gravado.
mkdir -p backup
if [[ ! -O backup ]]; then
  echo "A pasta $PWD/backup não é do usuário $(id -un). Corrija com:" \
    "sudo chown $(id -un): $PWD/backup" >&2
  exit 1
fi
chmod 700 backup

echo "1/4 pg_dump do banco..."
# Em arquivo, não num pipe para o restic: se o pg_dump falhar no meio, o
# script para aqui e nenhum snapshot pela metade é criado. Sem compressão: o
# restic deduplica entre os dias (só o que mudou sobe) e comprime depois.
compose exec -T db pg_dump -U financas -d financas --format=custom --compress=0 > "$dump"

echo "2/4 Enviando para o repositório ($(du -h "$dump" | cut -f1))..."
compose run --rm -T restic backup --tag diario /backup/financas.dump

# Um snapshot por dia nos 30 últimos dias que têm backup: se o backup parar,
# os antigos não somem. Só os de tag `diario`; um `--tag manual` fica até ser
# removido à mão.
echo "3/4 Aplicando a retenção..."
compose run --rm -T restic forget --tag diario --keep-daily 30 --prune

echo "4/4 Conferindo o repositório..."
compose run --rm -T restic check

echo "Backup concluído."
