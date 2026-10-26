import 'package:bloc_test/bloc_test.dart';
import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/transacoes/cubit/lancamento_cubit.dart';
import 'package:financas/features/transacoes/cubit/transacoes_cubit.dart';
import 'package:financas/features/transacoes/cubit/transferencia_cubit.dart';
import 'package:financas/features/transacoes/data/transacao.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/contas_falso.dart';
import '../../apoio/faturas_falso.dart';
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
      // Todas ficam no estado (nomes); a tela usa só as ativas nos filtros.
      expect(cubit.state.contas.map((c) => c.id), ['c1', 'c2']);
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

    test('"hoje" é relido: a aba aberta desde o mês passado avança', () async {
      var agora = DateTime(2026, 10, 31, 23);
      final cubit = TransacoesCubit(transacoes, contas, hoje: () => agora);
      await cubit.carregar();
      expect(cubit.state.noMesAtual, isTrue);

      agora = DateTime(2026, 11, 1, 8);
      await cubit.proximoMes();

      expect(cubit.state.mes, DateTime(2026, 11));
      expect(cubit.state.hoje, DateTime(2026, 11, 1));
      expect(cubit.state.noMesAtual, isTrue);
    });

    group('transferência', () {
      const par = ParTransferencia(
        parId: 'x',
        contaOrigemId: 'c1',
        contaDestinoId: 'c3',
      );
      setUp(() {
        transacoes.transacoes.addAll([
          transacaoExemplo(
            id: 'saida',
            tipo: TipoTransacao.transferenciaSaida,
            data: DateTime(2026, 10, 19),
            transferencia: par.copyWith(parId: 'entrada'),
          ),
          transacaoExemplo(
            id: 'entrada',
            contaId: 'c3',
            tipo: TipoTransacao.transferenciaEntrada,
            data: DateTime(2026, 10, 19),
            transferencia: par.copyWith(parId: 'saida'),
          ),
        ]);
      });

      List<String> ids(TransacoesEstado estado) => [
        for (final dia in estado.dias)
          for (final t in dia.transacoes) t.id,
      ];

      test('"Todas" mostra o par uma vez, pelo lado da saída', () async {
        final cubit = criar();

        await cubit.carregar();

        expect(ids(cubit.state), contains('saida'));
        expect(ids(cubit.state), isNot(contains('entrada')));
      });

      test('filtrando o destino, aparece o lado da entrada', () async {
        final cubit = criar();

        await cubit.filtrar('c3');

        expect(ids(cubit.state), ['entrada']);
      });
    });

    test('guarda também as contas desativadas, para os nomes', () async {
      final cubit = criar();

      await cubit.carregar();

      expect(cubit.state.nomeDaConta('c2'), 'Antiga');
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
      build: () => LancamentoCubit(transacoes, FaturasRepositorioFalso()),
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
      build: () => LancamentoCubit(transacoes, FaturasRepositorioFalso()),
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
        return LancamentoCubit(transacoes, FaturasRepositorioFalso());
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

  group('LancamentoCubit · compra parcelada', () {
    late TransacoesRepositorioFalso transacoes;

    setUp(() => transacoes = TransacoesRepositorioFalso());

    blocTest<LancamentoCubit, LancamentoEstado>(
      'com 2x ou mais lança a compra parcelada',
      build: () => LancamentoCubit(transacoes, FaturasRepositorioFalso()),
      act: (cubit) => cubit.salvar(
        contaId: 'cartao',
        valor: '1.000,00',
        data: hoje,
        descricao: ' Fone de ouvido ',
        parcelas: 3,
      ),
      skip: 1,
      expect: () => [
        isA<LancamentoEstado>().having(
          (e) => e.salva?.parcela,
          'parcela',
          const Parcela(numero: 1, total: 3),
        ),
      ],
      verify: (_) {
        expect(transacoes.lancados, isEmpty);
        expect(
          transacoes.parceladas.single,
          NovaCompraParcelada(
            contaId: 'cartao',
            valorTotal: Decimal.parse('1000'),
            qtdParcelas: 3,
            dataCompra: DateTime(2026, 10, 20),
            descricao: 'Fone de ouvido',
          ),
        );
      },
    );

    blocTest<LancamentoCubit, LancamentoEstado>(
      'à vista continua sendo o lançamento comum',
      build: () => LancamentoCubit(transacoes, FaturasRepositorioFalso()),
      act: (cubit) => cubit.salvar(
        contaId: 'cartao',
        valor: '50',
        data: hoje,
        descricao: 'Mercado',
        parcelas: 1,
      ),
      verify: (_) {
        expect(transacoes.lancados, hasLength(1));
        expect(transacoes.parceladas, isEmpty);
      },
    );

    blocTest<LancamentoCubit, LancamentoEstado>(
      'erros da API da parcelada aparecem nos campos do formulário',
      build: () {
        transacoes.erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {
            'valor_total': 'Cada parcela precisa ser de pelo menos R\$ 0,01.',
            'data_compra': 'Deve ser uma data no formato AAAA-MM-DD.',
            'qtd_parcelas': 'Escolha de 2 a 24 parcelas.',
          },
        );
        return LancamentoCubit(transacoes, FaturasRepositorioFalso());
      },
      act: (cubit) => cubit.salvar(
        contaId: 'cartao',
        valor: '0,02',
        data: hoje,
        descricao: 'Fone de ouvido',
        parcelas: 3,
      ),
      expect: () => [
        const LancamentoEstado(enviando: true),
        const LancamentoEstado(
          erros: {
            'valor': 'Cada parcela precisa ser de pelo menos R\$ 0,01.',
            'data': 'Deve ser uma data no formato AAAA-MM-DD.',
            'parcelas': 'Escolha de 2 a 24 parcelas.',
          },
        ),
      ],
    );
  });

  group('LancamentoCubit · fatura da compra', () {
    late FaturasRepositorioFalso faturas;

    setUp(() => faturas = FaturasRepositorioFalso());

    LancamentoCubit criar() =>
        LancamentoCubit(TransacoesRepositorioFalso(), faturas);

    blocTest<LancamentoCubit, LancamentoEstado>(
      'no cartão, consulta a fatura da data',
      build: criar,
      act: (cubit) =>
          cubit.consultarFatura(cartaoExemplo(), DateTime(2026, 10, 4)),
      expect: () => [
        isA<LancamentoEstado>().having(
          (e) => e.faturaDaCompra?.competencia,
          'competência',
          DateTime(2026, 10),
        ),
      ],
    );

    blocTest<LancamentoCubit, LancamentoEstado>(
      'mesma conta e data não consultam de novo',
      build: criar,
      act: (cubit) async {
        await cubit.consultarFatura(cartaoExemplo(), DateTime(2026, 10, 20));
        await cubit.consultarFatura(cartaoExemplo(), DateTime(2026, 10, 20));
      },
      expect: () => [isA<LancamentoEstado>()],
      verify: (_) => expect(faturas.consultasParaCompra, hasLength(1)),
    );

    blocTest<LancamentoCubit, LancamentoEstado>(
      'conta comum limpa a fatura sem consultar',
      build: criar,
      act: (cubit) async {
        await cubit.consultarFatura(cartaoExemplo(), DateTime(2026, 10, 20));
        await cubit.consultarFatura(contaExemplo(), DateTime(2026, 10, 20));
      },
      expect: () => [
        isA<LancamentoEstado>().having(
          (e) => e.faturaDaCompra,
          'fatura',
          isNotNull,
        ),
        isA<LancamentoEstado>().having(
          (e) => e.faturaDaCompra,
          'fatura',
          isNull,
        ),
      ],
      verify: (_) => expect(faturas.consultasParaCompra, hasLength(1)),
    );
  });

  group('TransferenciaCubit', () {
    late TransacoesRepositorioFalso transacoes;

    setUp(() => transacoes = TransacoesRepositorioFalso());

    blocTest<TransferenciaCubit, TransferenciaEstado>(
      'valida origem, destino e valor no aparelho',
      build: () => TransferenciaCubit(transacoes),
      act: (cubit) => cubit.salvar(
        origemId: null,
        destinoId: null,
        valor: '0,00',
        data: hoje,
        descricao: '',
      ),
      expect: () => [
        const TransferenciaEstado(
          erros: {
            'origem': 'Escolha a conta de origem.',
            'destino': 'Escolha a conta de destino.',
            'valor': 'Informe um valor maior que zero.',
          },
        ),
      ],
      verify: (_) => expect(transacoes.transferencias, isEmpty),
    );

    blocTest<TransferenciaCubit, TransferenciaEstado>(
      'transfere com Decimal, data sem horário e descrição em branco nula',
      build: () => TransferenciaCubit(transacoes),
      act: (cubit) => cubit.salvar(
        origemId: 'c1',
        destinoId: 'c3',
        valor: '200,00',
        data: hoje,
        descricao: '   ',
      ),
      skip: 1,
      expect: () => [
        isA<TransferenciaEstado>().having((e) => e.salva, 'salva', isNotNull),
      ],
      verify: (_) {
        final enviada = transacoes.transferencias.single;
        expect(enviada.contaOrigemId, 'c1');
        expect(enviada.contaDestinoId, 'c3');
        expect(enviada.valor, Decimal.parse('200'));
        expect(enviada.data, DateTime(2026, 10, 20));
        expect(enviada.descricao, isNull);
      },
    );

    blocTest<TransferenciaCubit, TransferenciaEstado>(
      'conta recusada pela API aparece no campo dela',
      build: () {
        transacoes.erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {
            'conta_destino_id': 'Escolha uma conta diferente da de origem.',
          },
        );
        return TransferenciaCubit(transacoes);
      },
      act: (cubit) => cubit.salvar(
        origemId: 'c1',
        destinoId: 'c1',
        valor: '10',
        data: hoje,
        descricao: 'Saque',
      ),
      expect: () => [
        const TransferenciaEstado(enviando: true),
        const TransferenciaEstado(
          erros: {'destino': 'Escolha uma conta diferente da de origem.'},
        ),
      ],
    );
  });
}
