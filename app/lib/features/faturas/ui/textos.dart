/// Frases das telas de fatura montadas a partir dos dados da API.
library;

import 'package:decimal/decimal.dart';

import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/fatura.dart';

/// "Dia 10 caiu num sábado e 12 out é feriado: passou para o próximo dia
/// útil."
String explicarAjuste(AjusteData ajuste) {
  final prevista = ajuste.dataPrevista;
  final motivo = switch (prevista.weekday) {
    DateTime.saturday => 'Dia ${prevista.day} caiu num sábado',
    DateTime.sunday => 'Dia ${prevista.day} caiu num domingo',
    _ => 'Dia ${prevista.day} é feriado',
  };
  final outros = [
    for (final feriado in ajuste.feriados.keys)
      if (feriado != prevista) ' e ${formatarDiaMes(feriado)} é feriado',
  ];
  return '$motivo${outros.join()}: passou para o próximo dia útil.';
}

/// Diferença entre o informado e o calculado (informado − calculado).
String descreverDiferenca(Decimal diferenca) => diferenca > Decimal.zero
    ? 'Faltam ${formatarDinheiro(diferenca)} em lançamentos.'
    : 'Lançado ${formatarDinheiro(-diferenca)} a mais que o banco informou.';

/// "Fatura de novembro de 2026".
String tituloDaFatura(DateTime competencia) =>
    'Fatura de ${nomeDoMes(competencia)} de ${competencia.year}';
