# 02 — Autenticação com access + refresh token (× sessão com cookie)

## O problema

O app Android precisa provar, a cada requisição, que quem chama é o usuário. Pedir a senha toda vez não dá; guardar a senha no celular, menos ainda.

## Como costuma ser num app Flask

Flask-Login + cookie de sessão: o login grava o id do usuário num cookie assinado, o navegador manda o cookie sozinho em toda requisição, e `@login_required` + `current_user` leem esse cookie. Como o navegador envia o cookie até em requisições disparadas por outro site, é preciso proteção contra **CSRF**.

## Como é aqui

O cliente é um app nativo, não um navegador: nada é enviado sozinho. O app guarda dois tokens e manda um deles explicitamente no cabeçalho `Authorization: Bearer ...`. Sem cookie, não existe CSRF.

| | access token | refresh token |
|---|---|---|
| O que é | JWT assinado (`sub`, `tipo`, `iat`, `exp`) | 32 bytes aleatórios, sem significado |
| Validade | 15 min | 30 dias |
| Onde vai | toda requisição (`Authorization`) | só em `POST /auth/refresh` |
| O banco guarda | nada: a API confere a assinatura com o `JWT_SECRET` | só o SHA-256 (`refresh_token.token_hash`) |
| Se vazar | vale no máximo 15 min | rotação + detecção de reuso (abaixo) |

**Por que dois tokens:** o access não passa pelo banco (rápido), mas não dá para revogar um JWT antes do `exp`; por isso ele dura pouco. O refresh dura muito, mas passa pelo banco a cada uso e pode ser revogado.

**Por que SHA-256 no refresh e argon2 na senha:** senha é escolhida por gente e pode ser adivinhada; argon2 é lento de propósito para encarecer a força bruta. O refresh token tem 256 bits aleatórios: não há o que adivinhar, e um hash determinístico deixa buscar o token pelo índice único.

## Rotação e detecção de reuso

1. `POST /auth/refresh` com o token T1 → a API grava `revogado_em` em T1 e devolve T2.
2. O app passa a usar T2. Ninguém legítimo apresenta T1 de novo.
3. Se T1 aparecer outra vez, alguém copiou o token. A API não sabe quem é o ladrão e quem é o dono, então **revoga todos** os refresh tokens do usuário: os dois lados precisam fazer login de novo, e só o dono sabe a senha.

O `SELECT ... FOR UPDATE` na busca do token faz duas renovações simultâneas com o mesmo token virarem "uma rotação + um reuso". Por isso o app precisa fazer um refresh por vez.

## No código

- `core/seguranca.py`: argon2, JWT e geração/hash do refresh. Funções puras, testadas em `tests/unit/test_seguranca.py`.
- `modulos/auth/service.py`: `login`, `renovar` (rotação e reuso), `criar_usuario`. Levanta exceções próprias; não conhece HTTP.
- `modulos/auth/router.py`: traduz as exceções em 401 com `detail` em pt-BR.
- `core/deps.py`: `UsuarioDep` lê o `Authorization`, valida o access token e entrega o `Usuario` para a rota. É o `@login_required` + `current_user` do Flask-Login feito com `Depends` (ver nota 01).

## Para a entrevista

- Bearer em vez de cookie → sem CSRF, porque nada é enviado automaticamente.
- Access curto e sem estado (JWT) + refresh longo e com estado (banco) = desempenho sem perder a revogação.
- Rotação com detecção de reuso: um token roubado vale no máximo até o dono usar o dele.
- Login com e-mail inexistente roda o argon2 mesmo assim, contra um hash fictício: o tempo de resposta não revela quais e-mails existem.
