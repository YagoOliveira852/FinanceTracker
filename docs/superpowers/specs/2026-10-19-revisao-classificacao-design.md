# Revisão: classificação, transferências, feriados e amostras de importação

**Status:** decidida em 2026-10-19.

## Contexto

A tela de revisão é o coração do app: tudo que não é lançamento manual entra como rascunho e é confirmado ali. Para o uso não depender de disciplina, o app precisa sugerir bem (categoria, pares de transferência) e deixar a decisão final com o usuário.

## Decisão

### Regras de classificação aprendidas

- **Padrão = descrição original normalizada**, por uma função pura e testável: minúsculas, sem acentos, sem números, datas e códigos, sem termos genéricos do banco ("pix enviado", "compra", "pagamento", ...). Ex.: `PIX ENVIADO 12/11 PADARIA SAO JOSE LTDA 0349` → `padaria sao jose ltda`.
- A regra é **aprendida na 1ª confirmação** de categoria (`origem = aprendida`). O app só sugere; a revisão confirma.
- **Correção sobrescreve:** se uma regra sugerir errado e o usuário corrigir, a categoria da regra é trocada e `vezes_aplicada` volta a zero.
- Regras manuais e aprendidas convivem; vence a de maior `prioridade`.

### Categorias iniciais

Seed versionado com uma lista genérica, sem nada pessoal: Alimentação, Mercado, Transporte, Moradia, Saúde, Lazer, Assinaturas, Compras, Educação (`essencial`/`variavel`), Salário, Outras receitas (`renda`) e Investimento (`investimento`). O usuário renomeia ou cria outras pelo app.

### Transferências entre contas próprias

- **Sugestão automática de par:** mesmo valor, sentidos opostos, contas próprias diferentes, datas até ±2 dias. O par aparece na revisão e só é ligado (`transferencia_par_id`) com confirmação.
- Depósito de dinheiro físico (`carteira` → `corrente`) também é transferência.
- Nunca fundir automaticamente; mesmo princípio da deduplicação entre fontes.

### Feriados

- A tabela `feriado` recebe **só feriados nacionais**, gerados pela biblioteca `holidays` num seed para os anos em uso. Vencimento de cartão de banco digital segue o calendário bancário nacional; feriado municipal não move a data.
- `fatura.data_vencimento` continua editável para casos que fujam da regra.

### Amostras para os importadores

- Extratos reais ficam numa pasta **fora do repositório** e nunca são lidos diretamente nem versionados.
- Um script local imprime só a estrutura (encoding, separador, cabeçalhos, formato de data e valor, linhas com letras e números mascarados). As fixtures em `backend/tests/fixtures/` são escritas à mão com dados inventados no mesmo formato.
- Se nenhum banco exportar a **fatura do cartão** em CSV/OFX, lançamentos de cartão chegam só pela Pluggy e por lançamento manual; leitura de PDF está fora do escopo.

## Alternativas consideradas

- **Padrão = descrição inteira:** nunca casa de novo por causa de datas e códigos.
- **Aprender só após 2 confirmações iguais:** menos sugestões erradas, mais trabalho manual no começo do uso.
- **Pares de transferência ligados manualmente:** mais trabalhoso e fácil de esquecer, o que dobra gasto e renda.
- **Feriados de Ceará e Fortaleza:** não afetam o vencimento de bancos digitais.
- **Lista de feriados à mão:** sem dependência nova, mas precisa ser mantida todo ano.

## Consequências

- Normalização e pareamento são funções puras com testes de tabela.
- `holidays` é dependência nova do backend.
- O cartão depende mais da Pluggy se não houver exportação estruturada da fatura; o spike da Pluggy confirma.
