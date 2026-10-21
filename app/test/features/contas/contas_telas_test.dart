import 'package:financas/app/tema.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/contas/cubit/nova_conta_cubit.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/contas/ui/contas_tela.dart';
import 'package:financas/features/contas/ui/nova_conta_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/contas_falso.dart';

Widget _app(Widget tela) => MaterialApp(theme: temaClaro(), home: tela);

void main() {
  testWidgets('Contas mostra total, saldos e cartões em breve', (tester) async {
    final repositorio = ContasRepositorioFalso(
      contas: [
        contaExemplo(),
        contaExemplo(
          id: 'c2',
          nome: 'Conta do dia a dia',
          instituicao: 'Banco Fictício',
          saldo: '-120.40',
        ),
        contaExemplo(
          id: 'c3',
          nome: 'Carteira',
          tipo: TipoConta.carteira,
          saldo: '950.50',
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => ContasCubit(repositorio)..carregar(),
          child: const ContasTela(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('R\$ 3.180,10'), findsOneWidget);
    expect(find.text('Banco Exemplo · Conta corrente'), findsOneWidget);
    expect(find.text('− R\$ 120,40'), findsOneWidget);
    expect(find.text('Saldo negativo'), findsOneWidget);
    expect(find.text('Dinheiro em espécie'), findsOneWidget);
    expect(find.text('Em breve'), findsOneWidget);
  });

  testWidgets('Contas sem contas mostra o estado vazio', (tester) async {
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => ContasCubit(ContasRepositorioFalso())..carregar(),
          child: const ContasTela(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma conta cadastrada'), findsOneWidget);
    expect(find.text('Adicionar conta'), findsOneWidget);
  });

  testWidgets('Nova conta mostra o erro embaixo do campo', (tester) async {
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => NovaContaCubit(ContasRepositorioFalso()),
          child: const NovaContaTela(),
        ),
      ),
    );

    await tester.tap(find.text('Salvar conta'));
    await tester.pump();

    expect(
      find.text('Dê um nome à conta, por exemplo: Conta principal.'),
      findsOneWidget,
    );
    expect(find.text('Informe a instituição da conta.'), findsOneWidget);
  });

  testWidgets('Nova conta: carteira esconde a instituição', (tester) async {
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => NovaContaCubit(ContasRepositorioFalso()),
          child: const NovaContaTela(),
        ),
      ),
    );
    expect(find.widgetWithText(TextField, 'Instituição'), findsOneWidget);

    await tester.tap(find.text('Carteira (dinheiro)'));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Instituição'), findsNothing);
  });
}
