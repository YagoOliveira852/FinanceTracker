import 'package:financas/app/tema.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/categorias/cubit/editar_categoria_cubit.dart';
import 'package:financas/features/categorias/cubit/editar_regra_cubit.dart';
import 'package:financas/features/categorias/cubit/regras_cubit.dart';
import 'package:financas/features/categorias/data/categoria.dart';
import 'package:financas/features/categorias/data/regra.dart';
import 'package:financas/features/categorias/ui/categorias_regras_tela.dart';
import 'package:financas/features/categorias/ui/editar_categoria_tela.dart';
import 'package:financas/features/categorias/ui/editar_regra_tela.dart';
import 'package:financas/features/categorias/ui/textos.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../apoio/categorias_falso.dart';
import '../../apoio/contas_falso.dart';

/// Categorias e regras com as rotas de Nova e Editar categoria e regra, como
/// no app (as contas do topo do app aparecem no campo Conta da regra).
Future<void> _abrir(
  WidgetTester tester,
  CategoriasRepositorioFalso repositorio,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/mais/categorias',
    routes: [
      GoRoute(
        path: '/mais/categorias',
        builder: (_, _) => BlocProvider(
          create: (_) => RegrasCubit(repositorio)..carregar(),
          child: const CategoriasRegrasTela(),
        ),
        routes: [
          GoRoute(
            path: 'regras/nova',
            builder: (_, _) => BlocProvider(
              create: (_) => EditarRegraCubit(repositorio),
              child: const EditarRegraTela(),
            ),
          ),
          GoRoute(
            path: 'regras/:id/editar',
            builder: (_, state) => BlocProvider(
              create: (_) => EditarRegraCubit(
                repositorio,
                existente: state.extra! as Regra,
              )..carregar(),
              child: const EditarRegraTela(),
            ),
          ),
          GoRoute(
            path: 'nova',
            builder: (_, _) => BlocProvider(
              create: (_) => EditarCategoriaCubit(repositorio),
              child: const EditarCategoriaTela(),
            ),
          ),
          GoRoute(
            path: ':id/editar',
            builder: (_, state) => BlocProvider(
              create: (_) => EditarCategoriaCubit(
                repositorio,
                existente: state.extra! as Categoria,
              ),
              child: const EditarCategoriaTela(),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider(
      create: (_) => ContasCubit(
        ContasRepositorioFalso(
          contas: [
            contaExemplo(),
            cartaoExemplo(),
            contaExemplo(id: 'c9', nome: 'Conta antiga', ativa: false),
          ],
        ),
      )..carregar(),
      child: comCategorias(
        MaterialApp.router(theme: temaClaro(), routerConfig: router),
        repositorio: repositorio,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('textos', () {
    test('regras na linha da categoria', () {
      expect(textoDasRegras(0), '—');
      expect(textoDasRegras(1), '1 regra');
      expect(textoDasRegras(4), '4 regras');
    });

    test('uso no Editar categoria', () {
      expect(
        textoDoUso(regras: 0, transacoes: 0),
        'Nenhuma regra nem transação usa esta categoria.',
      );
      expect(
        textoDoUso(regras: 1, transacoes: 0),
        '1 regra usa esta categoria.',
      );
      expect(
        textoDoUso(regras: 0, transacoes: 42),
        '42 transações usam esta categoria.',
      );
      expect(
        textoDoUso(regras: 3, transacoes: 1),
        '3 regras e 1 transação usam esta categoria.',
      );
    });
  });

  testWidgets('lista por grupo, com regras e a desativada', (tester) async {
    await _abrir(tester, CategoriasRepositorioFalso());

    expect(find.text('Essencial'), findsOneWidget);
    expect(find.text('Variável'), findsOneWidget);
    expect(find.text('Renda'), findsOneWidget);
    expect(find.text('Investimento'), findsNWidgets(2)); // grupo e categoria
    expect(find.text('4 regras'), findsOneWidget);
    expect(find.text('1 regra'), findsOneWidget);
    expect(find.text('Desativada'), findsOneWidget);
    expect(find.text('Nova categoria'), findsOneWidget);

    await tester.tap(find.text('Regras'));
    await tester.pumpAndSettle();
    expect(find.text('Nova categoria'), findsNothing);
    expect(find.text('Nova regra'), findsOneWidget);
  });

  testWidgets('nova categoria: valida, salva e volta à lista com ela', (
    tester,
  ) async {
    final repositorio = CategoriasRepositorioFalso();
    await _abrir(tester, repositorio);

    await tester.tap(find.text('Nova categoria'));
    await tester.pumpAndSettle();
    expect(find.text('Desativar categoria'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();
    expect(find.text('Dê um nome, por exemplo: Pets.'), findsOneWidget);
    expect(find.text('Escolha o grupo.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Pets');
    await tester.tap(find.widgetWithText(FilterChip, 'Variável'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(repositorio.criadas.single.grupo, GrupoCategoria.variavel);
    expect(find.text('Categorias e regras'), findsOneWidget);
    expect(find.text('Pets'), findsOneWidget);
  });

  testWidgets('editar: uso, troca de grupo e erro da API no campo', (
    tester,
  ) async {
    final repositorio = CategoriasRepositorioFalso();
    await _abrir(tester, repositorio);

    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();
    expect(
      find.text('4 regras e 12 transações usam esta categoria.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Essencial'))
          .selected,
      isTrue,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Renda'));
    await tester.pump();
    repositorio.erro = const ErroApi(
      'Dados inválidos.',
      campos: {
        'grupo':
            'Esta categoria já tem transações; troque o grupo só entre '
            'essencial e variável.',
      },
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Esta categoria já tem transações'), findsOne);
    expect(find.text('Editar categoria'), findsOneWidget);
  });

  testWidgets('desativar e reativar', (tester) async {
    final repositorio = CategoriasRepositorioFalso();
    await _abrir(tester, repositorio);

    await tester.tap(find.text('Alimentação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desativar categoria'));
    await tester.pumpAndSettle();

    expect(repositorio.editadas.single.dados.ativa, isFalse);
    expect(find.text('Desativada'), findsNWidgets(2));

    await tester.tap(find.text('Educação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reativar categoria'));
    await tester.pumpAndSettle();

    expect(repositorio.editadas.last.dados.ativa, isTrue);
    expect(find.text('Desativada'), findsOneWidget);
  });

  group('textos das regras', () {
    test('uso na linha da aprendida', () {
      expect(textoDoUsoDaRegra(0), 'Ainda não usada');
      expect(textoDoUsoDaRegra(1), 'Usada 1 vez');
      expect(textoDoUsoDaRegra(8), 'Usada 8 vezes');
    });

    test('rascunhos no Editar regra e no aviso de salvar', () {
      expect(textoDosRascunhos(0), 'Não casa com nenhum rascunho agora.');
      expect(
        textoDosRascunhos(1, exemplo: 'Padaria Pão Quente, 25 out'),
        'Casa com 1 rascunho agora: Padaria Pão Quente, 25 out.',
      );
      expect(
        textoDosRascunhos(3, exemplo: 'Padaria Pão Quente, 25 out'),
        'Casa com 3 rascunhos agora; o mais recente: Padaria Pão Quente, '
        '25 out.',
      );
      expect(
        textoRegraSalva(0),
        'Regra salva; não casa com nenhum rascunho agora.',
      );
      expect(textoRegraSalva(2), 'Regra salva; sugere 2 rascunhos agora.');
    });
  });

  Future<void> abrirRegras(
    WidgetTester tester,
    CategoriasRepositorioFalso repositorio,
  ) async {
    await _abrir(tester, repositorio);
    await tester.tap(find.text('Regras'));
    await tester.pumpAndSettle();
  }

  testWidgets('regras: manuais e aprendidas, com conta e uso', (tester) async {
    await abrirRegras(tester, CategoriasRepositorioFalso());

    expect(find.text('Manuais'), findsOneWidget);
    expect(find.text('Aprendidas na revisão'), findsOneWidget);
    expect(find.text('“posto”'), findsOneWidget);
    expect(find.text('Só Cartão Exemplo'), findsOneWidget);
    expect(find.text('Todas as contas'), findsOneWidget);
    expect(find.text('“padaria pao quente”'), findsOneWidget);
    expect(find.text('Usada 3 vezes'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Manuais')).dy,
      lessThan(tester.getTopLeft(find.text('Aprendidas na revisão')).dy),
    );
  });

  testWidgets('regras: sem nenhuma, explica de onde elas vêm', (tester) async {
    await abrirRegras(tester, CategoriasRepositorioFalso(regras: []));

    expect(find.text('Nenhuma regra ainda'), findsOneWidget);
    expect(find.text('Nova regra'), findsOneWidget);
  });

  testWidgets('editar aprendida: rascunhos, origem e salvar avisa na lista', (
    tester,
  ) async {
    final repositorio = CategoriasRepositorioFalso();
    await abrirRegras(tester, repositorio);

    await tester.tap(find.text('“padaria pao quente”'));
    await tester.pumpAndSettle();
    expect(find.text('Editar regra'), findsOneWidget);
    expect(
      find.text('Casa com 1 rascunho agora: Padaria Pão Quente, 25 out.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Aprendida na revisão em 12 out, usada 3 vezes. Salvar uma mudança '
        'a torna manual.',
      ),
      findsOneWidget,
    );
    // A conta desativada não é opção.
    await tester.tap(find.text('Todas as contas'));
    await tester.pumpAndSettle();
    expect(find.text('Conta antiga'), findsNothing);
    await tester.tap(find.text('Cartão Exemplo').last);
    await tester.pumpAndSettle();

    repositorio.rascunhos = 2;
    await tester.enterText(find.widgetWithText(TextField, 'Padrão'), 'padaria');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(
      repositorio.regrasEditadas.single.dados,
      const DadosRegra(
        padrao: 'padaria',
        categoriaId: 'cat-alimentacao',
        contaId: 'k1',
      ),
    );
    expect(find.text('Regra salva; sugere 2 rascunhos agora.'), findsOneWidget);
    expect(find.text('“padaria”'), findsOneWidget);
  });

  testWidgets('nova regra: valida e cria', (tester) async {
    final repositorio = CategoriasRepositorioFalso();
    await abrirRegras(tester, repositorio);

    await tester.tap(find.text('Nova regra'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();
    expect(
      find.text('Escreva o que procurar, por exemplo: padaria.'),
      findsOneWidget,
    );
    expect(find.text('Escolha a categoria.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Padrão'), 'Cinema');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    // Educação está desativada: fora das opções.
    expect(find.text('Educação'), findsNothing);
    await tester.tap(find.text('Alimentação').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(
      repositorio.regrasCriadas.single,
      const DadosRegra(padrao: 'Cinema', categoriaId: 'cat-alimentacao'),
    );
    expect(find.text('Regra salva; sugere 1 rascunho agora.'), findsOneWidget);
  });

  testWidgets('excluir pede confirmação', (tester) async {
    final repositorio = CategoriasRepositorioFalso();
    await abrirRegras(tester, repositorio);

    await tester.tap(find.text('“posto”'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repositorio.regrasExcluidas, isEmpty);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(repositorio.regrasExcluidas, ['r-posto']);
    expect(find.text('Regra excluída.'), findsOneWidget);
    expect(find.text('“posto”'), findsNothing);
  });
}
