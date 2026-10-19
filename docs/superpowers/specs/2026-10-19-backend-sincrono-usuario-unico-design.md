# Backend síncrono e usuário único

**Status:** decidida em 2026-10-19.

## Contexto

O app tem um único usuário e não precisa de concorrência alta. O FastAPI aceita rotas síncronas (`def`, executadas num pool de threads) e assíncronas (`async def`). O plano não definia qual estilo usar, e não havia forma prevista de criar o usuário, já que não existe tela de cadastro.

## Decisão

### Síncrono

- Rotas com `def`, `Session` síncrona do SQLAlchemy 2.0 com psycopg 3, dependências síncronas em `core/deps.py`.
- Testes de integração com `fastapi.testclient.TestClient` contra Postgres real (testcontainers), cada teste dentro de uma transação revertida.
- Clientes HTTP externos (Pluggy, BCB) com `httpx.Client` síncrono; nos testes, mockados com respx.

### Usuário único

- Tabela `usuario` existe só para autenticação; as tabelas de domínio **não** têm `usuario_id`. Tornar multiusuário depois = adicionar a coluna e filtrar.
- **Sem endpoint de cadastro.** O usuário é criado por comando de terminal: `uv run python -m app.criar_usuario`, que pede e-mail e senha de forma interativa e reusa o service de auth (hash argon2). O seed do modo demo usa o mesmo service com um usuário fictício.

## Alternativas consideradas

- **Async (`async def`, `AsyncSession`, `httpx.AsyncClient`):** mais moderno, mas acrescenta conceitos novos (event loop, `await` no ORM, lazy loading proibido) sem ganho para um usuário só.
- **Usuário via variáveis de ambiente na primeira inicialização:** deixa senha em `.env`.
- **Endpoint de cadastro que se desativa após o primeiro usuário:** abre uma superfície de ataque por um uso único.

## Consequências

- O modelo mental é o do Flask + SQLAlchemy síncrono; um conceito novo por vez.
- Migrar para async depois é possível, mas tocaria todos os services e testes.
- O `CLAUDE.md` passa a citar `TestClient` em vez de `httpx.AsyncClient`.
