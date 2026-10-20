#!/usr/bin/env bash
# Regera o cliente Dart da API em app/packages/api_client/ a partir do OpenAPI do FastAPI.
# Rode sempre que um endpoint ou schema mudar; o resultado é commitado (menos os .g.dart).
#
# Precisa de: uv, Docker rodando e Dart (vem com o Flutter).
# Não sobe a API nem lê o backend/.env: importar app.main não carrega a configuração.
set -euo pipefail

# Imagem fixada por digest: a mesma versão gera o mesmo código em qualquer máquina.
IMAGEM_GERADOR="openapitools/openapi-generator-cli:v7.26.0@sha256:a304ddf1e2e5f24f68fa3153568d6174cea4959d09aa8e3db6d526fd0782326d"

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="app/packages/api_client"

echo "1/3 Exportando openapi.json do FastAPI..."
# Esvazia a pasta (sem apagá-la: no Windows, pasta aberta num terminal ou editor
# não pode ser removida) para não sobrar modelo de schema que saiu da API.
mkdir -p "${RAIZ}/${DESTINO}"
find "${RAIZ:?}/${DESTINO}" -mindepth 1 -delete
(
  cd "${RAIZ}/backend"
  # O arquivo é escrito pelo Python em UTF-8 (o stdout no Windows não é UTF-8).
  uv run python -c '
import json, sys
from app.main import app
with open(sys.argv[1], "w", encoding="utf-8", newline="\n") as arquivo:
    json.dump(app.openapi(), arquivo, ensure_ascii=False, indent=2)
    arquivo.write("\n")
' "${RAIZ}/${DESTINO}/openapi.json"
)

echo "2/3 Gerando o cliente dart-dio (built_value)..."
# decimal=String: dinheiro chega no contrato como {"type": "string", "format": "decimal"},
# mas o dart-dio traduz o formato "decimal" para double. O repositório do app
# converte a String em Decimal; double nunca aparece.
opcoes_docker=(--rm)
if command -v cygpath >/dev/null 2>&1; then
  # Git Bash no Windows: caminho no formato C:/... e sem conversão automática de /local.
  export MSYS_NO_PATHCONV=1
  volume="$(cygpath -m "${RAIZ}"):/local"
else
  # Linux: gera os arquivos com o usuário atual, não com root.
  opcoes_docker+=(--user "$(id -u):$(id -g)")
  volume="${RAIZ}:/local"
fi
docker run "${opcoes_docker[@]}" -v "${volume}" "${IMAGEM_GERADOR}" generate \
  --input-spec "/local/${DESTINO}/openapi.json" \
  --generator-name dart-dio \
  --output "/local/${DESTINO}" \
  --additional-properties "pubName=api_client,pubVersion=0.1.0,serializationLibrary=built_value" \
  --type-mappings "decimal=String" \
  --global-property "apiTests=false,modelTests=false,apiDocs=false,modelDocs=false"

echo "3/3 Rodando o build_runner do pacote gerado (.g.dart)..."
(
  cd "${RAIZ}/${DESTINO}"
  dart pub get
  dart run build_runner build
)

echo "Cliente gerado em ${DESTINO}/."
