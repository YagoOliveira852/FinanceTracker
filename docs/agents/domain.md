# Docs de domínio

Como os skills de engenharia devem consumir a documentação de domínio deste repositório ao explorar o código.

## Antes de explorar, leia

- **`docs/arquitetura.md`**: referência técnica — fontes de dados, Pluggy, stack, armadilhas do domínio, modelo de dados e estrutura de pastas.
- **`CONTEXT.md`** na raiz, se existir: glossário dos termos do domínio.
- **`docs/superpowers/specs/`**: leia as specs que tocam a área em que você vai trabalhar. Elas fazem o papel de ADRs neste projeto.

Se o `CONTEXT.md` ou alguma spec não existir, **siga em silêncio**. Não aponte a ausência nem sugira criá-los de antemão. O skill `/domain-modeling` (acessado via `/grill-with-docs` e `/improve-codebase-architecture`) cria esses arquivos quando um termo ou decisão é de fato resolvido.

## Estrutura de arquivos

Repositório single-context: `backend/` e `app/` são dois lados do mesmo domínio (`modulos/` e `features/` usam os mesmos nomes).

```
/
├── CONTEXT.md                                  ← glossário (criado quando necessário)
├── docs/
│   ├── arquitetura.md
│   └── superpowers/specs/
│       ├── 2026-10-20-usuario-unico-design.md
│       └── 2026-10-21-dinheiro-decimal-design.md
├── backend/
└── app/
```

**Decisões vão em `docs/superpowers/specs/YYYY-MM-DD-<tema>-design.md`** (contexto, decisão, alternativas, consequências), nunca em `docs/adr/`. Quando um skill disser "registrar um ADR", escreva uma spec nesse formato. Mudança que altere o que está em `docs/arquitetura.md` também atualiza esse arquivo.

## Use o vocabulário do glossário

Quando sua saída nomear um conceito do domínio (título de issue, proposta de refatoração, hipótese, nome de teste), use o termo como definido no `CONTEXT.md` e nos identificadores do domínio (`fatura`, `competencia`, `transacao`, `rascunho`, `aporte`). Não troque por sinônimos que o glossário evita.

Se o conceito que você precisa ainda não estiver no glossário, isso é um sinal: ou você está inventando linguagem que o projeto não usa (reconsidere), ou existe uma lacuna real (anote para o `/domain-modeling`).

## Sinalize conflitos com specs

Se sua saída contradisser uma spec existente, aponte explicitamente em vez de sobrescrever em silêncio:

> _Contradiz a spec 2026-10-21-dinheiro-decimal (dinheiro como Decimal), mas vale reabrir porque…_
