# 01 — Injeção de dependências: `Depends` (FastAPI) × `g` (Flask)

## O problema

Toda rota que fala com o banco precisa de uma sessão aberta no começo da requisição e fechada no fim, mesmo se der erro. Daqui a pouco, as rotas também vão precisar do usuário logado.

## Como o Flask resolve

A rota **busca** o que precisa num objeto global da requisição:

```python
# Flask
def get_db():
    if "db" not in g:
        g.db = SessionLocal()
    return g.db

@app.teardown_appcontext
def fechar_db(exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()

@app.get("/contas")
def listar_contas():
    db = get_db()          # a rota vai buscar a sessão
    ...
```

Funciona, mas a dependência fica escondida: pela assinatura de `listar_contas()` não dá para saber que ela usa o banco. Para testar, é preciso preparar o contexto da app e trocar o que está em `g`.

## Como o FastAPI resolve

A rota **declara** o que precisa nos parâmetros, e o FastAPI entrega pronto:

```python
# app/core/db.py
def get_sessao() -> Iterator[Session]:
    with Session(get_engine()) as sessao:
        yield sessao       # antes do yield = abrir; depois = fechar (como o teardown)

# app/core/deps.py
SessaoDep = Annotated[Session, Depends(get_sessao)]

# app/main.py
@app.get("/saude")
def saude(sessao: SessaoDep) -> Saude:
    sessao.execute(text("SELECT 1"))
    ...
```

A cada requisição, o FastAPI vê `Depends(get_sessao)`, roda a função até o `yield`, passa a sessão para a rota e, quando a resposta termina, roda o resto (o `with` fecha a sessão). Uma função com `yield` faz, num lugar só, o papel do `get_db()` + `teardown_appcontext` do Flask.

`SessaoDep` é só um apelido (`Annotated`), para não repetir `Depends(get_sessao)` em toda rota.

## Por que isso importa

| | Flask (`g`) | FastAPI (`Depends`) |
|---|---|---|
| Quem pede | a rota busca | a rota declara no parâmetro |
| Visível na assinatura | não | sim (e aparece no OpenAPI quando é header/query) |
| Abrir/fechar | `get_db()` + `teardown_appcontext` | uma função com `yield` |
| Encadear | manual | uma dependência pode depender de outra (ex.: usuário logado depende da sessão) |
| Trocar no teste | mexer em `g` / contexto da app | `app.dependency_overrides[get_sessao] = ...` |

O último item é o que mais aparece neste projeto. Em `tests/conftest.py`, a fixture `client` troca a sessão real por uma sessão presa a uma transação que é revertida no fim do teste:

```python
app.dependency_overrides[get_sessao] = lambda: sessao
```

A rota não muda nada: continua pedindo uma `Session` e recebe a do teste.

## Para a entrevista

- **Injeção de dependências** = quem usa não cria; recebe pronto de fora. No FastAPI, o "de fora" é o próprio framework, guiado pelos parâmetros da rota.
- `Depends` com `yield` = setup/teardown por requisição, equivalente ao `g` + `teardown_appcontext` do Flask.
- `dependency_overrides` = trocar uma peça nos testes sem monkeypatch.
