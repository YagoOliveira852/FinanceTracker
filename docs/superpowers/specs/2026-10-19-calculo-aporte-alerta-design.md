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
- `renda_prevista.conta_id` é a conta **onde o salário cai**, que pode não ser a conta do dia a dia. Quando o salário cai num banco e é transferido manualmente para outro, a receita é detectada no banco de origem, o saldo dele entra no saldo disponível e a transferência posterior vira par entre contas próprias (não conta como renda duas vezes). Se a conta de origem não tiver fonte de dados (por exemplo, conta-salário fora do Open Finance), `conta_id` aponta para a conta que recebe a transferência, e o crédito ali é tratado como a receita.

### Aporte

```
aporte = saldo disponível
       − faturas que vencem até o próximo salário
       − gastos previstos até o próximo salário
       − colchao
```

- **Saldo disponível:** soma das contas `corrente` **e** `carteira` ativas. Dinheiro físico entra porque é dinheiro guardado para depositar, não já gasto. Investimentos ficam de fora: são a reserva.
- **Faturas até o próximo salário:** toda fatura não paga com `data_vencimento` **até a data do próximo salário, inclusive**. Como o salário pode cair depois do vencimento, a fatura sai do salário atual. Valor usado: o **maior** entre `valor_informado` e o total calculado das transações da fatura, menos o que já foi pago (decisões do código, abaixo). Assim um lançamento faltando ou um rascunho não revisado nunca deixa a fatura subestimada.
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

### Decisões do design do planejamento (2026-10-29)

Telas aprovadas na página "Planejamento" do canvas (Mais → Planejamento, e o "Cadastrar salário" do Início). Valem para o card do `calculo.py` e o da tela inicial:

- **Sem valores iniciais:** a linha de `configuracao` só existe depois do primeiro "Salvar" em "Aporte e reserva". Enquanto não houver renda prevista ativa **e** configuração, o Início fica no estado "sem salário cadastrado" (só o saldo disponível) e o aporte não é calculado. Colchão e gasto semanal zerados por padrão inflariam o aporte.
- **Renda prevista não é excluída, só desativada** (`ativa = false`), como cartões e conexões. Inativa, ela sai do aporte, do alerta e do lembrete, e continua listada para ser reativada.
- **Dia 29 a 31 em mês mais curto** vira o último dia do mês; depois vale o ajuste para o dia útil seguinte. A tela mostra a próxima data já ajustada, e o motivo quando muda ("dia 15 é domingo e feriado").
- **Gasto semanal estimado é um piso:** o texto da tela diz que, com 4 semanas de histórico, vale o maior entre ele e a média real das últimas 8 semanas (regra de "Gastos previstos" acima), e mostra a média real atual.
- **Gasto mensal de referência:** "Automático" (`gasto_mensal_referencia` nulo) usa a média dos **3 últimos meses fechados**, sem o mês corrente, e a tela mostra o valor calculado; "Valor fixo" grava o valor.
- **Validação da renda:** descrição obrigatória, valor maior que zero, dia de 1 a 31 e conta obrigatória (corrente ou carteira ativa). A ajuda do campo de conta lembra que é a conta onde o crédito aparece primeiro.

### Decisões do código do cálculo (2026-10-30)

Aprovadas ao implementar `planejamento/calculo.py` (card "S6 · calculo.py"). As tabelas `configuracao` e `renda_prevista` ainda não existem: o módulo recebe dataclasses próprias e o service do card seguinte as monta.

- **O que o cálculo recebe pronto e o que ele decide.** O service passa o saldo de cada conta já com confirmadas e rascunhos, sem as possíveis duplicatas: a consulta agregada do saldo continua num lugar só. Também passa as faturas com os valores da tela da fatura (informado, calculado e pago) e as transações de todas as contas desde o 1º dia do terceiro mês antes da referência, com status e marca de duplicata. O filtro de status (confirmada e rascunho entram; ignorada e possível duplicata, não) e a definição de gasto ficam no cálculo. O service também conta os rascunhos do aviso "considera N rascunhos", pela mesma regra.
- **Gasto = despesa − estorno**, de qualquer conta, cartão incluído. Ajustes ficam fora: são correções pontuais de conferência, e um ajuste grande distorceria a média de 8 semanas. O ajuste da fatura continua pesando pelo valor da fatura.
- **Salário detectado:** uma `receita` na conta da renda, com valor entre 80% e 120% do previsto, de 3 dias antes a 5 dias depois da data esperada. Os 5 dias cobrem o atraso da Pluggy e um fim de semana. Um crédito vale para uma renda só: as datas esperadas pegam os créditos em ordem, da mais cedo para a mais tarde.
- **Próximo salário:** a data esperada mais próxima, entre as rendas ativas, que ainda não tem crédito e cuja janela não acabou. O salário adiantado já leva ao seguinte, então o aporte do dia 8 olha até o salário do mês que vem e não até o dia 10. O salário atrasado continua sendo o próximo até o fim da janela, com 0 dia de gasto previsto; depois disso, o cálculo passa para o seguinte e o alerta mostra o saldo sem ele.
- **Aporte = sobra − colchão**, nunca negativo, e só existe enquanto a janela do salário detectado está aberta. A sobra e o alerta são a mesma conta. Se o aporte foi registrado ou o usuário dispensou a sugestão, quem trata é a tela inicial.
- **Fatura:** reserva o que falta pagar, ou seja, `maior(informado, calculado) − pago`, sem ficar negativo. O pagamento parcial ou adiantado já saiu do saldo disponível. A fatura vencida e não paga também entra.
- **Histórico:** `inicio_historico` é o primeiro dia com dados de gasto (o service usa o gasto mais antigo). As "4 semanas" contam como 28 dias desde esse início. A média usa os 56 dias antes de hoje, sem contar hoje, que ainda não terminou. Com histórico menor que isso, divide pelos dias que existem.
- **Gastos previstos** = o maior entre o piso e a média, vezes os dias até o salário (hoje entra, o dia do salário não). O total é arredondado para cima ao centavo. A média semanal real mostrada no Planejamento é arredondada ao centavo.
- **Gasto mensal automático:** a média dos 3 meses fechados que estão **inteiros** dentro do histórico (um mês pela metade puxaria a média para baixo). Com menos meses, usa os que houver. Sem nenhum, não há gasto mensal nem meses de reserva. O automático é calculado mesmo sem configuração, para a tela que ainda não foi salva.
- **Meses de reserva:** uma casa decimal, arredondada para baixo. Quando há aporte, o cálculo também devolve os meses depois dele. Sem investimentos (antes da S8), a reserva é 0.

### Decisões do código das rendas e da configuração (2026-10-30)

Tomadas ao implementar o cadastro (card "S6 · Planejamento: rendas e configuração"), para aprovação no PR:

- **API** em `/planejamento`, tag `planejamento`: `GET`/`POST /rendas`, `PUT /rendas/{id}`, `GET /rendas/previa?dia_previsto=` (a "Próxima data" ao vivo do formulário, como a prévia do cartão) e `GET`/`PUT /configuracao`. Desativar e reativar vão no `PUT` da renda, pelo campo `ativa`, como no cartão; não há `DELETE`.
- **Configuração ainda não salva:** o `GET` devolve `200` com `configuracao: null`, não `404`. O gasto mensal automático e a média semanal real vêm mesmo assim, e o automático vem também com valor fixo salvo, para a tela mostrar os dois ao trocar de modo. Os meses de reserva usam o gasto mensal que vale (o fixo ou o automático).
- **Reuso do cálculo:** a leitura chama `calculo.calcular` sem rendas e sem saldos, com as transações desde o 1º dia do terceiro mês antes de hoje. O início do histórico é o gasto (despesa ou estorno) mais antigo, confirmado ou rascunho, sem marca de duplicata. O service expõe essas consultas para o endpoint de resumo do card seguinte.
- **Próxima data da renda:** a primeira data efetiva a partir de hoje (inclusive), entre a do mês anterior (que pode ter sido empurrada para este), a deste mês e a do seguinte. Ela não olha se o crédito já chegou: isso é do cálculo e do Início. A API devolve a data efetiva, a prevista e os feriados entre elas; o app monta o motivo ("dia 15 é domingo e feriado", "novembro tem 30 dias").
- **Ordem da lista:** ativas pela próxima data, depois as inativas.
- **Conta desativada** só impede a renda ativa: a renda pode ser desativada mesmo depois que a conta saiu de uso, e só volta a ser ativa com uma corrente ou carteira ativa.
- **Validação da configuração:** colchão e gasto semanal a partir de zero (gasto semanal zero deixa só a média real), meta maior que zero com uma casa (até 999,9 meses, string no JSON como o dinheiro) e valor fixo maior que zero.
- **Primeira vez:** os dois passos aparecem enquanto faltar renda ou configuração. O passo feito ganha um ✓ e perde o botão, e a seção "Aporte e reserva" só aparece depois do primeiro salvamento.

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
