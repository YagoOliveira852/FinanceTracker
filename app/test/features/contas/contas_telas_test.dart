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
  testWidgets('Contas mostra total, saldos e os cartões', (tester) async {
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
        cartaoExemplo(),
        cartaoExemplo(id: 'k2', ativa: false).copyWith(nome: 'Cartão antigo'),
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
    expect(find.text('Cartão Exemplo'), findsOneWidget);
    expect(find.text('Fecha 3 nov · vence 10 nov'), findsOneWidget);
    expect(find.text('Fatura atual'), findsOneWidget);
    expect(find.text('R\$ 544,80'), findsOneWidget);
    expect(find.text('Cartão antigo'), findsNothing);
    expect(find.text('Em breve'), findsNothing);
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

  testWidgets('Nova conta: o erro some quando o campo muda', (tester) async {
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
    const erroNome = 'Dê um nome à conta, por exemplo: Conta principal.';
    expect(find.text(erroNome), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nome da conta'),
      'Conta principal',
    );
    await tester.pump();

    expect(find.text(erroNome), findsNothing);
    // Os outros campos continuam com erro até o próximo envio.
    expect(find.text('Informe a instituição da conta.'), findsOneWidget);
  });

  Widget novaConta(ContasRepositorioFalso repositorio) => _app(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ContasCubit(repositorio)..carregar()),
        BlocProvider(create: (_) => NovaContaCubit(repositorio)),
      ],
      child: const NovaContaTela(),
    ),
  );

  testWidgets('Nova conta: cartão de crédito pede dias e mostra a prévia', (
    tester,
  ) async {
    await tester.pumpWidget(
      novaConta(ContasRepositorioFalso(contas: [contaExemplo()])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cartão de crédito'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Nome do cartão'), findsOneWidget);
    expect(find.text('Conta principal · Banco Exemplo'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Saldo inicial'), findsNothing);
    expect(find.text('Próxima fatura: novembro'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Dia de fechamento'),
      '3',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Dia de vencimento'),
      '10',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Próxima fatura: novembro'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Próxima fatura: novembro'), findsOneWidget);
    expect(find.text('Fecha ter, 3 nov · vence ter, 10 nov'), findsOneWidget);
  });

  testWidgets('Nova conta: cartão sem conta corrente avisa e não salva', (
    tester,
  ) async {
    await tester.pumpWidget(
      novaConta(
        ContasRepositorioFalso(
          contas: [contaExemplo(tipo: TipoConta.carteira, nome: 'Carteira')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cartão de crédito'));
    await tester.pumpAndSettle();

    expect(find.text('Falta a conta que paga a fatura'), findsOneWidget);
    final salvar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Salvar cartão'),
    );
    expect(salvar.onPressed, isNull);

    await tester.tap(find.text('Cadastrar conta corrente'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Saldo inicial'), findsOneWidget);
  });
}
