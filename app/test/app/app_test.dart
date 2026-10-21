import 'package:financas/app/app.dart';
import 'package:financas/app/injecao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../apoio/auth_falso.dart';
import '../apoio/contas_falso.dart';
import '../apoio/transacoes_falso.dart';

/// App inteiro (router, abas, providers) com repositórios falsos.
Future<Dependencias> _abrir(WidgetTester tester, {bool sessao = true}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final dependencias = Dependencias(
    auth: AuthRepositorioFalso(sessao: sessao),
    contas: ContasRepositorioFalso(contas: [contaExemplo()]),
    transacoes: TransacoesRepositorioFalso(),
  );
  await dependencias.sessao.iniciar();
  await tester.pumpWidget(FinancasApp(dependencias));
  await tester.pumpAndSettle();
  return dependencias;
}

void main() {
  testWidgets('sem sessão, abre o login', (tester) async {
    await _abrir(tester, sessao: false);

    expect(find.text('Acesse suas finanças'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('com sessão, abre o Início com o saldo disponível', (
    tester,
  ) async {
    await _abrir(tester);

    expect(find.text('Saldo disponível'), findsOneWidget);
    expect(find.text('R\$ 2.350,00'), findsOneWidget);
    expect(find.text('Aporte e alerta chegam em breve'), findsOneWidget);
  });

  testWidgets('login leva ao Início', (tester) async {
    await _abrir(tester, sessao: false);

    await tester.enterText(
      find.widgetWithText(TextField, 'E-mail'),
      'ana@exemplo.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Senha'),
      'exemplo-123',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Saldo disponível'), findsOneWidget);
    expect(find.text('R\$ 2.350,00'), findsOneWidget);
  });

  testWidgets('Mais → Contas, com itens em breve visíveis', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    expect(find.text('Open Finance'), findsOneWidget);
    expect(find.text('Em breve'), findsNWidgets(7));

    await tester.tap(find.text('Contas'));
    await tester.pumpAndSettle();
    expect(find.text('Total disponível'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('aba Revisão mostra em breve', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Revisão'));
    await tester.pumpAndSettle();

    expect(find.text('Revisão chega em breve'), findsOneWidget);
  });

  testWidgets('Sair volta ao login', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sair'), 200);
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(find.text('Acesse suas finanças'), findsOneWidget);
    expect(find.textContaining('Sessão expirada.'), findsNothing);
  });

  testWidgets('sessão expirada leva ao login com o aviso', (tester) async {
    final dependencias = await _abrir(tester);

    dependencias.sessao.expirou();
    await tester.pumpAndSettle();

    expect(find.text('Acesse suas finanças'), findsOneWidget);
    expect(find.textContaining('Sessão expirada.'), findsOneWidget);
  });
}
