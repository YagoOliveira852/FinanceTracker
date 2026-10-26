import 'package:financas/app/tema.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/categorias/cubit/editar_categoria_cubit.dart';
import 'package:financas/features/categorias/data/categoria.dart';
import 'package:financas/features/categorias/ui/categorias_regras_tela.dart';
import 'package:financas/features/categorias/ui/editar_categoria_tela.dart';
import 'package:financas/features/categorias/ui/textos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../apoio/categorias_falso.dart';

/// Categorias e regras com as rotas de Nova e Editar categoria, como no app.
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
        builder: (_, _) => const CategoriasRegrasTela(),
        routes: [
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
    comCategorias(
      MaterialApp.router(theme: temaClaro(), routerConfig: router),
      repositorio: repositorio,
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
    expect(find.text('Regras em breve'), findsOneWidget);
    expect(find.text('Nova categoria'), findsNothing);
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
}
