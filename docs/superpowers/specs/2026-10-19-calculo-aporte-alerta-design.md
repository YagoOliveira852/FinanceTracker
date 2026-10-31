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

### Decisões do lembrete nos dias de salário (2026-10-30)

Aprovadas antes de implementar o card "S6 · Lembrete local nos dias de salário". Tudo fica no app (`flutter_local_notifications` + `timezone`), sem endpoint novo:

- **Data:** a data efetiva que `GET /planejamento/rendas` já devolve (`proxima.data`), só das rendas **ativas**. Agenda-se só a próxima de cada renda: o app reagenda a cada abertura com sessão, a cada carga da tela Planejamento (que recarrega depois de criar, editar, desativar ou reativar uma renda) e quando o toque no lembrete abre o app. Sem abrir o app entre um salário e o seguinte, o seguinte não é agendado; aceito, porque o uso é diário e mudar a API para devolver N datas não compensa.
- **Horário:** 09:00 em `America/Fortaleza` (o fuso de negócio, não o do aparelho), depois do sync da Pluggy das 07:00. Data cujo horário já passou não é agendada: no dia do salário depois das 09:00, o lembrete do mês seguinte entra na abertura do dia seguinte.
- **Uma notificação por data:** rendas no mesmo dia viram um lembrete só. Título "Dia de salário"; corpo com as descrições das rendas e "veja quanto aportar e o ritmo dos gastos". Sem valores: a notificação aparece na tela bloqueada, e o aporte e o alerta são do Início.
- **Salário adiantado:** o lembrete aparece mesmo assim. A API não sabe se o crédito chegou; o texto não afirma que o salário caiu, e o Início mostra o estado real.
- **Toque:** abre o app no Início (com o app fechado, é a rota inicial; aberto em outra tela, vai para o Início).
- **Alarme inexato** (`inexactAllowWhileIdle`): pode atrasar alguns minutos, mas dispensa `SCHEDULE_EXACT_ALARM`, que o usuário teria de conceder nas configurações.
- **Reiniciar o aparelho:** o plugin guarda os agendamentos e os refaz no boot (`RECEIVE_BOOT_COMPLETED` e os receivers dele no `AndroidManifest.xml`).
- **Permissão de notificação (Android 13+):** pedida só quando há pelo menos uma renda ativa, para não aparecer logo depois do login sem motivo. Recusada, os lembretes continuam agendados e simplesmente não aparecem; o Android para de perguntar depois de duas recusas.
- **Sessão:** "Sair" cancela todos os lembretes. Sessão expirada os mantém: o toque leva ao login e, depois dele, ao Início.
- **Onde fica:** `LembretesSalario` (serviço sem estado de tela, na feature `planejamento`) decide o que agendar; o plugin fica atrás da interface `Notificador` (`core/notificacoes/`), trocada por um falso nos testes.

### Decisões do código da tela inicial (2026-10-31)

Tomadas ao implementar o card "S6 · Tela inicial" sobre a página "Início" do canvas (no ritmo, atenção, risco, salário chegou e sem salário cadastrado, claro e escuro):

- **Uma rota só:** `GET /planejamento/resumo` monta a entrada inteira do `calculo.calcular` e devolve o que o Início mostra: o saldo disponível, quantos rascunhos o cálculo considera, a previsão (nula sem renda ativa ou sem configuração), o gasto mensal de referência e a meta da reserva. As linhas de fatura já trazem o nome do cartão, e o salário recebido traz a descrição da renda e o nome da conta, para o app não cruzar com outras listas.
- **Saldo das contas para o cálculo:** a mesma consulta do saldo da tela de contas, com rascunhos e sem as possíveis duplicatas, só das contas ativas. A tela de contas continua com o saldo oficial (só confirmadas).
- **Faturas:** as gravadas de cartões ativos; a fatura só calculada vale zero e não pesa. O cálculo escolhe as que vencem até o próximo salário.
- **"Considera N rascunhos":** os rascunhos sem marca de duplicata, de qualquer conta, a mesma regra do cálculo. O aviso tem borda contínua no tom do rascunho (o Flutter não tem borda tracejada pronta). É outro número que o contador da aba Revisão (que conta um par como 1 e inclui as duplicatas a decidir); o atalho "Revisar" leva à aba.
- **Card principal:** com aporte maior que zero (salário detectado e sobra acima do colchão), "Salário recebido: você pode aportar", com o colchão como linha da conta. Sem salário detectado, ou com aporte zero, "Sobra prevista até o salário" com o chip do nível (no ritmo, atenção, risco): quando não sobra, o alerta assume. Gastos previstos dizem "pela média recente" quando a média passou do gasto semanal estimado.
- **"Registrar aporte" fica desabilitado, com o aviso "em breve"**, até os investimentos (S8): hoje não há aporte manual, e o aporte das fontes chega pela revisão.
- **"Agora não" fica no aparelho** (`shared_preferences`), pela renda e pela data esperada do salário dispensado: o card volta à sobra e ao alerta até o salário seguinte. Usuário único, um aparelho: não compensa tabela nem endpoint.
- **Reserva "em breve"** até a S8: sem investimentos, a reserva seria sempre 0 meses. O card mostra a meta e o gasto mensal de referência e avisa que o saldo da reserva entra com os investimentos; a API ainda não devolve reserva nem meses depois do aporte.
- **Sem salário cadastrado** (sem renda ativa ou sem configuração): "Cadastre seu salário", que abre Mais → Planejamento, e o saldo disponível **oficial** (só confirmadas, o mesmo da aba Contas): sem cálculo, não há por que contar os rascunhos nem mostrar o aviso deles.
- **Recarga:** o Início carrega o resumo ao abrir, ao puxar para atualizar e a cada volta para a aba; o cubit fica no topo do app, como o das contas, e recarrega também no login.

### Plano de aporte recorrente (proposta, 2026-10-31)

Pedido do Yago no design de Investimentos: planejar um aporte fixo e periódico (ex.: R$ 20,00 toda semana), ver se ele cabe no que está guardado e no ritmo de gastos, e ser avisado quando o ritmo ameaçar o plano. Entra na S8, com os investimentos, porque o aporte do plano vai para um investimento. Em discussão até o design ser aprovado.

- **Onde:** "Planejar aporte" na tela Investimentos. O plano tem valor (> 0), frequência (`semanal`, `quinzenal` ou `mensal`), o dia (da semana, ou do mês de 1 a 31, com a regra do mês curto da renda), a conta de onde sai (corrente ou carteira ativa), o investimento de destino e se está ativo. Como a renda, é desativado, nunca excluído. Tabela nova `plano_aporte`.
- **Com o aporte do dia do salário:** ao salvar o primeiro plano, o app pergunta se mantém os dois ou só o plano (`configuracao.aporte_no_salario`, padrão verdadeiro; editável depois em "Aporte e reserva"). Só o plano: o Início deixa de sugerir o aporte do salário e passa a mostrar o plano.
- **No cálculo:** as datas do plano de hoje até antes do próximo salário são reservadas como as faturas: `sobra = saldo disponível − faturas − gastos previstos − aportes do plano`. O nível do alerta usa essa sobra, e o aporte do dia do salário (quando mantido) vira `sobra − colchão`, já descontado o plano. Continua no `calculo.py`, puro.
- **A análise antes de salvar** mostra duas contas, com o plano proposto:
  - **até o próximo salário:** quantas datas caem no período, o total e a sobra que fica. Os níveis são os do alerta: cabe (sobra ≥ colchão), aperta o colchão (0 a colchão) ou não cabe (negativa). Sem caber, sugere o maior valor por período que mantém a sobra no colchão;
  - **num mês típico:** o plano em valor mensal (semanal × 52 ÷ 12, quinzenal × 26 ÷ 12) contra a renda prevista ativa menos o gasto mensal de referência.
  Sem renda ativa ou sem configuração, a análise pede o cadastro, como o Início.
- **Aviso:** quando o plano é o que derruba o nível (o nível sem o plano seria melhor), o card da sobra no Início diz que o ritmo de gastos ameaça o plano, com o valor e a frequência. O plano entra também como linha da conta do card ("Plano de aporte · 4 sextas").
- **Cumprido ou pendente:** o app não move dinheiro. O aporte do período conta como feito quando existe um `aporte` (confirmado ou rascunho) para o investimento do plano, dentro do período, somando ao menos o valor; a tela mostra "feito" ou "pendente" no período atual.

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
