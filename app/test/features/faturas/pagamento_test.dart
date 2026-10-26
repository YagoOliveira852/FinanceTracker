import 'package:bloc_test/bloc_test.dart';
import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/faturas/cubit/pagamento_cubit.dart';
import 'package:financas/features/faturas/data/fatura.dart';
import 'package:financas/features/faturas/data/pagamento.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/faturas_falso.dart';

void main() {
  final hoje = DateTime(2026, 10, 20, 14, 30);
  final setembroPago = outubroExemplo.copyWith(
    competencia: DateTime(2026, 9),
    dataFechamento: DateTime(2026, 9, 3),
    dataVencimento: DateTime(2026, 9, 10),
    status: StatusFatura.paga,
    valorPago: Decimal.parse('1032.15'),
  );
  final agostoFechado = outubroExemplo.copyWith(competencia: DateTime(2026, 8));
  final lista = ListaFaturas(
    atual: novembroExemplo,
    proximas: [dezembroExemplo],
    anteriores: [outubroExemplo, setembroPago, agostoFechado],
  );

  group('regras do pagamento', () {
    test('a pagar: valor menos o pago, nunca negativo', () {
      expect(
        outubroExemplo.copyWith(valorPago: Decimal.parse('32.15')).aPagar,
        Decimal.parse('1000.00'),
      );
      expect(
        outubroExemplo.copyWith(valorPago: Decimal.parse('2000')).aPagar,
        Decimal.zero,
      );
    });

    test('faturas para pagar: fechadas da mais antiga, depois a atual', () {
      expect(faturasParaPagar(lista).map((f) => f.competencia), [
        DateTime(2026, 8),
        DateTime(2026, 10),
        DateTime(2026, 11),
      ]);
    });

    test('incluir acrescenta uma fatura fora da lista, em ordem', () {
      expect(
        faturasParaPagar(
          lista,
          incluir: DateTime(2026, 9),
        ).map((f) => f.competencia),
        [
          DateTime(2026, 8),
          DateTime(2026, 9),
          DateTime(2026, 10),
          DateTime(2026, 11),
        ],
      );
    });

    test('fatura padrão: a incluída, senão a fechada mais antiga', () {
      final opcoes = faturasParaPagar(lista, incluir: DateTime(2026, 9));
      expect(
        faturaPadrao(opcoes, incluir: DateTime(2026, 9)).competencia,
        DateTime(2026, 9),
      );
      expect(faturaPadrao(opcoes).competencia, DateTime(2026, 8));
      expect(faturaPadrao([novembroExemplo]), novembroExemplo);
    });

    test('data padrão: a menor entre o vencimento e hoje', () {
      expect(
        dataPadraoDoPagamento(outubroExemplo, hoje),
        DateTime(2026, 10, 13),
      );
      expect(
        dataPadraoDoPagamento(novembroExemplo, hoje),
        DateTime(2026, 10, 20),
      );
    });
  });

  group('PagamentoCubit', () {
    late FaturasRepositorioFalso faturas;

    setUp(() => faturas = FaturasRepositorioFalso()..lista = lista);

    PagamentoCubit criar() => PagamentoCubit(faturas);

    test('escolher o cartão carrega as faturas e escolhe a padrão', () async {
      final cubit = criar();

      await cubit.escolherCartao('k1');

      expect(cubit.state.cartaoId, 'k1');
      expect(cubit.state.faturas.map((f) => f.competencia), [
        DateTime(2026, 8),
        DateTime(2026, 10),
        DateTime(2026, 11),
      ]);
      expect(cubit.state.fatura?.competencia, DateTime(2026, 8));
      expect(cubit.state.carregando, isFalse);
    });

    test('aberto pela fatura, já vem com ela escolhida', () async {
      final cubit = criar();

      await cubit.escolherCartao('k1', competencia: DateTime(2026, 9));

      expect(cubit.state.fatura?.competencia, DateTime(2026, 9));
    });

    test('trocar de fatura', () async {
      final cubit = criar();
      await cubit.escolherCartao('k1');

      cubit.escolherFatura(DateTime(2026, 11));

      expect(cubit.state.fatura, novembroExemplo);
    });

    test('erro ao carregar as faturas aparece no estado', () async {
      faturas.erro = const ErroApi(ErroApi.semConexao);
      final cubit = criar();

      await cubit.escolherCartao('k1');

      expect(cubit.state.erroGeral, 'Não foi possível falar com o servidor.');
      expect(cubit.state.carregando, isFalse);
    });

    test('valida conta e valor no aparelho', () async {
      final cubit = criar();
      await cubit.escolherCartao('k1');

      await cubit.salvar(contaId: null, valor: '0,00', data: hoje);

      expect(cubit.state.erros, {
        'conta_id': 'Escolha a conta que paga.',
        'valor': 'Informe um valor maior que zero.',
      });
      expect(faturas.pagamentos, isEmpty);
    });

    test('salva com Decimal e data sem horário', () async {
      final cubit = criar();
      await cubit.escolherCartao('k1');

      await cubit.salvar(contaId: 'c1', valor: '1.032,15', data: hoje);

      final pago = faturas.pagamentos.single;
      expect(pago.cartaoId, 'k1');
      expect(pago.competencia, DateTime(2026, 8));
      expect(pago.dados.contaId, 'c1');
      expect(pago.dados.valor, Decimal.parse('1032.15'));
      expect(pago.dados.data, DateTime(2026, 10, 20));
      expect(cubit.state.salvo, isNotNull);
    });

    blocTest<PagamentoCubit, PagamentoEstado>(
      'conta recusada pela API aparece no campo',
      build: criar,
      act: (cubit) async {
        await cubit.escolherCartao('k1');
        faturas.erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {'conta_id': 'Pague com uma conta corrente ou carteira.'},
        );
        await cubit.salvar(contaId: 'k1', valor: '10', data: hoje);
      },
      verify: (cubit) => expect(cubit.state.erros, {
        'conta_id': 'Pague com uma conta corrente ou carteira.',
      }),
    );
  });
}
