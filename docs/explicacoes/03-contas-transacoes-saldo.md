# 03 — Contas, transações e saldo: o caminho de uma requisição

## O caminho dos dados

```
POST /transacoes  →  router.lancar        (valida o JSON com TransacaoEntrada)
                  →  service.lancar       (conta existe? está ativa? grava confirmada)
                  →  banco                (CHECK valor > 0, tipo/status/fonte válidos)
GET /contas       →  router.listar  →  service.listar_contas  →  1 SELECT com o saldo de todas
```

O router só traduz HTTP (JSON ↔ schema, exceção ↔ status). A regra fica no service, que não sabe o que é HTTP: dá para chamá-lo de um job ou de um teste sem subir a API.

## Proteger um router inteiro

No Flask, um `before_request` no blueprint barra tudo que não tem login. No FastAPI, o equivalente é a dependência no próprio `APIRouter`:

```python
router = APIRouter(prefix="/contas", dependencies=[Depends(get_usuario_atual)])
```

Toda rota desse router passa por `get_usuario_atual` antes de rodar; sem token válido, 401. Quando a rota precisa do usuário em si, ela declara `usuario: UsuarioDep` no parâmetro, como em `/auth/eu`.

## Erro de regra apontando o campo

O Pydantic recusa o que dá para validar olhando só o JSON, como valor com 3 casas ou texto vazio. Outras regras dependem do banco ou do dia, por exemplo "conta não encontrada" ou "data do saldo no futuro". O service levanta `CampoInvalido("conta_id", "Conta não encontrada.")`, e um tratador em `core/erros.py` devolve o mesmo 422 da validação, com `campos`. O app mostra a mensagem embaixo do campo certo, venha o erro de onde vier. No Marshmallow, isso seria um `ValidationError({"conta_id": [...]})` levantado por um `@validates_schema` que consulta o banco.

## Saldo calculado, não guardado

`saldo_atual` não é coluna: é `saldo_inicial` mais as transações confirmadas a partir de `data_saldo_inicial` (inclusive). Guardar o saldo exigiria atualizá-lo em toda criação, edição, exclusão e confirmação de transação. Um caminho esquecido e ele fica errado para sempre. Calculado, ele está sempre certo.

O custo é a consulta, e é aí que mora o **N+1**. O jeito ingênuo é listar as contas e, para cada uma, rodar um `SUM`, o que dá 1 + N consultas. Aqui uma subconsulta agrupa as transações por conta e o SELECT principal faz um `LEFT JOIN` nela. Pelo mesmo motivo, `relationship(lazy="joined")` traz a instituição no mesmo SELECT, e não numa consulta por conta (o padrão `lazy="select"` do SQLAlchemy, que você já conhece).

## "Hoje" como dependência

A VPS roda em UTC, e às 22h de Fortaleza já é amanhã por lá. Por isso a data de hoje vem de `HojeDep`, calculada no fuso `TZ_NEGOCIO`. Ser uma dependência tem um bônus: o teste fixa o dia com `app.dependency_overrides[get_hoje] = lambda: date(2026, 10, 20)`, sem biblioteca para congelar o relógio. No Flask, o caminho seria um `mock.patch` no `date.today`.
