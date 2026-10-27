#!/usr/bin/env bash
# Atualiza a stack de produção para uma versão da imagem da api. Roda no
# servidor, na pasta do compose.prod.yml e do .env:
#
#   bash implantar.sh sha-1a2b3c4
#
# O workflow deploy.yml copia este arquivo e o compose.prod.yml para a pasta e
# o chama por ssh; à mão, serve para voltar a uma versão anterior.
#
# A versão que subiu com sucesso fica em versao.env (TAG=...). Comandos do
# compose dados à mão leem esse arquivo também (ver CLAUDE.md), para um `up -d`
# não trocar a imagem por outra. O .env não é tocado.
set -euo pipefail

tag="${1:-}"
# Só a tag imutável do commit: `latest` muda a cada push e não dá para repetir.
if [[ ! "$tag" =~ ^sha-[0-9a-f]{7}$ ]]; then
  echo "uso: implantar.sh sha-<7 caracteres do commit>" >&2
  exit 2
fi

cd "$(dirname "${BASH_SOURCE[0]}")"
touch versao.env
# Pasta do dump do backup (backup.sh), montada no container restic. Criada
# aqui, pelo usuário do deploy, antes de qualquer `compose run restic`: se o
# Docker a criasse para o bind mount, ela seria do root.
mkdir -p -m 700 backup

# A TAG do ambiente vence a do versao.env na interpolação do compose.
compose() {
  TAG="$tag" docker compose -f compose.prod.yml --env-file .env --env-file versao.env "$@"
}

echo "1/4 Validando o compose e baixando $tag..."
compose config --quiet
compose pull

# Antes de trocar a api: se a migration falhar, a versão anterior segue no ar.
# Por isso cada migration precisa funcionar com o código da versão anterior.
echo "2/4 Aplicando as migrations..."
compose run --rm api alembic upgrade head

echo "3/4 Subindo a stack e esperando os healthchecks..."
compose up -d --wait --wait-timeout 180

printf 'TAG=%s\n' "$tag" > versao.env

echo "4/4 Em produção: $tag"
compose ps
