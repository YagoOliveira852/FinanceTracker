import 'package:bloc_test/bloc_test.dart';
import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/transacoes/cubit/lancamento_cubit.dart';
import 'package:financas/features/transacoes/cubit/transacoes_cubit.dart';
import 'package:financas/features/transacoes/data/transacao.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/contas_falso.dart';
import '../../apoio/transacoes_falso.dart';

void main() {
  final hoje = DateTime(2026, 10, 20, 14, 30);

  group('TransacoesCubit', () {
    late TransacoesRepositorioFalso transacoes;
    late ContasRepositorioFalso contas;

    setUp(() {
      contas = ContasRepositorioFalso(
        contas: [
          contaExemplo(),
          contaExemplo(id: 'c2', nome: 'Antiga', ativa: false),
        ],
      );
      transacoes = TransacoesRepositorioFalso(
        transacoes: [
          transacaoExemplo(id: 'a', data: DateTime(2026, 10, 20)),
          transacaoExemplo(id: 'b', data: DateTime(2026, 10, 19)),
          transacaoExemplo(id: 'c', data: DateTime(2026, 10, 20)),
          transacaoExemplo(
            id: 'ignorada',
            data: DateTime(2026, 10, 18),
            status: StatusTransacao.ignorada,
          ),
          transacaoExemplo(id: 'setembro', data: DateTime(2026, 9, 6)),
        ],
      );
    });

    TransacoesCubit criar() =>
        TransacoesCubit(transacoes, contas, hoje: () => hoje);

    test('começa no mês atual', () {
      final estado = criar().state;
      expect(estado.mes, DateTime(2026, 10));
      expect(estado.noMesAtual, isTrue);
    });

    test('carrega o mês inteiro, agrupa por dia e esconde ignoradas', () async {
      final cubit = criar();

      await cubit.carregar();

      expect(transacoes.consultas.single.de, DateTime(2026, 10, 1));
      expect(transacoes.consultas.single.ate, DateTime(2026, 10, 31));
      final dias = cubit.state.dias;
      expect(dias.map((d) => d.data), [
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 19),
      ]);
      expect(dias.first.transacoes.map((t) => t.id), ['a', 'c']);
      expect(cubit.state.carregando, isFalse);
      // Só contas ativas viram filtro.
      expect(cubit.state.contas.map((c) => c.id), ['c1']);
    });

    test('mês anterior e próximo, sem passar do mês atual', () async {
      final cubit = criar();

      await cubit.proximoMes();
      expect(cubit.state.mes, DateTime(2026, 10));
      expect(transacoes.consultas, isEmpty);

      await cubit.mesAnterior();
      expect(cubit.state.mes, DateTime(2026, 9));
      expect(transacoes.consultas.last.ate, DateTime(2026, 9, 30));
      expect(cubit.state.dias.single.transacoes.single.id, 'setembro');

      await cubit.proximoMes();
      expect(cubit.state.mes, DateTime(2026, 10));
    });

    test('filtro por conta vai para a API', () async {
      final cubit = criar();

      await cubit.filtrar('c1');

      expect(cubit.state.contaId, 'c1');
      expect(transacoes.consultas.single.contaId, 'c1');
    });

    blocTest<TransacoesCubit, TransacoesEstado>(
      'erro da API aparece no estado',
      build: () {
        transacoes.erro = const ErroApi(ErroApi.semConexao);
        return criar();
      },
      act: (cubit) => cubit.carregar(),
      skip: 1,
      expect: () => [
        isA<TransacoesEstado>()
            .having((e) => e.carregando, 'carregando', isFalse)
            .having(
              (e) => e.erro,
              'erro',
              'Não foi possível falar com o servidor.',
            ),
      ],
    );
  });

  group('LancamentoCubit', () {
    late TransacoesRepositorioFalso transacoes;

    setUp(() => transacoes = TransacoesRepositorioFalso());

    blocTest<LancamentoCubit, LancamentoEstado>(
      'valida conta, valor e descrição no aparelho',
      build: () => LancamentoCubit(transacoes),
      act: (cubit) => cubit.salvar(
        contaId: null,
        valor: '0,00',
        data: hoje,
        descricao: '  ',
      ),
      expect: () => [
        const LancamentoEstado(
          erros: {
            'conta_id': 'Escolha uma conta.',
            'valor': 'Informe um valor maior que zero.',
            'descricao': 'Descreva a transação, por exemplo: Mercado.',
          },
        ),
      ],
      verify: (_) => expect(transacoes.lancados, isEmpty),
    );

    blocTest<LancamentoCubit, LancamentoEstado>(
      'lança receita com valor em Decimal e data sem horário',
      build: () => LancamentoCubit(transacoes),
      act: (cubit) {
        cubit.escolherTipo(TipoTransacao.receita);
        return cubit.salvar(
          contaId: 'c1',
          valor: '1.234,56',
          data: hoje,
          descricao: ' Freela de design ',
        );
      },
      skip: 2,
      expect: () => [
        isA<LancamentoEstado>().having((e) => e.salva, 'salva', isNotNull),
      ],
      verify: (_) {
        final lancado = transacoes.lancados.single;
        expect(lancado.tipo, TipoTransacao.receita);
        expect(lancado.valor, Decimal.parse('1234.56'));
        expect(lancado.data, DateTime(2026, 10, 20));
        expect(lancado.descricao, 'Freela de design');
      },
    );

    blocTest<LancamentoCubit, LancamentoEstado>(
      'conta recusada pela API aparece no campo',
      build: () {
        transacoes.erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {'conta_id': 'Esta conta está desativada.'},
        );
        return LancamentoCubit(transacoes);
      },
      act: (cubit) => cubit.salvar(
        contaId: 'c1',
        valor: '10',
        data: hoje,
        descricao: 'Mercado',
      ),
      expect: () => [
        const LancamentoEstado(enviando: true),
        const LancamentoEstado(
          erros: {'conta_id': 'Esta conta está desativada.'},
        ),
      ],
    );
  });
}
