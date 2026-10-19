# Cálculo de aporte, meses de reserva e alerta de ritmo

**Status:** decidida em 2026-10-19.

## Contexto

É a regra mais importante do app: responder "quanto posso aportar no próximo salário e se o ritmo de gastos ameaça a reserva". Parte dos lançamentos chega como rascunho com até ~24h de atraso (Pluggy) e só é confirmada na tela de revisão, então um cálculo que ignore rascunhos superestima o que sobra.

Tudo abaixo vive em `backend/app/modulos/planejamento/calculo.py` como **funções puras** (sem banco, sem I/O, sem relógio: a data de referência é parâmetro), com cobertura de teste completa. Os valores (colchão, gasto semanal estimado, rendas previstas) são dados de `configuracao` e `renda_prevista`, nunca constantes.

## Decisão

### Datas de salário

- A **data esperada** de cada `renda_prevista` é o `dia_previsto` do mês ajustado para o **dia útil seguinte** quando cai em fim de semana ou feriado (tabela `feriado`).
- O **dia de aporte** é disparado pela **receita detectada**: uma transação `receita` na conta da renda prevista, com valor próximo do previsto, a partir de alguns dias antes da data esperada. O app sugere "salário chegou, aporte de R$ X". A data esperada serve para a projeção do alerta e para o lembrete local.
- **Próximo salário** = a próxima data esperada após a data de referência.

### Aporte

```
aporte = saldo disponível
       − faturas que vencem até o próximo salário
       − gastos previstos até o próximo salário
       − colchao
```

- **Saldo disponível:** soma das contas `corrente` **e** `carteira` ativas. Dinheiro físico entra porque é dinheiro guardado para depositar, não já gasto. Investimentos ficam de fora: são a reserva.
- **Faturas até o próximo salário:** toda fatura não paga com `data_vencimento` **até a data do próximo salário, inclusive**. Como o salário pode cair depois do vencimento, a fatura sai do salário atual. Valor usado: o **maior** entre `valor_informado` e o total calculado das transações da fatura. Assim um lançamento faltando ou um rascunho não revisado nunca deixa a fatura subestimada.
- **Gastos previstos até o próximo salário:** taxa diária × dias até o próximo salário, onde:
  - com menos de 4 semanas de histórico de gasto, taxa = `gasto_semanal_estimado / 7`;
  - a partir de 4 semanas, taxa = o **maior** entre `gasto_semanal_estimado / 7` e a média diária real das últimas 8 semanas.
  - "Gasto" exclui `pagamento_fatura`, transferências entre contas próprias (`transferencia_par_id`), `aporte` e `resgate`.
- Aporte negativo é mostrado como 0 a aportar, e o alerta (abaixo) assume.

### Rascunhos

- **Saldo oficial** (tela de contas) usa só transações `confirmada`.
- **Aporte e alerta** usam `confirmada` **+ `rascunho`**, e a tela mostra "considera N rascunhos não revisados", com atalho para a revisão.
- Rascunhos com `possivel_duplicata_de` preenchido ficam **fora** do cálculo, para não contar o mesmo gasto duas vezes.
- `ignorada` nunca entra.

### Meses de reserva

`meses = saldo dos investimentos com conta_reserva / gasto mensal de referência`, onde o gasto mensal de referência é `configuracao.gasto_mensal_referencia` ou, quando nulo, a média dos últimos 3 meses de gasto (mesma definição de "gasto" acima). A meta é `configuracao.meta_reserva_meses`.

### Alerta de ritmo

Projeção da sobra até o próximo salário, recalculada a cada leitura:

```
sobra = saldo disponível − faturas até o próximo salário − gastos previstos restantes
```

| Nível | Condição | Significado |
|---|---|---|
| 🟢 verde | `sobra ≥ colchao` | ritmo sob controle |
| 🟡 amarelo | `0 ≤ sobra < colchao` | vai consumir o colchão |
| 🔴 vermelho | `sobra < 0` | exigiria resgatar a reserva |

O alerta aparece na **tela inicial** e é visto também pelo **lembrete local** dos dias de salário, que abre o app. Não há notificação push.

### Exemplo (valores fictícios)

Saldo disponível R$ 2.000,00; fatura que vence antes do próximo salário R$ 700,00; 10 dias até o próximo salário com taxa de R$ 20,00/dia (R$ 200,00); colchão R$ 250,00 → aporte = 2.000 − 700 − 200 − 250 = **R$ 850,00**; sobra = 1.100 ≥ 250 → 🟢.

## Alternativas consideradas

- **Ignorar rascunhos até a confirmação:** com o atraso da Pluggy, o aporte do dia de salário estaria quase sempre inflado.
- **Bloquear o aporte enquanto houver rascunho:** seguro, mas trava o uso sempre que a revisão atrasar.
- **Só a média real ou só o parâmetro fixo para gastos previstos:** a média sozinha deixa uma semana atípica inflar o aporte; o fixo sozinho ignora o histórico.
- **Vencimento no dia do salário contando para o próximo salário:** errado quando o salário cai depois da fatura.
- **Notificação push do alerta:** exigiria Firebase (FCM), fora do escopo.

## Consequências

- Todas as regras são testáveis com tabelas de casos (datas, feriados, rascunhos, duplicatas, histórico curto e longo) sem banco.
- O cálculo erra para o lado conservador: na dúvida, aporta menos.
- A detecção de receita depende de a transação chegar; com a Pluggy, o aporte pode ser sugerido um dia depois do crédito real.
