import 'package:decimal/decimal.dart';
import 'package:financas/features/faturas/data/fatura.dart';
import 'package:financas/features/faturas/ui/textos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('explicarAjuste', () {
    test('fim de semana e feriado em seguida', () {
      final ajuste = AjusteData(
        dataPrevista: DateTime(2026, 10, 10),
        feriados: {DateTime(2026, 10, 12): 'Nossa Senhora Aparecida'},
      );

      expect(
        explicarAjuste(ajuste),
        'Dia 10 caiu num sábado e 12 out é feriado: passou para o próximo '
        'dia útil.',
      );
    });

    test('só o fim de semana', () {
      final ajuste = AjusteData(
        dataPrevista: DateTime(2026, 10, 3),
        feriados: const {},
      );

      expect(
        explicarAjuste(ajuste),
        'Dia 3 caiu num sábado: passou para o próximo dia útil.',
      );
    });

    test('domingo', () {
      final ajuste = AjusteData(
        dataPrevista: DateTime(2026, 10, 11),
        feriados: {DateTime(2026, 10, 12): 'Nossa Senhora Aparecida'},
      );

      expect(
        explicarAjuste(ajuste),
        'Dia 11 caiu num domingo e 12 out é feriado: passou para o próximo '
        'dia útil.',
      );
    });

    test('o próprio dia é feriado', () {
      final ajuste = AjusteData(
        dataPrevista: DateTime(2026, 10, 12),
        feriados: {DateTime(2026, 10, 12): 'Nossa Senhora Aparecida'},
      );

      expect(
        explicarAjuste(ajuste),
        'Dia 12 é feriado: passou para o próximo dia útil.',
      );
    });
  });

  group('descreverDiferenca', () {
    test('faltam lançamentos', () {
      expect(
        descreverDiferenca(Decimal.parse('45.90')),
        'Faltam R\$ 45,90 em lançamentos.',
      );
    });

    test('lançado a mais', () {
      expect(
        descreverDiferenca(Decimal.parse('-12.00')),
        'Lançado R\$ 12,00 a mais que o banco informou.',
      );
    });
  });

  test(
    'ResumoFatura.diferenca: informado menos calculado, nula sem informado',
    () {
      final base = ResumoFatura(
        competencia: DateTime(2026, 10),
        dataFechamento: DateTime(2026, 10, 5),
        dataVencimento: DateTime(2026, 10, 13),
        status: StatusFatura.fechada,
        valor: Decimal.parse('1032.15'),
        valorCalculado: Decimal.parse('986.25'),
        valorPago: Decimal.zero,
      );

      expect(base.diferenca, isNull);
      expect(
        base.copyWith(valorInformado: Decimal.parse('1032.15')).diferenca,
        Decimal.parse('45.90'),
      );
      expect(
        base.copyWith(valorInformado: Decimal.parse('986.25')).diferenca,
        isNull,
      );
    },
  );

  test('competenciaParaApi', () {
    expect(competenciaParaApi(DateTime(2026, 3)), '2026-03');
    expect(competenciaParaApi(DateTime(2026, 11)), '2026-11');
  });
}
