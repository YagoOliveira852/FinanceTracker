import 'package:bloc_test/bloc_test.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/categorias/cubit/categorias_cubit.dart';
import 'package:financas/features/categorias/cubit/editar_categoria_cubit.dart';
import 'package:financas/features/categorias/cubit/editar_regra_cubit.dart';
import 'package:financas/features/categorias/cubit/regras_cubit.dart';
import 'package:financas/features/categorias/data/categoria.dart';
import 'package:financas/features/categorias/data/regra.dart';
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

  group('RegrasCubit', () {
    blocTest<RegrasCubit, RegrasEstado>(
      'carrega as regras',
      build: () => RegrasCubit(CategoriasRepositorioFalso()),
      act: (cubit) => cubit.carregar(),
      expect: () => [
        const RegrasEstado.carregando(),
        isA<RegrasCarregado>().having((e) => e.regras.length, 'quantidade', 3),
      ],
    );
  });

  group('EditarRegraCubit', () {
    late CategoriasRepositorioFalso repositorio;

    setUp(() => repositorio = CategoriasRepositorioFalso());

    blocTest<EditarRegraCubit, EditarRegraEstado>(
      'regra existente carrega os rascunhos que ela sugere',
      build: () =>
          EditarRegraCubit(repositorio, existente: repositorio.regras.last),
      act: (cubit) => cubit.carregar(),
      expect: () => [
        isA<EditarRegraEstado>().having(
          (e) => e.detalhe?.rascunhos,
          'rascunhos',
          1,
        ),
      ],
    );

    blocTest<EditarRegraCubit, EditarRegraEstado>(
      'falha ao contar os rascunhos não trava o formulário',
      build: () => EditarRegraCubit(
        repositorio..erro = const ErroApi(ErroApi.semConexao),
        existente: repositorio.regras.last,
      ),
      act: (cubit) => cubit.carregar(),
      expect: () => [const EditarRegraEstado(erroDetalhe: ErroApi.semConexao)],
    );

    blocTest<EditarRegraCubit, EditarRegraEstado>(
      'valida padrão e categoria sem chamar a API',
      build: () => EditarRegraCubit(repositorio),
      act: (cubit) =>
          cubit.salvar(padrao: ' ', categoriaId: null, contaId: null),
      expect: () => [
        const EditarRegraEstado(
          erros: {
            'padrao': 'Escreva o que procurar, por exemplo: padaria.',
            'categoria_id': 'Escolha a categoria.',
          },
        ),
      ],
      verify: (_) => expect(repositorio.regrasCriadas, isEmpty),
    );

    blocTest<EditarRegraCubit, EditarRegraEstado>(
      'editar manda os campos; padrão repetido volta no campo',
      build: () =>
          EditarRegraCubit(repositorio, existente: repositorio.regras.last),
      act: (cubit) async {
        repositorio.erro = const ErroApi(
          'Dados inválidos.',
          campos: {'padrao': 'Já existe uma regra com esse padrão.'},
        );
        await cubit.salvar(
          padrao: 'posto',
          categoriaId: 'cat-mercado',
          contaId: 'k1',
        );
        repositorio.erro = null;
        await cubit.salvar(
          padrao: ' padaria ',
          categoriaId: 'cat-alimentacao',
          contaId: null,
        );
      },
      expect: () => [
        const EditarRegraEstado(enviando: true),
        const EditarRegraEstado(
          erros: {'padrao': 'Já existe uma regra com esse padrão.'},
        ),
        const EditarRegraEstado(enviando: true),
        isA<EditarRegraEstado>().having(
          (e) => e.salva?.regra.origem,
          'origem',
          OrigemRegra.manual,
        ),
      ],
      verify: (_) => expect(
        repositorio.regrasEditadas.single.dados,
        const DadosRegra(padrao: 'padaria', categoriaId: 'cat-alimentacao'),
      ),
    );

    blocTest<EditarRegraCubit, EditarRegraEstado>(
      'excluir',
      build: () =>
          EditarRegraCubit(repositorio, existente: repositorio.regras.first),
      act: (cubit) => cubit.excluir(),
      expect: () => [
        const EditarRegraEstado(enviando: true),
        const EditarRegraEstado(excluida: true),
      ],
      verify: (_) => expect(repositorio.regrasExcluidas, ['r-posto']),
    );
  });
}
