import 'package:decimal/decimal.dart';
import 'package:financas/features/planejamento/cubit/ajustes_calculo_cubit.dart';
import 'package:financas/features/planejamento/data/planejamento.dart';
import 'package:financas/features/planejamento/ui/textos.dart';
import 'package:flutter_test/flutter_test.dart';

ProximaData _proxima(
  DateTime data, {
  DateTime? prevista,
  Map<DateTime, String> feriados = const {},
}) =>
    ProximaData(data: data, dataPrevista: prevista ?? data, feriados: feriados);

void main() {
  group('descreverProxima', () {
    test('dia útil: só a data', () {
      expect(
        descreverProxima(_proxima(DateTime(2026, 11, 10)), diaPrevisto: 10),
        'terça, 10 nov',
      );
    });

    test('domingo e feriado', () {
      final proxima = _proxima(
        DateTime(2026, 11, 16),
        prevista: DateTime(2026, 11, 15),
        feriados: {DateTime(2026, 11, 15): 'Proclamação da República'},
      );

      expect(
        descreverProxima(proxima, diaPrevisto: 15),
        'segunda, 16 nov (dia 15 é domingo e feriado)',
      );
    });

    test('feriado num dia de semana', () {
      final proxima = _proxima(
        DateTime(2026, 11, 23),
        prevista: DateTime(2026, 11, 20),
        feriados: {DateTime(2026, 11, 20): 'Consciência Negra'},
      );

      expect(
        descreverProxima(proxima, diaPrevisto: 20),
        'segunda, 23 nov (dia 20 é feriado)',
      );
    });

    test('sábado e a segunda é feriado', () {
      final proxima = _proxima(
        DateTime(2026, 11, 3),
        prevista: DateTime(2026, 10, 31),
        feriados: {DateTime(2026, 11, 2): 'Finados'},
      );

      expect(
        descreverProxima(proxima, diaPrevisto: 31),
        'terça, 3 nov (dia 31 é sábado e 2 nov é feriado)',
      );
    });

    test('mês mais curto', () {
      expect(
        descreverProxima(_proxima(DateTime(2026, 11, 30)), diaPrevisto: 31),
        'segunda, 30 nov (novembro tem 30 dias)',
      );
    });

    test('mês mais curto e fim de semana', () {
      final proxima = _proxima(
        DateTime(2027, 3, 1),
        prevista: DateTime(2027, 2, 28),
      );

      expect(
        descreverProxima(proxima, diaPrevisto: 30),
        'segunda, 1 mar (fevereiro tem 28 dias; dia 28 é domingo)',
      );
    });
  });

  test('formatarMeses', () {
    expect(formatarMeses(Decimal.parse('6')), '6 meses');
    expect(formatarMeses(Decimal.parse('4.2')), '4,2 meses');
    expect(formatarMeses(Decimal.parse('1')), '1 mês');
    expect(formatarMeses(Decimal.parse('1.5')), '1,5 mês');
    expect(formatarMeses(Decimal.zero), '0 meses');
  });

  test('intervaloDeMeses e listaDeMeses', () {
    final tres = [DateTime(2026, 7), DateTime(2026, 8), DateTime(2026, 9)];

    expect(intervaloDeMeses(tres), 'jul a set');
    expect(listaDeMeses(tres), 'jul, ago e set');
    expect(intervaloDeMeses(tres.sublist(1)), 'ago e set');
    expect(listaDeMeses(tres.sublist(2)), 'set');
  });

  test('gastoPorDia arredonda ao centavo', () {
    expect(gastoPorDia(Decimal.parse('280')), Decimal.parse('40'));
    expect(gastoPorDia(Decimal.parse('160')), Decimal.parse('22.86'));
  });

  test('lerMeses aceita vírgula e uma casa', () {
    expect(lerMeses('6'), Decimal.parse('6'));
    expect(lerMeses(' 4,5 '), Decimal.parse('4.5'));
    expect(lerMeses('4.5'), Decimal.parse('4.5'));
    expect(lerMeses('4,55'), isNull);
    expect(lerMeses('1000'), isNull);
    expect(lerMeses('seis'), isNull);
  });
}
