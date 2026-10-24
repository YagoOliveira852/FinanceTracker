import 'package:bloc_test/bloc_test.dart';
import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/contas/cubit/nova_conta_cubit.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/contas_falso.dart';

void main() {
  group('ContasCubit', () {
    blocTest<ContasCubit, ContasEstado>(
      'carrega o resumo',
      build: () =>
          ContasCubit(ContasRepositorioFalso(contas: [contaExemplo()])),
      act: (cubit) => cubit.carregar(),
      expect: () => [
        const ContasEstado.carregando(),
        isA<ContasCarregado>().having(
          (e) => e.resumo.totalDisponivel,
          'total',
          Decimal.parse('2350'),
        ),
      ],
    );

    blocTest<ContasCubit, ContasEstado>(
      'erro da API vira estado de erro com a mensagem',
      build: () => ContasCubit(
        ContasRepositorioFalso()..erro = const ErroApi(ErroApi.semConexao),
      ),
      act: (cubit) => cubit.carregar(),
      expect: () => [
        const ContasEstado.carregando(),
        const ContasEstado.erro('Não foi possível falar com o servidor.'),
      ],
    );
  });

  group('NovaContaCubit', () {
    final hoje = DateTime(2026, 10, 20);
    late ContasRepositorioFalso repositorio;

    setUp(() => repositorio = ContasRepositorioFalso());

    NovaContaCubit criar() => NovaContaCubit(repositorio, hoje: () => hoje);

    blocTest<NovaContaCubit, NovaContaEstado>(
      'valida no aparelho sem chamar a API',
      build: criar,
      act: (cubit) => cubit.salvar(
        nome: ' ',
        instituicao: '',
        saldoInicial: '1.234,567',
        dataSaldoInicial: DateTime(2026, 10, 25),
      ),
      expect: () => [
        const NovaContaEstado(
          erros: {
            'nome': 'Dê um nome à conta, por exemplo: Conta principal.',
            'instituicao': 'Informe a instituição da conta.',
            'saldo_inicial':
                'Use no máximo 2 casas decimais, por exemplo: 1.234,56.',
            'data_saldo_inicial':
                'A data do saldo não pode ser depois de hoje.',
          },
        ),
      ],
      verify: (_) => expect(repositorio.criadas, isEmpty),
    );

    blocTest<NovaContaCubit, NovaContaEstado>(
      'carteira não pede instituição e aceita saldo negativo',
      build: criar,
      act: (cubit) {
        cubit.escolherTipo(TipoConta.carteira);
        return cubit.salvar(
          nome: 'Carteira',
          instituicao: 'ignorada',
          saldoInicial: '-10,50',
          dataSaldoInicial: hoje,
        );
      },
      skip: 1,
      expect: () => [
        const NovaContaEstado(tipo: TipoConta.carteira, enviando: true),
        isA<NovaContaEstado>().having(
          (e) => e.salva?.nome,
          'salva',
          'Carteira',
        ),
      ],
      verify: (_) {
        final enviada = repositorio.criadas.single;
        expect(enviada.instituicao, isNull);
        expect(enviada.saldoInicial, Decimal.parse('-10.5'));
      },
    );

    blocTest<NovaContaCubit, NovaContaEstado>(
      'erro do servidor aparece no campo',
      build: () {
        repositorio.erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {
            'data_saldo_inicial':
                'A data do saldo não pode ser depois de hoje.',
          },
        );
        return criar();
      },
      act: (cubit) => cubit.salvar(
        nome: 'Conta principal',
        instituicao: 'Banco Exemplo',
        saldoInicial: '0',
        dataSaldoInicial: hoje,
      ),
      expect: () => [
        const NovaContaEstado(enviando: true),
        const NovaContaEstado(
          erros: {
            'data_saldo_inicial':
                'A data do saldo não pode ser depois de hoje.',
          },
        ),
      ],
    );

    blocTest<NovaContaCubit, NovaContaEstado>(
      'sem rede vira erro geral',
      build: () {
        repositorio.erro = const ErroApi(ErroApi.semConexao);
        return criar();
      },
      act: (cubit) => cubit.salvar(
        nome: 'Conta principal',
        instituicao: 'Banco Exemplo',
        saldoInicial: '0',
        dataSaldoInicial: hoje,
      ),
      expect: () => [
        const NovaContaEstado(enviando: true),
        const NovaContaEstado(
          erroGeral: 'Não foi possível falar com o servidor.',
        ),
      ],
    );
  });

  group('NovaContaCubit · cartão de crédito', () {
    late ContasRepositorioFalso repositorio;

    setUp(() => repositorio = ContasRepositorioFalso());

    NovaContaCubit criar() =>
        NovaContaCubit(repositorio)..escolherTipo(TipoConta.cartaoCredito);

    blocTest<NovaContaCubit, NovaContaEstado>(
      'prévia da próxima fatura com os dois dias válidos',
      build: criar,
      act: (cubit) => cubit.atualizarPrevia('3', '10'),
      expect: () => [
        NovaContaEstado(tipo: TipoConta.cartaoCredito, previa: previaExemplo),
      ],
      verify: (_) =>
          expect(repositorio.previas, [(diaFechamento: 3, diaVencimento: 10)]),
    );

    blocTest<NovaContaCubit, NovaContaEstado>(
      'sem prévia (e sem chamar a API) com dia inválido ou dias iguais',
      build: criar,
      act: (cubit) async {
        await cubit.atualizarPrevia('0', '10');
        await cubit.atualizarPrevia('3', '');
        await cubit.atualizarPrevia('3', '3');
      },
      expect: () => const <NovaContaEstado>[],
      verify: (_) => expect(repositorio.previas, isEmpty),
    );

    blocTest<NovaContaCubit, NovaContaEstado>(
      'valida o cartão no aparelho',
      build: criar,
      act: (cubit) => cubit.salvarCartao(
        nome: ' ',
        instituicao: '',
        contaPagamentoId: null,
        diaFechamento: '32',
        diaVencimento: '32',
        limite: '0',
      ),
      expect: () => [
        const NovaContaEstado(
          tipo: TipoConta.cartaoCredito,
          erros: {
            'nome': 'Dê um nome ao cartão, por exemplo: Cartão principal.',
            'instituicao': 'Informe a instituição do cartão.',
            'conta_pagamento_id': 'Escolha a conta que paga a fatura.',
            'dia_fechamento': 'Informe um dia de 1 a 31.',
            'dia_vencimento': 'Informe um dia de 1 a 31.',
            'limite': 'Informe um valor maior que zero.',
          },
        ),
      ],
      verify: (_) => expect(repositorio.cartoesCriados, isEmpty),
    );

    blocTest<NovaContaCubit, NovaContaEstado>(
      'dias iguais são recusados',
      build: criar,
      act: (cubit) => cubit.salvarCartao(
        nome: 'Cartão Exemplo',
        instituicao: 'Banco Exemplo',
        contaPagamentoId: 'c1',
        diaFechamento: '10',
        diaVencimento: '10',
        limite: '',
      ),
      expect: () => [
        const NovaContaEstado(
          tipo: TipoConta.cartaoCredito,
          erros: {
            'dia_vencimento':
                'O vencimento precisa ser num dia diferente do fechamento.',
          },
        ),
      ],
    );

    blocTest<NovaContaCubit, NovaContaEstado>(
      'salva o cartão com limite opcional',
      build: criar,
      act: (cubit) => cubit.salvarCartao(
        nome: ' Cartão Exemplo ',
        instituicao: 'Banco Exemplo',
        contaPagamentoId: 'c1',
        diaFechamento: '3',
        diaVencimento: '10',
        limite: '3.000,00',
      ),
      skip: 1,
      expect: () => [
        isA<NovaContaEstado>().having(
          (e) => e.salva?.nome,
          'salva',
          'Cartão Exemplo',
        ),
      ],
      verify: (_) => expect(
        repositorio.cartoesCriados.single,
        NovoCartao(
          nome: 'Cartão Exemplo',
          instituicao: 'Banco Exemplo',
          contaPagamentoId: 'c1',
          diaFechamento: 3,
          diaVencimento: 10,
          limite: Decimal.parse('3000'),
        ),
      ),
    );

    blocTest<NovaContaCubit, NovaContaEstado>(
      'erro do servidor na conta de pagamento aparece no campo',
      build: () {
        repositorio.erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {
            'conta_pagamento_id':
                'Escolha uma conta corrente ativa para pagar a fatura.',
          },
        );
        return criar();
      },
      act: (cubit) => cubit.salvarCartao(
        nome: 'Cartão Exemplo',
        instituicao: 'Banco Exemplo',
        contaPagamentoId: 'c1',
        diaFechamento: '3',
        diaVencimento: '10',
        limite: '',
      ),
      skip: 1,
      expect: () => [
        const NovaContaEstado(
          tipo: TipoConta.cartaoCredito,
          erros: {
            'conta_pagamento_id':
                'Escolha uma conta corrente ativa para pagar a fatura.',
          },
        ),
      ],
    );
  });
}
