# Hospedagem, deploy e backup

**Status:** decidida em 2026-10-19.

## Contexto

O app tem um único usuário e guarda histórico financeiro real. Dois requisitos exigem um servidor sempre ligado: o job diário da Pluggy e o uso real no celular, que começa antes do fim do desenvolvimento. O plano original previa Coolify com deploy só no fim do cronograma, o que deixava o uso real sem servidor e concentrava o risco de deploy nas últimas semanas.

## Decisão

- **VPS própria, acessível só pela Tailscale.** A API não tem endereço público. O celular entra na tailnet e acessa a API por HTTPS em `https://<maquina>.<tailnet>.ts.net`, com certificado emitido pela própria Tailscale (`tailscale serve`). Isso atende à exigência do Android de só usar HTTPS fora do debug.
- **Docker Compose puro na VPS, sem Coolify.** Serviços: `api`, `db` (Postgres 16) e `jobs` (cron dos scripts).
- **Deploy por GitHub Actions:** o workflow entra na tailnet como nó efêmero (OAuth client da Tailscale nos secrets do repositório), faz `ssh` na VPS e roda `docker compose pull && docker compose up -d`. A imagem da API é publicada no GitHub Container Registry.
- **Deploy mínimo cedo:** a VPS é contratada e recebe o primeiro deploy junto com a fatia vertical, não no fim.
- **Jobs:** `sync_pluggy` roda 1×/dia às 07:00 (`America/Fortaleza`), com nova tentativa às 13:00 se a execução falhar. `atualizar_cdi` roda 1×/dia após o fechamento do BCB. O resultado do sync fica em `conexao_pluggy.ultimo_sync_em/ultimo_erro` e aparece como card de status na tela inicial; falhas também vão para o log do container.
- **Backup:** `pg_dump` diário, criptografado com restic antes de sair da VPS, enviado para um bucket Backblaze B2 (cobrança por uso, sem mínimo; limite diário de gasto configurado no B2). Retenção de 30 dias. **Uma restauração completa é testada e documentada antes de o app guardar dados reais.**
- **Repositório público desde o início**, com secret scanning e push protection do GitHub ativados e `.env`, extratos (`*.ofx`, `*.csv` fora de `tests/fixtures/`) e dumps no `.gitignore`.
- **Modo demo só local:** banco separado populado por `uv run python -m app.seed` com dados fictícios. Os prints do README saem dele. Não existe instância demo pública.

## Alternativas consideradas

- **PC pessoal como servidor + Tailscale:** custo zero, mas o job e o app param quando o PC desliga.
- **Oracle Cloud Always Free:** gratuito, porém com aprovação de conta instável e risco de recolhimento da instância ociosa.
- **Coolify:** painel e deploy por botão, mas o webhook do GitHub não alcança um servidor que só existe na tailnet, e o próprio Coolify consome boa parte da RAM de uma VPS pequena.
- **API pública com HTTPS:** permitiria uma demo online, ao custo de expor o banco com dados reais a ataques (rate limit, hardening, monitoramento).
- **Google Drive via rclone / Cloudflare R2 para backup:** o token OAuth do Drive expira e quebra o job; o R2 exige cartão no cadastro.

## Consequências

- O celular precisa estar conectado à Tailscale para usar o app.
- Quem visita o portfólio vê o projeto pelo README e pelo código, não por uma instância rodando.
- Cada peça do deploy é explicável isoladamente: Action → Tailscale → ssh → Compose.
- O cronograma ganha folga no fim, porque o deploy deixa de ser uma tarefa concentrada.
- A VPS é um ponto único de falha; o backup externo testado é o que torna isso aceitável.
