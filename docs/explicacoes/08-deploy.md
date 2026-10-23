# 08 — Deploy: Actions → Tailscale (OIDC) → ssh → Compose

## O problema

A API roda numa VPS que **não tem porta aberta para a internet**: só a tailnet (a rede privada da Tailscale) alcança o servidor. Isso protege o banco com dados financeiros reais, mas cria um problema para o deploy: o runner do GitHub Actions é uma máquina qualquer da internet, e o servidor não aceita conexão dela.

Num deploy "comum" (Heroku, Render, uma VPS com ssh aberto), o GitHub guarda uma senha ou chave ssh nos secrets e entra direto. Aqui, além de o servidor estar fechado, a ideia é **não deixar segredo de longa duração no GitHub**: uma chave vazada daria acesso à produção até alguém notar.

## O caminho de um commit até a produção

```
merge na main
  └─ imagem.yml ──► GHCR: financetracker-api:sha-1a2b3c4
       └─ (terminou com sucesso) deploy.yml, environment "producao"
            1. pede ao GitHub um token OIDC deste job
            2. troca o token por um acesso curto na Tailscale → entra na tailnet como nó efêmero tag:ci
            3. busca a chave de host da VPS na própria tailnet
            4. scp compose.prod.yml + implantar.sh → /opt/financas
            5. ssh deploy@<maquina> bash implantar.sh sha-1a2b3c4
                 pull → alembic upgrade head → up -d --wait → grava versao.env
            6. curl https://<maquina>.<tailnet>.ts.net/saude == {"status":"ok"}
       └─ fim do job: o nó efêmero sai da tailnet sozinho
```

## As peças

**OIDC (workload identity federation).** O GitHub emite, para cada job que pede `id-token: write`, um JWT assinado com afirmações sobre quem está rodando: repositório, branch, environment. A Tailscale confere a assinatura com as chaves públicas do GitHub e compara o `sub` do token com o subject cadastrado na credencial (`repo:<dono>@<id>/<repo>@<id>:environment:producao`). Se bater, devolve um acesso que vale minutos. É a mesma ideia do "Entrar com Google" de um site, só que entre máquinas: ninguém guarda senha, a confiança vem de quem emitiu o token. Os ids numéricos no subject impedem que alguém que registre um nome de conta ou repositório igual (depois de uma renomeação) reaproveite a confiança.

**Environment `producao`.** Só a `main` pode usar o environment, e a credencial da Tailscale só aceita tokens dele. Um workflow num PR, mesmo que alguém o altere, não consegue entrar na tailnet.

**Nó efêmero com tag.** O runner entra como `tag:ci`, sem dono humano, e é removido da tailnet quando o job termina. A política da tailnet (ACL) diz o que essa tag pode: alcançar `tag:server` nas portas 22 e 443 e entrar por ssh **só** como `deploy`. A política tem testes: o painel recusa salvar uma mudança que os quebre.

**Tailscale SSH.** Com `tailscale up --ssh`, quem atende o ssh vindo da tailnet é o `tailscaled`, que decide pela política da tailnet, não por `authorized_keys`. Não existe chave ssh do deploy para guardar nem rotacionar. A chave de host da VPS vem da coordenação da Tailscale (`tailscale status --json`), e o ssh roda com `StrictHostKeyChecking yes`: se outra máquina responder no lugar da VPS, a conexão é recusada.

**`implantar.sh`.** Roda no servidor, e é o mesmo comando para o deploy automático e para um rollback à mão:

| Passo | Por quê |
|---|---|
| Só aceita `sha-<7>` | `latest` muda a cada push; com a tag do commit, o deploy de hoje e um repetido amanhã sobem a mesma imagem. |
| `pull` antes de tudo | Se a imagem não existir, nada mudou no servidor. |
| `alembic upgrade head` separado e **antes** de trocar a api | Se a migration falhar, a versão anterior continua no ar. O preço: toda migration precisa funcionar com o código anterior (acrescentar coluna sim; remover só num deploy seguinte). |
| `up -d --wait` | Só termina quando o healthcheck da api (`/saude`) passa; senão o job fica vermelho. |
| `versao.env` | Guarda a versão que subiu. O `.env` (segredos, gerado no servidor) nunca é tocado pelo deploy. |

## Comparando com o que você já conhece

| Aqui | Equivalente comum |
|---|---|
| Tailscale + `ufw` só na `tailscale0` | VPN corporativa: o servidor só existe para quem está nela. |
| OIDC entre GitHub e Tailscale | "Entrar com Google", só que para máquinas; substitui o `HEROKU_API_KEY` nos secrets. |
| `implantar.sh` | O `release` do Procfile do Heroku (migrations) + o restart dos dynos. |
| `up -d --wait` + healthcheck | O health check do load balancer que só manda tráfego quando o app responde. |
| `gh workflow run deploy -f tag=sha-…` | `heroku rollback v41`. |

## Perguntas de entrevista

- **"Por que não deixar a API pública?"** Usuário único com dados financeiros reais: não expor nada é mais simples e mais seguro que hardening, rate limit e monitoramento de uma API aberta.
- **"Onde estão os segredos?"** O `.env` de produção foi gerado no próprio servidor e só existe lá (permissão 600). O GitHub não tem nenhum segredo que dê acesso: client id, audience e nome da máquina só servem com um token OIDC válido do environment `producao`.
- **"E se o deploy quebrar a produção?"** O `up --wait` deixa o job vermelho; volta-se com `gh workflow run deploy -f tag=sha-<anterior>`. Migration que falha não chega a trocar a api.
- **"Por que Compose e não Kubernetes?"** Uma VPS de 1 GB, dois containers, um usuário: Compose é o suficiente e cabe na RAM.
