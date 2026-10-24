import 'package:financas/core/formatacao/datas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hoje = DateTime(2026, 10, 20); // terça

  test('nomeDoMes', () {
    expect(nomeDoMes(DateTime(2026, 9, 1)), 'setembro');
  });

  test('formatarMesAno', () {
    expect(formatarMesAno(DateTime(2026, 10, 1)), 'Outubro de 2026');
    expect(formatarMesAno(DateTime(2026, 3, 15)), 'Março de 2026');
  });

  test('formatarCabecalhoDia: hoje, ontem e dia da semana', () {
    expect(formatarCabecalhoDia(DateTime(2026, 10, 20), hoje), 'Hoje · 20 out');
    expect(
      formatarCabecalhoDia(DateTime(2026, 10, 19), hoje),
      'Ontem · 19 out',
    );
    expect(formatarCabecalhoDia(DateTime(2026, 10, 16), hoje), 'Sex · 16 out');
    expect(formatarCabecalhoDia(DateTime(2026, 10, 17), hoje), 'Sáb · 17 out');
    expect(formatarCabecalhoDia(DateTime(2026, 9, 6), hoje), 'Dom · 6 set');
  });

  test('formatarCabecalhoDia ignora o horário de hoje', () {
    expect(
      formatarCabecalhoDia(
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20, 23, 59),
      ),
      'Ontem · 19 out',
    );
  });

  test('formatarData', () {
    expect(formatarData(DateTime(2026, 10, 5)), '05/10/2026');
  });

  test('formatarDataLonga', () {
    expect(formatarDataLonga(hoje), 'Terça, 20 de outubro');
    expect(formatarDataLonga(DateTime(2026, 11, 1)), 'Domingo, 1 de novembro');
  });

  test('somenteData tira o horário', () {
    expect(somenteData(DateTime(2026, 10, 20, 13, 45)), DateTime(2026, 10, 20));
  });

  test('formatarDiaCurto: dia da semana minúsculo e mês curto', () {
    expect(formatarDiaCurto(DateTime(2026, 11, 3)), 'ter, 3 nov');
    expect(formatarDiaCurto(DateTime(2026, 10, 10)), 'sáb, 10 out');
  });
}
