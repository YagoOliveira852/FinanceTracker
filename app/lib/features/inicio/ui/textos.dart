/// Frases do Início montadas a partir do resumo do planejamento.
library;

import 'package:decimal/decimal.dart';

import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../planejamento/data/resumo.dart';

/// A frase do card da sobra, pelo nível do alerta:
/// - no ritmo: "Salário previsto para terça, 10 nov. A sobra cobre o colchão
///   de R$ 500,00."
/// - atenção: "… A sobra não cobre o colchão de R$ 500,00: faltam R$ 152,05."
/// - risco: "Sem ajuste, faltariam R$ 252,05 até o salário de terça, 10 nov,
///   e seria preciso resgatar da reserva."
String fraseDaSobra(Previsao previsao, DateTime hoje) {
  final quando = _quando(previsao.proximoSalario, hoje);
  final colchao = formatarDinheiro(previsao.colchao);
  return switch (previsao.nivel) {
    NivelRitmo.vermelho =>
      'Sem ajuste, faltariam ${formatarDinheiro(-previsao.sobra)} até o '
          'salário de $quando, e seria preciso resgatar da reserva.',
    NivelRitmo.amarelo =>
      '${_salarioPrevisto(previsao.proximoSalario, hoje)} A sobra não cobre o '
          'colchão de $colchao: faltam '
          '${formatarDinheiro(previsao.colchao - previsao.sobra)}.',
    NivelRitmo.verde when previsao.colchao == Decimal.zero => _salarioPrevisto(
      previsao.proximoSalario,
      hoje,
    ),
    NivelRitmo.verde =>
      '${_salarioPrevisto(previsao.proximoSalario, hoje)} A sobra cobre o '
          'colchão de $colchao.',
  };
}

/// "Salário previsto para terça, 10 nov.", "… para hoje." ou, atrasado
/// (ainda na janela de espera), "… para terça, 10 nov, e ainda não chegou."
String _salarioPrevisto(DateTime salario, DateTime hoje) {
  final atrasado = salario.isBefore(hoje) ? ', e ainda não chegou' : '';
  return 'Salário previsto para ${_quando(salario, hoje)}$atrasado.';
}

String _quando(DateTime dia, DateTime hoje) =>
    dia == hoje ? 'hoje' : formatarDiaDaSemana(dia);

/// "Fatura Cartão Exemplo · vence 10 nov" ou, já vencida, "· venceu 3 nov".
String linhaDaFatura(FaturaReservada fatura, DateTime hoje) {
  final verbo = fatura.vencimento.isBefore(hoje) ? 'venceu' : 'vence';
  return 'Fatura ${fatura.cartao} · $verbo ${formatarDiaMes(fatura.vencimento)}';
}

/// "Gastos previstos · 21 dias", "… · 1 dia" e, quando a média das últimas
/// semanas passou do gasto semanal estimado, ", pela média recente".
String linhaDosGastos(Previsao previsao) {
  final dias = previsao.diasAteSalario;
  final media = previsao.gastosPelaMedia ? ', pela média recente' : '';
  return 'Gastos previstos · $dias ${dias == 1 ? 'dia' : 'dias'}$media';
}

/// "O salário de R$ 4.200,00 caiu hoje na Conta principal. O resto fica na
/// conta até o próximo salário, em 10 dez."
String fraseDoAporte(Previsao previsao, DateTime hoje) {
  final salario = previsao.salarioRecebido!;
  final diferenca = DateTime.utc(hoje.year, hoje.month, hoje.day)
      .difference(
        DateTime.utc(salario.data.year, salario.data.month, salario.data.day),
      )
      .inDays;
  final quando = switch (diferenca) {
    0 => 'hoje',
    1 => 'ontem',
    _ => 'em ${formatarDiaMes(salario.data)}',
  };
  return 'O salário de ${formatarDinheiro(salario.valor)} caiu $quando na '
      '${salario.conta}. O resto fica na conta até o próximo salário, em '
      '${formatarDiaMes(previsao.proximoSalario)}.';
}

/// "Considera 2 rascunhos não revisados", "Considera 1 rascunho não revisado".
String fraseDosRascunhos(int quantidade) => quantidade == 1
    ? 'Considera 1 rascunho não revisado'
    : 'Considera $quantidade rascunhos não revisados';

/// Card da reserva até os investimentos existirem: a meta e o gasto de
/// referência, sem os meses (seriam sempre 0).
String fraseDaReserva(GastoMensalReferencia? gasto) {
  const emBreve =
      'Os investimentos chegam em breve; com eles, a reserva aparece aqui em '
      'meses de gasto.';
  if (gasto == null) return emBreve;
  final origem = gasto.automatico ? 'média dos últimos meses' : 'valor fixo';
  return '$emBreve Gasto de referência: ${formatarDinheiro(gasto.valor)} por '
      'mês ($origem).';
}
