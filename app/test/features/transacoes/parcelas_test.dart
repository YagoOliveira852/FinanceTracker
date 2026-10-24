import 'package:decimal/decimal.dart';
import 'package:financas/features/transacoes/data/parcelas.dart';
import 'package:financas/features/transacoes/ui/textos.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String valor) => Decimal.parse(valor);

void main() {
  group('dividirEmParcelas (mesmos casos do backend)', () {
    final casos = <(String, int, List<String>)>[
      ('1000.00', 3, ['333.34', '333.33', '333.33']),
      ('300.00', 3, ['100.00', '100.00', '100.00']),
      ('1.00', 7, ['0.16', ...List.filled(6, '0.14')]),
      ('0.03', 3, ['0.01', '0.01', '0.01']),
      ('2499.90', 10, List.filled(10, '249.99')),
      ('100.01', 2, ['50.01', '50.00']),
    ];
    for (final (total, quantidade, parcelas) in casos) {
      test('$total em ${quantidade}x', () {
        final resultado = dividirEmParcelas(d(total), quantidade);

        expect(resultado, parcelas.map(d).toList());
        expect(resultado.reduce((a, b) => a + b), d(total));
      });
    }

    test('sem um centavo para cada parcela é erro', () {
      expect(() => dividirEmParcelas(d('0.02'), 3), throwsArgumentError);
    });
  });

  group('textoDaDivisao', () {
    test('com resto, a 1ª parcela fica com ele', () {
      expect(
        textoDaDivisao(d('1000.00'), 3),
        '3x de R\$ 333,33; a 1ª parcela fica com R\$ 333,34.',
      );
    });

    test('divisão exata', () {
      expect(textoDaDivisao(d('300.00'), 3), '3x de R\$ 100,00.');
    });
  });

  test('textoDaUltimaParcela atravessa o ano', () {
    expect(
      textoDaUltimaParcela(DateTime(2026, 11), 3),
      'A última parcela cai na fatura de janeiro de 2027.',
    );
  });
}
