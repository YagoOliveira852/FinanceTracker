import 'package:financas/app/tema.dart';
import 'package:financas/features/categorias/cubit/categorias_cubit.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/revisao/cubit/revisao_cubit.dart';
import 'package:financas/features/revisao/data/revisao_repositorio.dart';
import 'package:financas/features/revisao/ui/revisao_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/categorias_falso.dart';
import '../../apoio/contas_falso.dart';
import '../../apoio/revisao_falso.dart';

/// A aba Revisão com os cubits do topo do app ("hoje" = 26/10/2026).
Future<void> _abrir(
  WidgetTester tester,
  RevisaoRepositorioFalso repositorio,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepositoryProvider<RevisaoRepositorio>.value(
      value: repositorio,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                RevisaoCubit(repositorio, hoje: () => DateTime(2026, 10, 26))
                  ..carregar(),
          ),
          BlocProvider(
            create: (_) =>
                CategoriasCubit(CategoriasRepositorioFalso())..carregar(),
          ),
          BlocProvider(create: (_) => ContasCubit(ContasRepositorioFalso())),
        ],
        child: MaterialApp(theme: temaClaro(), home: const RevisaoTela()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('vazio: "Nada para revisar" com o atalho para importar', (
    tester,
  ) async {
    await _abrir(
      tester,
      RevisaoRepositorioFalso(revisao: revisaoCom(rascunhos: [])),
    );

    expect(find.text('Nada para revisar'), findsOneWidget);
    expect(find.text('Tudo o que chegou está confirmado.'), findsOneWidget);
    final importar = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Importar extrato'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(importar.onPressed, isNotNull);
    expect(find.byTooltip('Importar extrato'), findsOneWidget);
    expect(find.text('Em breve'), findsNothing);
    expect(find.textContaining(RegExp(r'^\d+ para revisar$')), findsNothing);
  });

  testWidgets('lista: contador, lote, dias, sugestão e sem categoria', (
    tester,
  ) async {
    await _abrir(
      tester,
      RevisaoRepositorioFalso(
        revisao: revisaoCom(duplicatas: [duplicataExemplo()]),
      ),
    );

    expect(find.text('4 para revisar'), findsOneWidget);
    expect(find.text('2 rascunhos com categoria sugerida'), findsOneWidget);
    expect(find.text('Precisam de você · 1'), findsOneWidget);
    expect(find.text('Possível duplicata'), findsOneWidget);
    expect(find.text('Ontem · 25 out'), findsOneWidget);
    expect(find.text('Sáb · 24 out'), findsOneWidget);
    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.text('Sem categoria'), findsOneWidget);
    expect(find.text('Extrato OFX · Cartão Exemplo'), findsOneWidget);
    expect(find.text('− R\$ 150,00'), findsOneWidget);
  });

  testWidgets('confirmar em lote confirma os sugeridos e avisa', (
    tester,
  ) async {
    final repositorio = RevisaoRepositorioFalso();
    await _abrir(tester, repositorio);

    await _tocar(tester, find.text('Confirmar 2'));

    expect(repositorio.lotes.single, ['i1', 'i2']);
    expect(find.text('2 rascunhos confirmados.'), findsOneWidget);
    expect(find.text('Confirmar 2'), findsNothing);
    expect(find.text('Padaria Pão Quente'), findsNothing);
    expect(find.text('Posto Fictício'), findsOneWidget);
    expect(find.text('1 para revisar'), findsOneWidget);
  });

  testWidgets('o ✓ da linha confirma com a sugestão', (tester) async {
    final repositorio = RevisaoRepositorioFalso();
    await _abrir(tester, repositorio);

    await _tocar(
      tester,
      find.byTooltip('Confirmar Padaria Pão Quente como Alimentação'),
    );

    expect(repositorio.confirmados.single.categoriaId, 'cat-alimentacao');
    expect(
      find.text('Padaria Pão Quente confirmada como Alimentação.'),
      findsOneWidget,
    );
  });

  testWidgets('folha sem categoria: escolhe, mostra a regra e confirma', (
    tester,
  ) async {
    final repositorio = RevisaoRepositorioFalso();
    await _abrir(tester, repositorio);

    await _tocar(tester, find.text('Posto Fictício'));

    expect(find.text('Como veio do banco'), findsOneWidget);
    expect(find.text('POSTO FICTICIO 0193 FORTALEZA BR'), findsOneWidget);
    expect(find.textContaining('entra na fatura de novembro'), findsOneWidget);
    final confirmar = find.widgetWithText(FilledButton, 'Confirmar');
    expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);

    await _tocar(tester, find.widgetWithText(FilterChip, 'Mercado'));

    expect(
      find.text(
        'Próximas de “posto ficticio fortaleza br” vão sugerir Mercado.',
      ),
      findsOneWidget,
    );
    await _tocar(tester, confirmar);

    final confirmado = repositorio.confirmados.single;
    expect(confirmado.id, 'i3');
    expect(confirmado.categoriaId, 'cat-mercado');
    expect(find.text('Como veio do banco'), findsNothing);
    expect(find.text('Posto Fictício confirmada.'), findsOneWidget);
  });

  testWidgets('folha: corrigir sugestão de regra manual avisa que ela fica', (
    tester,
  ) async {
    await _abrir(tester, RevisaoRepositorioFalso());

    await _tocar(tester, find.text('Lanchonete Exemplo'));
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Mercado'))
          .selected,
      isTrue,
    );
    expect(find.text('Sugerida pela regra de “lanchonete”.'), findsOneWidget);

    await _tocar(tester, find.widgetWithText(FilterChip, 'Alimentação'));

    expect(
      find.text(
        'A regra manual de “lanchonete” continua sugerindo Mercado. Para '
        'mudá-la, use Categorias e regras.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('folha: ignorar tira o rascunho da lista', (tester) async {
    final repositorio = RevisaoRepositorioFalso();
    await _abrir(tester, repositorio);

    await _tocar(tester, find.text('Posto Fictício'));
    await _tocar(tester, find.widgetWithText(OutlinedButton, 'Ignorar'));

    expect(repositorio.ignorados, ['i3']);
    expect(find.text('Posto Fictício ignorada.'), findsOneWidget);
    expect(find.text('Sem categoria'), findsNothing);
  });
}
