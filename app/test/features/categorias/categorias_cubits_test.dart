import 'package:bloc_test/bloc_test.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/categorias/cubit/categorias_cubit.dart';
import 'package:financas/features/categorias/cubit/editar_categoria_cubit.dart';
import 'package:financas/features/categorias/data/categoria.dart';
import 'package:financas/features/transacoes/data/transacao.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/categorias_falso.dart';

void main() {
  group('Categoria', () {
    test('opções de cada tipo: ativas e do grupo que combina', () {
      final categorias = categoriasExemplo();
      List<String> opcoes(TipoTransacao tipo) => [
        for (final c in categorias)
          if (c.opcaoPara(tipo)) c.nome,
      ];

      expect(opcoes(TipoTransacao.despesa), ['Mercado', 'Alimentação']);
      expect(opcoes(TipoTransacao.estorno), ['Mercado', 'Alimentação']);
      expect(opcoes(TipoTransacao.receita), ['Salário']);
      expect(opcoes(TipoTransacao.aporte), ['Investimento']);
      expect(opcoes(TipoTransacao.transferenciaSaida), isEmpty);
      expect(opcoes(TipoTransacao.pagamentoFatura), isEmpty);
    });
  });

  group('CategoriasCubit', () {
    blocTest<CategoriasCubit, CategoriasEstado>(
      'carrega as categorias',
      build: () => CategoriasCubit(CategoriasRepositorioFalso()),
      act: (cubit) => cubit.carregar(),
      expect: () => [
        const CategoriasEstado.carregando(),
        isA<CategoriasCarregado>().having(
          (e) => e.categorias.length,
          'quantidade',
          5,
        ),
      ],
    );

    blocTest<CategoriasCubit, CategoriasEstado>(
      'erro da API vira estado de erro com a mensagem',
      build: () => CategoriasCubit(
        CategoriasRepositorioFalso()..erro = const ErroApi(ErroApi.semConexao),
      ),
      act: (cubit) => cubit.carregar(),
      expect: () => [
        const CategoriasEstado.carregando(),
        const CategoriasEstado.erro(ErroApi.semConexao),
      ],
    );
  });

  group('EditarCategoriaCubit', () {
    late CategoriasRepositorioFalso repositorio;

    setUp(() => repositorio = CategoriasRepositorioFalso());

    blocTest<EditarCategoriaCubit, EditarCategoriaEstado>(
      'valida no aparelho sem chamar a API',
      build: () => EditarCategoriaCubit(repositorio),
      act: (cubit) => cubit.salvar(nome: '  ', grupo: null),
      expect: () => [
        const EditarCategoriaEstado(
          erros: {
            'nome': 'Dê um nome, por exemplo: Pets.',
            'grupo': 'Escolha o grupo.',
          },
        ),
      ],
      verify: (_) => expect(repositorio.criadas, isEmpty),
    );

    blocTest<EditarCategoriaCubit, EditarCategoriaEstado>(
      'nova categoria é criada ativa, com o nome sem espaços nas pontas',
      build: () => EditarCategoriaCubit(repositorio),
      act: (cubit) =>
          cubit.salvar(nome: ' Pets ', grupo: GrupoCategoria.variavel),
      expect: () => [
        const EditarCategoriaEstado(enviando: true),
        isA<EditarCategoriaEstado>().having(
          (e) => e.salva?.nome,
          'salva',
          'Pets',
        ),
      ],
      verify: (_) => expect(repositorio.criadas, [
        const DadosCategoria(nome: 'Pets', grupo: GrupoCategoria.variavel),
      ]),
    );

    blocTest<EditarCategoriaCubit, EditarCategoriaEstado>(
      'editar mantém o ativo; desativar manda nome e grupo atuais',
      build: () => EditarCategoriaCubit(
        repositorio,
        existente: repositorio.categorias.first,
      ),
      act: (cubit) async {
        await cubit.salvar(nome: 'Feira', grupo: GrupoCategoria.variavel);
        await cubit.mudarAtivo(false);
      },
      verify: (_) => expect(repositorio.editadas.map((e) => e.dados), [
        const DadosCategoria(nome: 'Feira', grupo: GrupoCategoria.variavel),
        const DadosCategoria(
          nome: 'Mercado',
          grupo: GrupoCategoria.essencial,
          ativa: false,
        ),
      ]),
    );

    blocTest<EditarCategoriaCubit, EditarCategoriaEstado>(
      'erro de campo da API fica no campo; outro erro vai para o geral',
      build: () => EditarCategoriaCubit(repositorio),
      act: (cubit) async {
        repositorio.erro = const ErroApi(
          'Dados inválidos.',
          campos: {'nome': 'Já existe uma categoria com esse nome.'},
        );
        await cubit.salvar(nome: 'mercado', grupo: GrupoCategoria.essencial);
        repositorio.erro = const ErroApi(ErroApi.semConexao);
        await cubit.salvar(nome: 'Pets', grupo: GrupoCategoria.variavel);
      },
      expect: () => [
        const EditarCategoriaEstado(enviando: true),
        const EditarCategoriaEstado(
          erros: {'nome': 'Já existe uma categoria com esse nome.'},
        ),
        const EditarCategoriaEstado(enviando: true),
        const EditarCategoriaEstado(erroGeral: ErroApi.semConexao),
      ],
    );
  });
}
