import 'package:decimal/decimal.dart';
import 'package:financas/features/inicio/ui/textos.dart';
import 'package:financas/features/planejamento/data/resumo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/planejamento_falso.dart';

void main() {
  final hoje = DateTime(2026, 10, 20);
  Previsao previsao(NivelRitmo nivel) =>
      resumoComPrevisao(nivel: nivel).previsao!;

  group('fraseDaSobra', () {
    test('no ritmo: a sobra cobre o colchão', () {
      expect(
        fraseDaSobra(previsao(NivelRitmo.verde), hoje),
        'Salário previsto para terça, 10 nov. A sobra cobre o colchão de '
        'R\$ 500,00.',
      );
    });

    test('no ritmo sem colchão: só a data', () {
      final semColchao = previsao(NivelRitmo.verde)
          .copyWith(colchao: Decimal.zero);

      expect(
        fraseDaSobra(semColchao, hoje),
        'Salário previsto para terça, 10 nov.',
      );
    });

    test('atenção: quanto falta para o colchão', () {
      expect(
        fraseDaSobra(previsao(NivelRitmo.amarelo), hoje),
        'Salário previsto para terça, 10 nov. A sobra não cobre o colchão de '
        'R\$ 500,00: faltam R\$ 152,05.',
      );
    });

    test('risco: quanto faltaria até o salário', () {
      expect(
        fraseDaSobra(previsao(NivelRitmo.vermelho), hoje),
        'Sem ajuste, faltariam R\$ 252,05 até o salário de terça, 10 nov, e '
        'seria preciso resgatar da reserva.',
      );
    });

    test('salário previsto para hoje', () {
      expect(
        fraseDaSobra(previsao(NivelRitmo.verde), DateTime(2026, 11, 10)),
        startsWith('Salário previsto para hoje.'),
      );
    });

    test('salário atrasado, ainda na janela', () {
      expect(
        fraseDaSobra(previsao(NivelRitmo.verde), DateTime(2026, 11, 12)),
        startsWith('Salário previsto para terça, 10 nov, e ainda não chegou.'),
      );
    });
  });

  test('linhaDaFatura: vence ou venceu', () {
    final fatura = previsao(NivelRitmo.verde).faturas.single;

    expect(linhaDaFatura(fatura, hoje), 'Fatura Cartão Exemplo · vence 10 nov');
    expect(
      linhaDaFatura(fatura, DateTime(2026, 11, 11)),
      'Fatura Cartão Exemplo · venceu 10 nov',
    );
  });

  test('linhaDosGastos: dias e a média recente', () {
    expect(
      linhaDosGastos(previsao(NivelRitmo.verde)),
      'Gastos previstos · 21 dias',
    );
    expect(
      linhaDosGastos(previsao(NivelRitmo.amarelo)),
      'Gastos previstos · 21 dias, pela média recente',
    );
    expect(
      linhaDosGastos(previsao(NivelRitmo.verde).copyWith(diasAteSalario: 1)),
      'Gastos previstos · 1 dia',
    );
  });

  test('fraseDoAporte: quando caiu, onde e o próximo salário', () {
    final recebido = resumoSalarioRecebido().previsao!;

    expect(
      fraseDoAporte(recebido, DateTime(2026, 11, 10)),
      'O salário de R\$ 4.200,00 caiu hoje na Conta principal. O resto fica '
      'na conta até o próximo salário, em 10 dez.',
    );
    expect(
      fraseDoAporte(recebido, DateTime(2026, 11, 11)),
      startsWith('O salário de R\$ 4.200,00 caiu ontem'),
    );
    expect(
      fraseDoAporte(recebido, DateTime(2026, 11, 13)),
      startsWith('O salário de R\$ 4.200,00 caiu em 10 nov'),
    );
  });

  test('fraseDosRascunhos: singular e plural', () {
    expect(fraseDosRascunhos(1), 'Considera 1 rascunho não revisado');
    expect(fraseDosRascunhos(2), 'Considera 2 rascunhos não revisados');
  });

  test('fraseDaReserva: em breve, com o gasto de referência', () {
    expect(
      fraseDaReserva(null),
      'Os investimentos chegam em breve; com eles, a reserva aparece aqui em '
      'meses de gasto.',
    );
    expect(
      fraseDaReserva(
        GastoMensalReferencia(valor: Decimal.parse('3000'), automatico: false),
      ),
      endsWith('Gasto de referência: R\$ 3.000,00 por mês (valor fixo).'),
    );
  });
}
