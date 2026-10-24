import 'package:decimal/decimal.dart';
import 'package:financas/core/formatacao/dinheiro.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String valor) => Decimal.parse(valor);

void main() {
  group('formatarDinheiro', () {
    test('separa milhar com ponto e centavos com vírgula', () {
      expect(formatarDinheiro(d('1234.56')), 'R\$ 1.234,56');
      expect(formatarDinheiro(d('1234567.89')), 'R\$ 1.234.567,89');
    });

    test('sempre mostra duas casas', () {
      expect(formatarDinheiro(d('0')), 'R\$ 0,00');
      expect(formatarDinheiro(d('950.5')), 'R\$ 950,50');
      expect(formatarDinheiro(d('100')), 'R\$ 100,00');
    });

    test('negativo usa o sinal de menos antes do R\$', () {
      expect(formatarDinheiro(d('-120.40')), '− R\$ 120,40');
    });
  });

  group('formatarDinheiroComSinal', () {
    test('entrada com +, saída com −', () {
      expect(formatarDinheiroComSinal(d('850'), entrada: true), '+ R\$ 850,00');
      expect(
        formatarDinheiroComSinal(d('187.4'), entrada: false),
        '− R\$ 187,40',
      );
    });
  });

  group('lerDinheiro', () {
    test('aceita com e sem separador de milhar', () {
      expect(lerDinheiro('1.234,56'), d('1234.56'));
      expect(lerDinheiro('1234,56'), d('1234.56'));
      expect(lerDinheiro('1234,5'), d('1234.5'));
      expect(lerDinheiro('42'), d('42'));
      expect(lerDinheiro(' 12,30 '), d('12.3'));
    });

    test('aceita sinal de menos', () {
      expect(lerDinheiro('-120,40'), d('-120.40'));
      expect(lerDinheiro('−120,40'), d('-120.40'));
    });

    test('recusa texto que não é valor', () {
      expect(lerDinheiro(''), isNull);
      expect(lerDinheiro('abc'), isNull);
      expect(lerDinheiro('12.34'), isNull); // ponto só como milhar
      expect(lerDinheiro('1.23,45'), isNull);
      expect(lerDinheiro('1,2,3'), isNull);
    });
  });

  group('validarDinheiro', () {
    test('valor válido não tem erro', () {
      expect(validarDinheiro('1.234,56'), isNull);
      expect(validarDinheiro('0,00'), isNull);
    });

    test('vazio ou inválido', () {
      expect(validarDinheiro(''), 'Informe um valor, por exemplo: 1.234,56.');
      expect(validarDinheiro('abc'), 'Valor inválido. Use o formato 1.234,56.');
    });

    test('mais de duas casas', () {
      expect(
        validarDinheiro('1.234,567'),
        'Use no máximo 2 casas decimais, por exemplo: 1.234,56.',
      );
    });

    test('negativo só quando aceito', () {
      expect(validarDinheiro('-120,40'), 'O valor não pode ser negativo.');
      expect(validarDinheiro('-120,40', aceitaNegativo: true), isNull);
    });

    test('exigePositivo recusa vazio, zero e negativo', () {
      const mensagem = 'Informe um valor maior que zero.';
      expect(validarDinheiro('', exigePositivo: true), mensagem);
      expect(validarDinheiro('0,00', exigePositivo: true), mensagem);
      expect(validarDinheiro('-5', exigePositivo: true), mensagem);
      expect(validarDinheiro('0,01', exigePositivo: true), isNull);
    });

    test('limite do NUMERIC(14,2): 12 dígitos antes da vírgula', () {
      expect(validarDinheiro('999.999.999.999,99'), isNull);
      expect(validarDinheiro('1.000.000.000.000,00'), 'Valor alto demais.');
    });
  });

  test('paraApi manda sempre duas casas, com ponto', () {
    expect(dinheiroParaApi(d('1234.5')), '1234.50');
    expect(dinheiroParaApi(d('-120.4')), '-120.40');
  });

  test('dinheiroParaCampo volta pelo lerDinheiro', () {
    expect(dinheiroParaCampo(Decimal.parse('1032.15')), '1.032,15');
    expect(dinheiroParaCampo(Decimal.parse('-120.4')), '-120,40');
    expect(
      lerDinheiro(dinheiroParaCampo(Decimal.parse('1032.15'))),
      Decimal.parse('1032.15'),
    );
  });
}
