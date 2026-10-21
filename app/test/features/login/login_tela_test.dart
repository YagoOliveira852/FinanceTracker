import 'dart:async';

import 'package:financas/app/tema.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/login/cubit/login_cubit.dart';
import 'package:financas/features/login/cubit/sessao_cubit.dart';
import 'package:financas/features/login/ui/login_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/auth_falso.dart';

Future<void> _abrir(
  WidgetTester tester,
  AuthRepositorioFalso auth, {
  SessaoEstado estado = const SessaoEstado.desconectada(),
}) async {
  final sessao = SessaoCubit(auth)..emit(estado);
  await tester.pumpWidget(
    MaterialApp(
      theme: temaClaro(),
      home: BlocProvider.value(
        value: sessao,
        child: BlocProvider(
          create: (_) => LoginCubit(auth, sessao),
          child: const LoginTela(),
        ),
      ),
    ),
  );
}

Future<void> _preencherEEntrar(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'E-mail'),
    'ana@exemplo.com',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Senha'),
    'exemplo-123',
  );
  await tester.tap(find.text('Entrar'));
}

void main() {
  testWidgets('mostra o aviso de sessão expirada', (tester) async {
    await _abrir(
      tester,
      AuthRepositorioFalso(),
      estado: const SessaoEstado.desconectada(expirou: true),
    );

    expect(find.textContaining('Sessão expirada.'), findsOneWidget);
  });

  testWidgets('login normal não mostra o aviso', (tester) async {
    await _abrir(tester, AuthRepositorioFalso());

    expect(find.text('Acesse suas finanças'), findsOneWidget);
    expect(find.textContaining('Sessão expirada.'), findsNothing);
  });

  testWidgets('credenciais erradas mostram o erro', (tester) async {
    await _abrir(
      tester,
      AuthRepositorioFalso(
        erroAoEntrar: const ErroApi('E-mail ou senha incorretos.', status: 401),
      ),
    );

    await _preencherEEntrar(tester);
    await tester.pump();

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
  });

  testWidgets('enquanto envia, mostra "Entrando" e desabilita o botão', (
    tester,
  ) async {
    final auth = AuthRepositorioFalso()..esperaEntrar = Completer<void>();
    await _abrir(tester, auth);

    await _preencherEEntrar(tester);
    await tester.pump();

    expect(find.text('Entrando'), findsOneWidget);
    final botao = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(botao.onPressed, isNull);

    auth.esperaEntrar!.complete();
    await tester.pumpAndSettle();
  });
}
