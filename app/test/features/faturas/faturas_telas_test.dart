import 'package:financas/app/tema.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/faturas/cubit/fatura_cubit.dart';
import 'package:financas/features/faturas/cubit/faturas_cubit.dart';
import 'package:financas/features/faturas/ui/fatura_tela.dart';
import 'package:financas/features/faturas/ui/faturas_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/contas_falso.dart';
import '../../apoio/faturas_falso.dart';

Widget _app(Widget tela) => MaterialApp(
  theme: temaClaro(),
  home: MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => ContasCubit(
          ContasRepositorioFalso(contas: [contaExemplo(), cartaoExemplo()]),
        )..carregar(),
      ),
    ],
    child: tela,
  ),
);

void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Faturas do cartão: próximas, atual e anteriores', (
    tester,
  ) async {
    _telaAlta(tester);
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) =>
              FaturasCubit(FaturasRepositorioFalso(), 'k1')..carregar(),
          child: const FaturasTela(contaId: 'k1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cartão Exemplo'), findsOneWidget);
    expect(
      find.text(
        'Banco Exemplo · fecha dia 3 · vence dia 10 · limite R\$ 3.000,00',
      ),
      findsOneWidget,
    );
    expect(find.text('Próximas'), findsOneWidget);
    expect(find.text('Atual'), findsOneWidget);
    expect(find.text('Anteriores'), findsOneWidget);
    expect(find.text('Dezembro de 2026'), findsOneWidget);
    expect(find.text('Novembro de 2026'), findsOneWidget);
    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('Aberta'), findsOneWidget);
    expect(find.text('Fechada'), findsOneWidget);
    expect(find.text('vence ter, 10 nov'), findsOneWidget);
    expect(find.text('R\$ 544,80'), findsOneWidget);
    expect(find.text('R\$ 1.032,15'), findsOneWidget);
    expect(find.byTooltip('Editar cartão'), findsOneWidget);
  });

  Widget detalhe(DateTime competencia) => _app(
    BlocProvider(
      create: (_) => FaturaCubit(FaturasRepositorioFalso(), 'k1'),
      child: FaturaTela(
        contaId: 'k1',
        competencia: competencia,
        ordem: listaExemplo.emOrdem.map((f) => f.competencia).toList(),
      ),
    ),
  );

  testWidgets('Fatura aberta: total até agora e banco sem valor', (
    tester,
  ) async {
    _telaAlta(tester);
    await tester.pumpWidget(detalhe(DateTime(2026, 11)));
    await tester.pumpAndSettle();

    expect(find.text('Fatura de novembro de 2026'), findsOneWidget);
    expect(find.text('Total até agora'), findsOneWidget);
    expect(
      find.text(
        'Soma das compras lançadas. O banco ainda não informou o valor '
        'desta fatura.',
      ),
      findsOneWidget,
    );
    expect(find.text('Fecha'), findsOneWidget);
    expect(find.text('ter, 3 nov'), findsOneWidget);
    expect(find.text('Posto Fictício'), findsOneWidget);
    expect(find.text('Compras · 1'), findsOneWidget);
  });

  testWidgets('Fatura fechada: informado × calculado, ajuste e vencimento', (
    tester,
  ) async {
    _telaAlta(tester);
    await tester.pumpWidget(detalhe(DateTime(2026, 10)));
    await tester.pumpAndSettle();

    expect(find.text('Fechada · a pagar'), findsOneWidget);
    expect(find.text('Valor da fatura'), findsOneWidget);
    expect(find.text('Informado pelo banco'), findsOneWidget);
    expect(find.text('Calculado (compras lançadas)'), findsOneWidget);
    expect(find.text('R\$ 986,25'), findsOneWidget);
    expect(find.text('Faltam R\$ 45,90 em lançamentos.'), findsOneWidget);
    expect(find.text('Ajustar para o valor real'), findsOneWidget);
    expect(find.text('Fechou'), findsOneWidget);
    expect(find.text('seg, 5 out'), findsOneWidget);
    expect(
      find.text(
        'Vencimento: dia 10 caiu num sábado e 12 out é feriado: passou para '
        'o próximo dia útil.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Registrar pagamento'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    final pagamento = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Registrar pagamento'),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      ),
    );
    expect(pagamento.onPressed, isNull);
  });

  testWidgets('Setas navegam pelas faturas da lista e somem nas pontas', (
    tester,
  ) async {
    _telaAlta(tester);
    await tester.pumpWidget(detalhe(DateTime(2026, 11)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Fatura anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Fatura de outubro de 2026'), findsOneWidget);
    expect(find.byTooltip('Fatura anterior'), findsNothing);

    await tester.tap(find.byTooltip('Próxima fatura'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Próxima fatura'));
    await tester.pumpAndSettle();
    expect(find.text('Fatura de dezembro de 2026'), findsOneWidget);
    expect(find.byTooltip('Próxima fatura'), findsNothing);
  });
}
