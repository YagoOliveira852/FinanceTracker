import 'package:bloc_test/bloc_test.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/open_finance/cubit/conexao_cubit.dart';
import 'package:financas/features/open_finance/cubit/open_finance_cubit.dart';
import 'package:financas/features/open_finance/data/open_finance.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/open_finance_falso.dart';

void main() {
  late OpenFinanceRepositorioFalso repositorio;

  setUp(
    () => repositorio = OpenFinanceRepositorioFalso(
      lista: ListaConexoes(conexoes: [conexaoExemplo()]),
    ),
  );

  group('OpenFinanceCubit', () {
    blocTest<OpenFinanceCubit, OpenFinanceEstado>(
      'carrega as conexões',
      build: () => OpenFinanceCubit(repositorio),
      act: (cubit) => cubit.carregar(),
      expect: () => [
        const OpenFinanceEstado.carregando(),
        OpenFinanceEstado.carregado(
          lista: ListaConexoes(conexoes: [conexaoExemplo()]),
        ),
      ],
    );

    blocTest<OpenFinanceCubit, OpenFinanceEstado>(
      'buscar agora marca a conexão ocupada e avisa quantas chegaram',
      build: () => OpenFinanceCubit(repositorio),
      act: (cubit) async {
        await cubit.carregar();
        await cubit.buscarAgora('x1');
      },
      skip: 2,
      expect: () => [
        OpenFinanceEstado.carregado(
          lista: ListaConexoes(conexoes: [conexaoExemplo()]),
          ocupada: 'x1',
        ),
        OpenFinanceEstado.carregado(
          lista: ListaConexoes(conexoes: [conexaoExemplo()]),
          aviso: '3 transações novas na Revisão.',
        ),
      ],
      verify: (_) => expect(repositorio.buscas, ['x1']),
    );

    blocTest<OpenFinanceCubit, OpenFinanceEstado>(
      'erro da busca vira o aviso',
      build: () => OpenFinanceCubit(repositorio),
      act: (cubit) async {
        await cubit.carregar();
        repositorio.resultadoBusca = const ResultadoBusca(
          ok: false,
          erro: 'A Pluggy respondeu com erro (500).',
          novas: 0,
          atualizadas: 0,
        );
        await cubit.buscarAgora('x1');
      },
      skip: 3,
      expect: () => [
        OpenFinanceEstado.carregado(
          lista: ListaConexoes(conexoes: [conexaoExemplo()]),
          aviso: 'A Pluggy respondeu com erro (500).',
        ),
      ],
    );

    blocTest<OpenFinanceCubit, OpenFinanceEstado>(
      'desativar e reativar recarregam a lista',
      build: () => OpenFinanceCubit(repositorio),
      act: (cubit) async {
        await cubit.carregar();
        await cubit.desativar('x1');
        await cubit.reativar('x1');
      },
      verify: (_) => expect(repositorio.alteracoes, [
        (conexaoId: 'x1', ativa: false),
        (conexaoId: 'x1', ativa: true),
      ]),
    );
  });

  group('ConexaoCubit', () {
    blocTest<ConexaoCubit, ConexaoEstado>(
      'verificar traz a prévia com as escolhas padrão',
      build: () => ConexaoCubit(repositorio),
      act: (cubit) => cubit.verificar('  8f3c2a91-5d4e  '),
      expect: () => [
        const ConexaoEstado(verificando: true),
        ConexaoEstado(
          previa: previaExemplo(),
          // Sugestão vira vínculo; sem sugestão, criar nova.
          escolhas: const {
            'conta-1': Escolha.vincular('c1'),
            'cartao-1': Escolha.criar(),
          },
        ),
      ],
      verify: (_) => expect(repositorio.previas.single.itemId, '8f3c2a91-5d4e'),
    );

    blocTest<ConexaoCubit, ConexaoEstado>(
      'ID vazio pede o ID sem chamar a API',
      build: () => ConexaoCubit(repositorio),
      act: (cubit) => cubit.verificar(' '),
      expect: () => [
        const ConexaoEstado(erroItem: 'Cole o ID do item do Meu Pluggy.'),
      ],
    );

    blocTest<ConexaoCubit, ConexaoEstado>(
      'erro do item aparece no campo',
      build: () {
        repositorio.erro = const ErroApi(
          'Dados inválidos.',
          campos: {'item_id': 'Não encontramos uma conexão com esse ID.'},
        );
        return ConexaoCubit(repositorio);
      },
      act: (cubit) => cubit.verificar('nao-existe'),
      skip: 1,
      expect: () => [
        const ConexaoEstado(
          erroItem: 'Não encontramos uma conexão com esse ID.',
        ),
      ],
    );

    blocTest<ConexaoCubit, ConexaoEstado>(
      'cartão que não pode ser criado fica sem escolha e trava o salvar',
      build: () {
        repositorio.previaDevolvida = previaExemplo(cartaoPodeCriar: false);
        return ConexaoCubit(repositorio);
      },
      act: (cubit) async {
        await cubit.verificar('item');
        await cubit.salvar();
      },
      skip: 2,
      expect: () => [
        isA<ConexaoEstado>().having(
          (e) => e.erro,
          'erro',
          'Escolha a conta do app para Cartão Exemplo.',
        ),
      ],
      verify: (_) => expect(repositorio.criadas, isEmpty),
    );

    blocTest<ConexaoCubit, ConexaoEstado>(
      'salvar manda os vínculos escolhidos',
      build: () => ConexaoCubit(repositorio),
      act: (cubit) async {
        await cubit.verificar('item');
        cubit.escolher('conta-1', const Escolha.criar());
        await cubit.salvar();
      },
      verify: (cubit) {
        expect(cubit.state.salvo, isTrue);
        expect(repositorio.criadas.single.vinculos, const [
          Vinculo(pluggyAccountId: 'conta-1'),
          Vinculo(pluggyAccountId: 'cartao-1'),
        ]);
      },
    );

    blocTest<ConexaoCubit, ConexaoEstado>(
      'na renovação, salvar renova a conexão',
      build: () => ConexaoCubit(repositorio, conexaoId: 'x1'),
      act: (cubit) async {
        await cubit.verificar('item-novo');
        await cubit.salvar();
      },
      verify: (_) {
        expect(repositorio.previas.single.conexaoId, 'x1');
        expect(repositorio.renovadas.single.conexaoId, 'x1');
        expect(repositorio.criadas, isEmpty);
      },
    );
  });
}
