/// Frases das telas do Planejamento montadas a partir dos dados da API.
library;

import 'package:decimal/decimal.dart';

import '../../../core/formatacao/datas.dart';
import '../data/planejamento.dart';

/// `terça, 10 nov` ou, quando a data muda, com o motivo:
/// `segunda, 16 nov (dia 15 é domingo e feriado)`.
String descreverProxima(ProximaData proxima, {required int diaPrevisto}) {
  final data = formatarDiaDaSemana(proxima.data);
  final motivo = _motivo(proxima, diaPrevisto);
  return motivo == null ? data : '$data ($motivo)';
}

String? _motivo(ProximaData proxima, int diaPrevisto) {
  final prevista = proxima.dataPrevista;
  final partes = [
    if (prevista.day != diaPrevisto)
      '${nomeDoMes(prevista)} tem ${prevista.day} dias',
    if (proxima.data != prevista) _porQueMudou(proxima),
  ];
  return partes.isEmpty ? null : partes.join('; ');
}

/// "dia 15 é domingo e feriado", "dia 31 é sábado e 2 nov é feriado".
String _porQueMudou(ProximaData proxima) {
  final prevista = proxima.dataPrevista;
  final motivos = [
    if (prevista.weekday == DateTime.saturday) 'sábado',
    if (prevista.weekday == DateTime.sunday) 'domingo',
    if (proxima.feriados.containsKey(prevista)) 'feriado',
  ];
  final outros = [
    for (final feriado in proxima.feriados.keys)
      if (feriado != prevista) ' e ${formatarDiaMes(feriado)} é feriado',
  ];
  return 'dia ${prevista.day} é ${motivos.join(' e ')}${outros.join()}';
}

/// `6 meses`, `4,2 meses`, `1 mês`.
String formatarMeses(Decimal meses) {
  final numero = meses
      .toStringAsFixed(1)
      .replaceFirst(RegExp(r'\.0$'), '')
      .replaceAll('.', ',');
  // Singular de 0 a 2 exclusive ("1,5 mês"), menos o zero.
  final singular = meses > Decimal.zero && meses < Decimal.fromInt(2);
  return '$numero ${singular ? 'mês' : 'meses'}';
}

/// `jul a set`, `ago e set` ou `set`: meses da média automática.
String intervaloDeMeses(List<DateTime> meses) => switch (meses) {
  [final mes] => nomeDoMesCurto(mes),
  [final primeiro, final ultimo] =>
    '${nomeDoMesCurto(primeiro)} e ${nomeDoMesCurto(ultimo)}',
  _ => '${nomeDoMesCurto(meses.first)} a ${nomeDoMesCurto(meses.last)}',
};

/// `jul, ago e set`.
String listaDeMeses(List<DateTime> meses) {
  final nomes = meses.map(nomeDoMesCurto).toList();
  if (nomes.length == 1) return nomes.single;
  return '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}';
}

/// O gasto semanal em reais por dia, arredondado ao centavo.
Decimal gastoPorDia(Decimal semanal) => (semanal / Decimal.fromInt(7))
    .toDecimal(scaleOnInfinitePrecision: 10)
    .round(scale: 2);
