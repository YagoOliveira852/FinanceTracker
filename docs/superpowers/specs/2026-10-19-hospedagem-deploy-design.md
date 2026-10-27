# Hospedagem, deploy e backup

**Status:** decidida em 2026-10-19; revista em 2026-10-23, com o servidor no ar e o primeiro deploy automático feito (provedor escolhido, OIDC no lugar do OAuth client, Tailscale SSH); detalhes do backup decididos em 2026-10-27 (seção "Backup em detalhe").

## Contexto

O app tem um único usuário e guarda histórico financeiro real. Dois requisitos exigem um servidor sempre ligado: o job diário da Pluggy e o uso real no celular, que começa antes do fim do desenvolvimento. O plano original previa Coolify com deploy só no fim do cronograma, o que deixava o uso real sem servidor e concentrava o risco de deploy nas últimas semanas.

## Decisão

### Servidor

- **Locaweb VPS de 1 GB, plano mensal:** Ubuntu 24.04, 2 vCPU, ~1 GB de RAM, 40 GB de disco, datacenter no Brasil, cobrança em reais (sem IOF) e sem fidelidade. A stack medida (api ~110 MiB, db ~60 MiB) deixa o servidor em ~500 MiB usados.
- **Acessível só pela Tailscale.** A API não tem endereço público. O celular entra na tailnet e acessa a API por HTTPS em `https://<maquina>.<tailnet>.ts.net`, com certificado emitido pela própria Tailscale (`tailscale serve --bg 8000`). Isso atende à exigência do Android de só usar HTTPS fora do debug.
- **Preparação feita à mão, uma vez** (passo a passo em `CLAUDE.md`, "Produção"):
  - usuário `deploy` (grupo `docker`); `root` e login por senha bloqueados no sshd;
  - `ufw` só aceita `22/tcp` na interface `tailscale0`: o IP público não aceita conexão nenhuma;
  - Tailscale com `--ssh` (o acesso por ssh é decidido pela política da tailnet, não por chave no servidor);
  - swap de 2 GB com `swappiness=10`: a RAM é pouca, e o swap evita o OOM killer num pico (pull de imagem, migration);
  - logs limitados (journald 100 MB; Docker 3×10 MB por container) para não encher o disco;
  - `.env` gerado **no próprio servidor** (`secrets.token_hex`/`token_urlsafe`), com permissão 600: os segredos de produção nunca passam pelo PC nem pelo GitHub.
- **Docker Compose puro, sem Coolify.** Serviços: `api` e `db` (Postgres 16); `jobs` (cron dos scripts) entra com os jobs. A api só escuta em `127.0.0.1:8000` (o Docker publica portas por fora do `ufw`) e o `db` não publica porta.
- **Postgres enxuto:** `shared_buffers=64MB` e `max_connections=20`. O padrão (128 MB, 100 conexões) é para servidor dedicado; a api com um worker usa no máximo 15 conexões (pool do SQLAlchemy).

### Deploy

GitHub Actions → Tailscale → ssh → Compose, em `.github/workflows/deploy.yml`:

1. O workflow `imagem` publica a imagem da api no GHCR a cada push na `main` (`sha-<7 caracteres>` e `latest`).
2. Quando ele termina com sucesso, o `deploy` roda no environment `producao`, que só aceita a `main`.
3. O runner entra na tailnet como **nó efêmero `tag:ci`** pela `tailscale/github-action`, autenticado por **OIDC (workload identity federation)**: o GitHub emite um token assinado para aquele job, e a Tailscale o troca por um acesso curto. A credencial na Tailscale só aceita o subject do environment `producao` deste repositório (formato imutável do GitHub, com os ids numéricos do dono e do repo). **Nenhum segredo de longa duração fica no GitHub:** os três secrets do environment (client id, audience, nome da VPS) não dão acesso sozinhos e só ficam em secrets para saírem mascarados no log público.
4. A chave de host da VPS vem da coordenação da Tailscale (`tailscale status --json`, como faz o `tailscale ssh`), e o ssh roda com `StrictHostKeyChecking yes`.
5. `scp` copia `deploy/compose.prod.yml` e `deploy/implantar.sh` (e, desde 2026-10-27, os scripts e units do backup) para `/opt/financas`; `ssh` (Tailscale SSH, usuário `deploy`) roda `implantar.sh sha-<7>`:
   - `docker compose pull` da tag **imutável** do commit (nunca `latest`), para o deploy ser reproduzível;
   - `alembic upgrade head` como passo explícito, **antes** de trocar a api: se a migration falhar, a versão anterior segue no ar;
   - `docker compose up -d --wait`, que só termina quando os healthchecks passam;
   - grava `TAG=sha-<7>` em `versao.env`. O `.env` não é tocado.
6. Teste de fumaça: `curl https://<maquina>.<tailnet>.ts.net/saude` a partir do runner.

**Política da tailnet** (no painel, fora do repositório): `tag:ci` só alcança `tag:server` nas portas 22 e 443 e só entra por ssh como `deploy`; os aparelhos do usuário alcançam tudo. A política tem `tests`/`sshTests`, e o painel recusa salvar uma regra que os quebre.

**Rollback:** `gh workflow run deploy -f tag=sha-<anterior>`, ou `bash implantar.sh sha-<anterior>` no servidor. As migrations precisam funcionar com o código da versão anterior (só acrescentar; remover em outro deploy).

### Jobs, backup e repositório

- **Jobs:** `sync_pluggy` roda 1×/dia às 07:00 (`America/Fortaleza`), com nova tentativa às 13:00 se a execução falhar. `atualizar_cdi` roda 1×/dia após o fechamento do BCB. O resultado do sync fica em `conexao_pluggy.ultimo_sync_em/ultimo_erro` e aparece como card de status na tela inicial; falhas também vão para o log do container.
- **Backup:** `pg_dump` diário, criptografado com restic antes de sair da VPS, enviado para um bucket Backblaze B2 (cobrança por uso, sem mínimo; limite diário de gasto configurado no B2). Retenção de 30 dias. **Uma restauração completa é testada e documentada antes de o app guardar dados reais.**
- **Repositório público desde o início**, com secret scanning e push protection do GitHub ativados e `.env`, extratos (`*.ofx`, `*.csv` fora de `tests/fixtures/`) e dumps no `.gitignore`. Nome da tailnet, IP e valores reais não entram no repositório: as docs usam `<maquina>.<tailnet>.ts.net`.
- **Modo demo só local:** banco separado populado por `uv run python -m app.seed` com dados fictícios. Os prints do README saem dele. Não existe instância demo pública.

### Backup em detalhe (2026-10-27)

Objetivo: perder no máximo um dia de lançamentos (RPO de 24 h) e conseguir reconstruir o banco **sem a VPS**, só com o que está fora dela (o bucket e a senha do repositório no gerenciador de senhas).

**O que roda, todo dia às 03:30 (`America/Fortaleza`):** `deploy/backup.sh`, no servidor:

1. `pg_dump --format=custom --compress=0` dentro do container `db`, para `/opt/financas/backup/financas.dump` (pasta 700). Se o `pg_dump` falhar, o script para ali, e nenhum snapshot parcial é criado (o motivo de gravar num arquivo em vez de usar um pipe para o `restic backup --stdin`).
2. `restic backup` do arquivo: o restic cifra no próprio servidor (AES-256, chave derivada da senha do repositório) e envia só os pedaços novos para o B2. O dump sai sem compressão de propósito: o restic deduplica entre os dias (o que não mudou não é reenviado) e comprime depois (formato v2, zstd); um dump já comprimido muda inteiro todo dia e anula a deduplicação.
3. `restic forget --keep-daily 30 --prune`: mantém um snapshot por dia nos 30 **últimos dias que têm backup** e apaga os dados que só os outros usavam. Se o backup parar de rodar, os antigos não somem.
4. `restic check`: confere a estrutura do repositório (índices e snapshots, sem baixar os dados).
5. O dump local é apagado ao sair, com ou sem erro: não fica cópia em claro fora do volume do banco.

**Como roda: systemd timer no servidor.** `deploy/systemd/financas-backup.service` (`Type=oneshot`, usuário `deploy`, prioridade baixa de CPU e disco) e `financas-backup.timer` (`OnCalendar=… America/Fortaleza`, `Persistent=true`: se a VPS estava desligada no horário, roda quando ligar). O resultado fica no journald (`journalctl -u financas-backup`) e o código de saída em `systemctl status`/`systemctl list-timers`. Os units são instalados à mão, uma vez (como o resto da preparação do servidor); o deploy só copia os arquivos para `/opt/financas`, então mudanças no `backup.sh` chegam sozinhas, e mudanças nos units pedem repetir a instalação.

**O restic roda num container, definido no `compose.prod.yml`:** serviço `restic` (imagem oficial `restic/restic`, versão fixa), no profile `backup`, então `up -d` não o sobe e não ocupa RAM fora do horário do backup; `docker compose run --rm restic <comando>` o usa. A versão fica no repositório, como a do Postgres, e nada é instalado no servidor além dos units. O serviço monta `./backup` só leitura e um volume de cache do restic (evita baixar os índices do B2 a cada execução) e tem `hostname` fixo, porque o restic grava o host em cada snapshot e o `forget` agrupa por ele.

**B2 pela API S3**, como recomenda a documentação do restic (o backend `b2:` nativo tem problemas no tratamento de erros). Bucket privado, só para isso, com a regra de ciclo de vida "Keep only the last version of the file": o B2 guarda versões antigas por padrão, e sem a regra o `prune` não liberaria espaço. Application key restrita ao bucket, com leitura, escrita e exclusão (o `prune` precisa apagar). O banco cabe com folga nos 10 GB gratuitos. **Sem cartão cadastrado** (decisão de 2026-10-27): o Caps & Alerts do B2 exige um meio de pagamento, e uma conta sem ele fica limitada ao plano gratuito, o que já garante custo zero; se um limite gratuito for atingido, o B2 recusa a operação, o backup falha e o alerta avisa. Se um dia houver cartão, o Caps & Alerts com limite diário baixo entra junto.

**Segredos em `/opt/financas/restic.env`** (permissão 600), separado do `.env`: a api recebe o `.env` inteiro (`env_file`), e quem invadisse a api não deve conseguir apagar os backups. Variáveis: `RESTIC_REPOSITORY` (`s3:https://<endpoint-s3-do-b2>/<bucket>`), `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` (id e chave da application key). Nomes em `deploy/restic.env.example`, sem valores. A senha do repositório é gerada no servidor e **copiada para o gerenciador de senhas** no mesmo momento: sem ela os backups são ilegíveis (não há recuperação), e ela não pode existir só na VPS que o backup protege. A application key pode ser recriada pelo painel do B2.

**Alerta: healthchecks.io** (plano gratuito), como "dead man's switch": o script avisa o início (`/start`) e o fim com o código de saída (`/<código>`) numa URL de ping. O healthchecks.io manda e-mail quando chega um código diferente de 0 **ou quando nenhum aviso chega** dentro do período (1 dia + 2 h de tolerância), o que cobre também a VPS desligada e o timer parado, casos em que nenhum script local conseguiria avisar. A URL fica em `BACKUP_PING_URL` no `restic.env` (quem a tem só consegue mandar avisos falsos); sem ela, o script roda igual e só não avisa. Uma falha do próprio aviso não derruba o backup.

**Restauração testada:** `deploy/testar-restauracao.sh` baixa o dump de um snapshot (`restic dump`), sobe um Postgres 16 temporário **sem rede**, restaura com `pg_restore --exit-on-error` e compara com a produção a lista de tabelas, a contagem de linhas de cada uma e o `alembic_version`. Roda logo depois de um backup (as contagens só batem se ninguém escreveu no meio). O passo a passo do desastre (VPS perdida: servidor novo, restaurar do B2, implantar) fica no runbook `docs/runbooks/backup-restauracao.md`.

**Fora por enquanto:** backup automático antes das migrations do deploy (deixaria o deploy dependente do B2); `restic check --read-data` periódico (baixa o repositório inteiro; a restauração testada cumpre esse papel quando é refeita).

## Alternativas consideradas

**Onde hospedar** (pesquisa de 21 a 23/10/2026):

- **Oracle Cloud Always Free (ARM):** era a primeira escolha por ser gratuita; a criação da VM falhou com "Out of host capacity" em São Paulo, e a região da conta não pode ser trocada. A imagem multi-arch (amd64 + arm64) ficou, e vale para uma migração futura.
- **PC pessoal, notebook velho ou Raspberry Pi + Tailscale:** custo mensal quase zero, mas o job e o app param quando a máquina desliga ou a energia cai; o Raspberry custa o equivalente a anos de VPS.
- **VPS estrangeiras (Vultr, DigitalOcean, Hetzner):** cobrança em dólar/euro com IOF, e as mais baratas não têm datacenter no Brasil.
- **Hostinger:** preço promocional só com pagamento adiantado de 24 meses.
- **Railway:** fechada a novos usuários no momento da escolha.
- **Vercel:** serverless com banco externo e API necessariamente pública; não atende "só na tailnet".
- **Heroku / Render:** caros para o que entregam (Render free dorme e apaga o Postgres em 30 dias; Heroku em modo de manutenção).
- **Fly.io:** tem São Paulo, mas sem plano gratuito, com Postgres próprio numa machine e IPv4 cobrado à parte.
- **Upuai:** barata e em reais, mas a empresa foi aberta em 08/2026, sem histórico nem avaliações independentes.
- **Locaweb 2 GB ou plano anual:** mais folga ou preço menor, mas com pagamento adiantado; o plano mensal de 1 GB permite trocar sem perda, e a medição mostrou que 1 GB com swap basta.

**Como fazer o deploy:**

- **Coolify:** painel e deploy por botão, mas o webhook do GitHub não alcança um servidor que só existe na tailnet, e o próprio Coolify consome boa parte da RAM de uma VPS pequena.
- **OAuth client da Tailscale nos secrets** (o plano original): funciona, mas é um segredo de longa duração no GitHub; o OIDC tira esse segredo do caminho.
- **Chave ssh nos secrets:** outro segredo de longa duração, e um `authorized_keys` para manter; o Tailscale SSH decide o acesso pela política da tailnet.
- **API pública com HTTPS:** permitiria uma demo online, ao custo de expor o banco com dados reais a ataques (rate limit, hardening, monitoramento).

**Backup:** Google Drive via rclone (o token OAuth do Drive expira e quebra o job) e Cloudflare R2 (exige cartão no cadastro). Para agendar (2026-10-27): **cron** (não roda o que perdeu com a VPS desligada e o log fica por conta do script); **serviço permanente no compose** com um agendador dentro (ocupa RAM o dia todo numa VPS de 1 GB para trabalhar um minuto); **restic instalado pelo apt** (o Ubuntu 24.04 traz uma versão antiga, e a versão deixaria de estar no repositório). Para enviar o dump: **pipe para `restic backup --stdin`** (um `pg_dump` que falha no meio ainda vira snapshot). Para o alerta: **só log e código de saída** (falha silenciosa até alguém olhar) e **ntfy.sh** (push no celular, mas não percebe o backup que não rodou). Para os segredos: **no `.env`** (a chave que apaga backups ficaria também no ambiente da api).

## Consequências

- O celular precisa estar conectado à Tailscale para usar o app.
- Quem visita o portfólio vê o projeto pelo README e pelo código, não por uma instância rodando.
- Cada peça do deploy é explicável isoladamente: Action → Tailscale (OIDC) → ssh → Compose.
- Todo push na `main` vai para produção alguns minutos depois; a proteção é o CI do PR e o `up --wait` com healthcheck.
- O cronograma ganha folga no fim, porque o deploy deixa de ser uma tarefa concentrada.
- Com 1 GB, sobra pouca RAM: o container `jobs` e o restic precisam caber no que resta (medir quando entrarem; o plano de 2 GB é a saída).
- A VPS é um ponto único de falha; o backup externo testado é o que torna isso aceitável. Acesso de emergência: o console web do provedor.
- O certificado `*.ts.net` aparece nos logs públicos de Certificate Transparency: o nome da máquina e da tailnet ficam conhecidos, o acesso não.
