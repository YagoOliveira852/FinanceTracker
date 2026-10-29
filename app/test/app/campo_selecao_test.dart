import 'package:financas/app/widgets/campos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _opcoes = [
  OpcaoSelecao<String?>(valor: null, rotulo: 'Sem categoria'),
  OpcaoSelecao<String?>(valor: 'a', rotulo: 'Alimentação', detalhe: 'Variável'),
  OpcaoSelecao<String?>(
    valor: 'c',
    rotulo: 'Conta principal',
    detalhe: 'Banco Exemplo',
    resumo: 'Conta principal · Banco Exemplo',
  ),
];

Widget _campo({
  String? valor,
  List<OpcaoSelecao<String?>> opcoes = _opcoes,
  ValueChanged<String?>? aoMudar,
  String? vazio,
}) => MaterialApp(
  home: Scaffold(
    body: CampoSelecao<String?>(
      rotulo: 'Categoria',
      opcoes: opcoes,
      valor: valor,
      vazio: vazio,
      aoMudar: aoMudar,
    ),
  ),
);

void main() {
  testWidgets('mostra o resumo da escolhida, ou o rótulo', (tester) async {
    await tester.pumpWidget(_campo(valor: 'c', aoMudar: (_) {}));
    expect(find.text('Conta principal · Banco Exemplo'), findsOneWidget);

    await tester.pumpWidget(_campo(valor: 'a', aoMudar: (_) {}));
    expect(find.text('Alimentação'), findsOneWidget);
  });

  testWidgets('sem escolhida, mostra o texto de vazio', (tester) async {
    await tester.pumpWidget(
      _campo(
        valor: 'x',
        opcoes: _opcoes.sublist(1),
        vazio: 'Escolha a categoria',
        aoMudar: (_) {},
      ),
    );

    expect(find.text('Escolha a categoria'), findsOneWidget);
  });

  testWidgets('a folha tem título, detalhe e o check na escolhida', (
    tester,
  ) async {
    await tester.pumpWidget(_campo(valor: 'a', aoMudar: (_) {}));

    await tester.tap(find.text('Alimentação'));
    await tester.pumpAndSettle();

    expect(find.text('Categoria'), findsNWidgets(2));
    expect(find.text('Variável'), findsOneWidget);
    expect(find.text('Banco Exemplo'), findsOneWidget);
    final escolhida = find.widgetWithText(ListTile, 'Alimentação');
    expect(tester.widget<ListTile>(escolhida).selected, isTrue);
    expect(
      find.descendant(
        of: escolhida,
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('escolher chama aoMudar, inclusive com a opção nula', (
    tester,
  ) async {
    final escolhas = <String?>[];
    await tester.pumpWidget(_campo(valor: 'a', aoMudar: escolhas.add));

    await tester.tap(find.text('Alimentação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sem categoria'));
    await tester.pumpAndSettle();

    expect(escolhas, [null]);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('fechar a folha sem escolher não muda nada', (tester) async {
    final escolhas = <String?>[];
    await tester.pumpWidget(_campo(valor: 'a', aoMudar: escolhas.add));

    await tester.tap(find.text('Alimentação'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(escolhas, isEmpty);
  });

  testWidgets('sem aoMudar, o campo não abre', (tester) async {
    await tester.pumpWidget(_campo(valor: 'a'));

    await tester.tap(find.text('Alimentação'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
  });
}
