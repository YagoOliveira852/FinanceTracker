# syntax=docker/dockerfile:1
# Imagem da API. Duas etapas: o "builder" instala as dependências com o uv e a
# imagem final leva só o .venv pronto e o código (sem uv, sem cache, sem dev).
# Builda em linux/amd64 e linux/arm64: todas as dependências têm wheel nas duas.

# Mesma base nas duas etapas: o .venv aponta para o Python de /usr/local/bin.
ARG PYTHON_IMAGE=python:3.12-slim-trixie

FROM ${PYTHON_IMAGE} AS builder

COPY --from=ghcr.io/astral-sh/uv:0.12.23 /uv /bin/uv

# Bytecode compilado no build (o container não escreve no próprio código);
# cópia em vez de link, porque o cache do uv não vai para a imagem final;
# Python da imagem, nunca um baixado pelo uv.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# Só os arquivos de dependência: a camada fica em cache enquanto o uv.lock não muda.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=.python-version,target=.python-version \
    uv sync --locked --no-dev --no-install-project


FROM ${PYTHON_IMAGE}

# Usuário sem root e sem shell de login; o código fica do root, só para leitura.
RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY alembic.ini ./
COPY alembic ./alembic
COPY app ./app
RUN python -m compileall -q app alembic

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

USER app

EXPOSE 8000

# Um worker basta para um usuário só e cabe numa VM de 2 GB. Forma exec (lista):
# o processo recebe o SIGTERM do `docker compose down` e encerra limpo.
CMD ["fastapi", "run", "app/main.py", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
