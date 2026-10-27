#!/usr/bin/env bash
# Testa a restauração de um backup: baixa o dump de um snapshot, restaura num
# Postgres 16 temporário e sem rede, e compara com a produção as tabelas, a
# contagem de linhas de cada uma e a versão das migrations (alembic_version).
# Roda no servidor, na pasta do compose.prod.yml, logo depois de um backup:
# as contagens só batem se ninguém escreveu no banco no meio.
#
#   sudo systemctl start financas-backup && bash testar-restauracao.sh
#   bash testar-restauracao.sh 1a2b3c4d        # um snapshot específico
#
# Do banco de produção, só lê as contagens. Passo a passo e o caso da VPS
# perdida em docs/runbooks/backup-restauracao.md.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

snapshot="${1:-latest}"
container=financas-restauracao
tmp="$(mktemp -d)" # permissão 700: o dump tem os dados reais

compose() {
  docker compose -f compose.prod.yml --env-file .env --env-file versao.env "$@"
}

limpar() {
  docker rm -f "$container" > /dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap limpar EXIT

# Uma linha por tabela do schema public com a contagem de linhas, mais a
# versão das migrations. O query_to_xml roda um count(*) em cada tabela
# dentro da mesma consulta.
consulta="
select 'migrations ' || version_num from alembic_version
union all
select 'tabela ' || table_name || ' ' || (xpath('/row/n/text()', query_to_xml(
         format('select count(*) as n from public.%I', table_name), false, true, '')))[1]::text
  from information_schema.tables
 where table_schema = 'public' and table_type = 'BASE TABLE'
order by 1"

echo "1/4 Baixando o dump do snapshot $snapshot..."
compose run --rm -T restic dump "$snapshot" /backup/financas.dump > "$tmp/financas.dump"
echo "    $(du -h "$tmp/financas.dump" | cut -f1)"

echo "2/4 Subindo um Postgres temporário, sem rede..."
# Sobra de uma execução interrompida.
docker rm -f "$container" > /dev/null 2>&1 || true
# Sem rede, ninguém além do `docker exec` o alcança; por isso, sem senha.
docker run -d --name "$container" --network none \
  -e POSTGRES_DB=financas -e POSTGRES_USER=financas -e POSTGRES_HOST_AUTH_METHOD=trust \
  postgres:16-alpine -c shared_buffers=32MB -c max_connections=5 > /dev/null
# Pelo TCP local: na primeira inicialização, o Postgres do container sobe só
# no socket, cria o banco e reinicia; o pg_isready no socket diria "pronto"
# cedo demais.
pronto() { docker exec "$container" pg_isready -q -h 127.0.0.1 -U financas -d financas; }
for _ in $(seq 60); do
  pronto && break
  sleep 1
done
pronto || { echo "O Postgres temporário não subiu em 60 s." >&2; exit 1; }

echo "3/4 Restaurando..."
docker exec -i "$container" pg_restore -U financas -d financas \
  --no-owner --no-acl --exit-on-error < "$tmp/financas.dump"

echo "4/4 Comparando com a produção..."
compose exec -T db psql -U financas -d financas -At -c "$consulta" > "$tmp/producao.txt"
docker exec "$container" psql -U financas -d financas -At -c "$consulta" > "$tmp/restaurado.txt"
if diff -u --label producao --label restaurado "$tmp/producao.txt" "$tmp/restaurado.txt"; then
  tabelas="$(grep -c '^tabela ' "$tmp/restaurado.txt")"
  versao="$(sed -n 's/^migrations //p' "$tmp/restaurado.txt")"
  echo "OK: snapshot $snapshot restaurado; $tabelas tabelas (com as contagens) e migrations em $versao, iguais à produção."
else
  echo "DIFERENTE da produção (acima). Se o banco recebeu escrita depois do" \
    "snapshot, rode um backup e teste de novo." >&2
  exit 1
fi
