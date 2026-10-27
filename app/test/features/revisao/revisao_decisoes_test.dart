import 'package:financas/app/tema.dart';
import 'package:financas/features/categorias/cubit/categorias_cubit.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/revisao/cubit/revisao_cubit.dart';
import 'package:financas/features/revisao/data/revisao.dart';
import 'package:financas/features/revisao/data/revisao_repositorio.dart';
import 'package:financas/features/revisao/ui/revisao_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/categorias_falso.dart';
import '../../apoio/contas_falso.dart';
import '../../apoio/revisao_falso.dart';

/// A aba Revisão com uma decisão de cada tipo, as categorias e as contas
/// (Conta principal, Conta do dia a dia e Carteira) carregadas.
Future<RevisaoRepositorioFalso> _abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repositorio = RevisaoRepositorioFalso(revisao: revisaoComDecisoes());
  final contas = ContasRepositorioFalso(
    contas: [
      contaExemplo(),
      contaExemplo(id: 'c2', nome: 'Conta do dia a dia'),
      contaExemplo(id: 'cart', nome: 'Carteira', tipo: TipoConta.carteira),
      cartaoExemplo(),
    ],
  );
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
          BlocProvider(create: (_) => ContasCubit(contas)..carregar()),
        ],
        child: MaterialApp(theme: temaClaro(), home: const RevisaoTela()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repositorio;
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('decisões no topo, com o contador', (tester) async {
    await _abrir(tester);

    expect(find.text('7 para revisar'), findsOneWidget);
    expect(find.text('Precisam de você · 4'), findsOneWidget);
    expect(find.text('Par de transferência?'), findsOneWidget);
    expect(find.text('Conta principal → Conta do dia a dia'), findsOneWidget);
    expect(find.text('Pagamento de fatura?'), findsOneWidget);
    expect(find.text('Sumiu do Open Finance'), findsOneWidget);
  });

  group('duplicata', () {
    testWidgets('ficar com o rascunho', (tester) async {
      final repositorio = await _abrir(tester);

      await _tocar(tester, find.text('Possível duplicata'));
      expect(find.text('Chegou a mesma compra duas vezes?'), findsOneWidget);
      expect(find.text('Mercado do bairro'), findsOneWidget);
      expect(find.text('Mercado do Bairro Ltda'), findsOneWidget);

      await _tocar(
        tester,
        find.widgetWithText(
          RadioListTile<ManterDuplicata>,
          'Mercado do Bairro Ltda',
        ),
      );
      await _tocar(tester, find.widgetWithText(FilledButton, 'Ficar com esta'));

      expect(repositorio.decisoes, ['duplicata d1 rascunho']);
      expect(find.text('Duplicata resolvida.'), findsOneWidget);
      expect(find.text('Possível duplicata'), findsNothing);
      expect(find.text('6 para revisar'), findsOneWidget);
    });

    testWidgets('começa na que já estava', (tester) async {
      final repositorio = await _abrir(tester);

      await _tocar(tester, find.text('Possível duplicata'));
      await _tocar(tester, find.widgetWithText(FilledButton, 'Ficar com esta'));

      expect(repositorio.decisoes, ['duplicata d1 outra']);
    });

    testWidgets('manter as duas', (tester) async {
      final repositorio = await _abrir(tester);

      await _tocar(tester, find.text('Possível duplicata'));
      await _tocar(
        tester,
        find.widgetWithText(OutlinedButton, 'Manter as duas'),
      );

      expect(repositorio.decisoes, ['duplicata d1 asDuas']);
      expect(find.text('As duas ficam.'), findsOneWidget);
    });
  });

  testWidgets('par: ligar com descrição', (tester) async {
    final repositorio = await _abrir(tester);

    await _tocar(tester, find.text('Par de transferência?'));
    expect(
      find.text(
        'Mesmo valor, sentidos opostos, contas diferentes, 1 dia de '
        'diferença.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Descrição (opcional)'),
      'Reserva do mês',
    );
    await _tocar(tester, find.widgetWithText(FilledButton, 'Ligar'));

    expect(repositorio.decisoes, ['ligar p1 p2 Reserva do mês']);
    expect(find.text('Transferência ligada.'), findsOneWidget);
  });

  testWidgets('par: não é par', (tester) async {
    final repositorio = await _abrir(tester);

    await _tocar(tester, find.text('Par de transferência?'));
    await _tocar(tester, find.widgetWithText(OutlinedButton, 'Não é par'));

    expect(repositorio.decisoes, ['recusar p1 p2']);
  });

  testWidgets('pagamento: começa na sugerida e mostra que fica paga', (
    tester,
  ) async {
    final repositorio = await _abrir(tester);

    await _tocar(tester, find.text('Pagamento de fatura?'));

    expect(find.text('Cartão Exemplo · outubro'), findsOneWidget);
    expect(find.text('Paga'), findsOneWidget);
    await _tocar(
      tester,
      find.widgetWithText(FilledButton, 'Confirmar pagamento'),
    );

    expect(repositorio.decisoes, ['pagar f1 k1 10']);
    expect(
      find.text('Pagamento ligado à fatura de Cartão Exemplo.'),
      findsOneWidget,
    );
  });

  testWidgets('pagamento: "É outra coisa" abre a folha comum', (tester) async {
    await _abrir(tester);

    await _tocar(tester, find.text('Pagamento de fatura?'));
    await _tocar(tester, find.widgetWithText(OutlinedButton, 'É outra coisa'));

    expect(find.text('Pagamento de fatura?'), findsOneWidget); // na lista
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Despesa'))
          .selected,
      isTrue,
    );
    expect(find.text('Categoria'), findsOneWidget);
  });

  testWidgets('sumiu: remover', (tester) async {
    final repositorio = await _abrir(tester);

    await _tocar(tester, find.text('Sumiu do Open Finance'));
    expect(find.text('Esta transação não veio mais do banco'), findsOneWidget);
    await _tocar(tester, find.widgetWithText(FilledButton, 'Remover'));

    expect(repositorio.decisoes, ['remover s1']);
    expect(find.text('Farmácia Exemplo removida.'), findsOneWidget);
  });

  testWidgets('rascunho marcado como transferência para a carteira', (
    tester,
  ) async {
    final repositorio = await _abrir(tester);

    await _tocar(tester, find.text('Padaria Pão Quente'));
    await _tocar(
      tester,
      find.widgetWithText(FilterChip, 'Transferência entre contas próprias'),
    );
    expect(find.text('Categoria'), findsNothing);
    final confirmar = find.widgetWithText(FilledButton, 'Confirmar');
    expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);

    await _tocar(
      tester,
      find.widgetWithText(DropdownButtonFormField<String>, 'Para'),
    );
    await _tocar(tester, find.text('Carteira').last);
    expect(
      find.textContaining('o app cria a entrada de R\$ 18,50'),
      findsOneWidget,
    );
    await _tocar(tester, confirmar);

    expect(repositorio.decisoes, ['transferir i1 cart Padaria Pão Quente']);
    expect(
      find.text('Padaria Pão Quente ligada como transferência.'),
      findsOneWidget,
    );
  });
}
