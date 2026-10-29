import 'package:financas/app/tema.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/faturas/cubit/fatura_cubit.dart';
import 'package:decimal/decimal.dart';
import 'package:financas/features/faturas/cubit/faturas_cubit.dart';
import 'package:financas/features/faturas/cubit/pagamento_cubit.dart';
import 'package:financas/features/faturas/data/fatura.dart';
import 'package:financas/features/transacoes/cubit/lancamento_cubit.dart';
import 'package:financas/features/transacoes/cubit/transferencia_cubit.dart';
import 'package:financas/features/transacoes/ui/lancamento_tela.dart';
import 'package:go_router/go_router.dart';
import 'package:financas/features/faturas/ui/fatura_tela.dart';
import 'package:financas/features/faturas/ui/formulario_pagamento.dart';
import 'package:financas/features/faturas/ui/faturas_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/categorias_falso.dart';
import '../../apoio/contas_falso.dart';
import '../../apoio/faturas_falso.dart';
import '../../apoio/transacoes_falso.dart';

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

  Widget detalhe(DateTime competencia, {FaturasRepositorioFalso? faturas}) =>
      _app(
        BlocProvider(
          create: (_) =>
              FaturaCubit(faturas ?? FaturasRepositorioFalso(), 'k1'),
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

  testWidgets('Fatura mostra a data e o número da parcela', (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(detalhe(DateTime(2026, 12)));
    await tester.pumpAndSettle();

    expect(find.text('30 nov · Parcela 3/10'), findsOneWidget);
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
    final pagamento = tester.widget<FloatingActionButton>(
      find.widgetWithText(FloatingActionButton, 'Registrar pagamento'),
    );
    expect(pagamento.onPressed, isNotNull);
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

  /// Repositório falso com outubro trocado por [outubro] e novembro por
  /// [novembro].
  FaturasRepositorioFalso com({
    ResumoFatura? outubro,
    ResumoFatura? novembro,
  }) => FaturasRepositorioFalso()
    ..lista = ListaFaturas(
      atual: novembro ?? novembroExemplo,
      proximas: [dezembroExemplo],
      anteriores: [outubro ?? outubroExemplo],
    );

  testWidgets('Fatura paga: chip, quadro do pagamento e sem botão', (
    tester,
  ) async {
    _telaAlta(tester);
    final paga = outubroExemplo.copyWith(
      status: StatusFatura.paga,
      valorCalculado: Decimal.parse('1032.15'),
      valorPago: Decimal.parse('1032.15'),
    );
    await tester.pumpWidget(
      detalhe(DateTime(2026, 10), faturas: com(outubro: paga)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paga'), findsOneWidget);
    expect(find.text('Valor da fatura'), findsOneWidget);
    expect(
      find.text('Confere com o valor informado pelo banco.'),
      findsOneWidget,
    );
    expect(find.text('Paga em ter, 13 out'), findsOneWidget);
    expect(find.text('Conta principal · Banco Exemplo'), findsOneWidget);
    expect(find.text('Venceu'), findsOneWidget);
    expect(find.text('Registrar pagamento'), findsNothing);
  });

  testWidgets('Fatura fechada com pagamento parcial: falta pagar', (
    tester,
  ) async {
    _telaAlta(tester);
    final parcial = outubroExemplo.copyWith(
      valorCalculado: Decimal.parse('1032.15'),
      valorPago: Decimal.parse('1000.00'),
    );
    await tester.pumpWidget(
      detalhe(DateTime(2026, 10), faturas: com(outubro: parcial)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fechada · a pagar'), findsOneWidget);
    expect(find.text('Falta pagar'), findsOneWidget);
    expect(find.text('R\$ 32,15'), findsOneWidget);
    expect(
      find.text(
        'De R\$ 1.032,15 da fatura. Pagando o restante, ela fica paga.',
      ),
      findsOneWidget,
    );
    expect(find.text('Pagamento em ter, 13 out'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Registrar pagamento'),
      findsOneWidget,
    );
  });

  testWidgets('Fatura aberta com pagamento adiantado', (tester) async {
    _telaAlta(tester);
    final adiantada = novembroExemplo.copyWith(
      valorPago: Decimal.parse('300.00'),
    );
    await tester.pumpWidget(
      detalhe(DateTime(2026, 11), faturas: com(novembro: adiantada)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aberta'), findsOneWidget);
    expect(find.text('Total até agora'), findsOneWidget);
    expect(
      find.text(
        'Falta pagar R\$ 244,80 até agora. Compras novas ainda entram nesta '
        'fatura.',
      ),
      findsOneWidget,
    );
    expect(find.text('Pagamento adiantado em ter, 10 nov'), findsOneWidget);
    expect(find.text('Registrar pagamento'), findsNothing);
  });

  testWidgets('Lista de faturas mostra o chip Paga', (tester) async {
    _telaAlta(tester);
    final faturas = com(
      outubro: outubroExemplo.copyWith(
        status: StatusFatura.paga,
        valorPago: Decimal.parse('1032.15'),
      ),
    );
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => FaturasCubit(faturas, 'k1')..carregar(),
          child: const FaturasTela(contaId: 'k1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paga'), findsOneWidget);
  });

  // A fatura fica aberta na aba Mais enquanto a Revisão (outra aba) confirma
  // ou ignora compras dela; cada ação recarrega as contas.
  testWidgets('Fatura aberta recarrega quando as contas recarregam', (
    tester,
  ) async {
    _telaAlta(tester);
    final faturas = com();
    await tester.pumpWidget(detalhe(DateTime(2026, 10), faturas: faturas));
    await tester.pumpAndSettle();
    expect(find.text('Fechada · a pagar'), findsOneWidget);
    final cargas = faturas.obtidas.length;

    faturas.lista = com(
      outubro: outubroExemplo.copyWith(
        status: StatusFatura.paga,
        valorPago: Decimal.parse('1032.15'),
      ),
    ).lista;
    tester.element(find.byType(FaturaTela)).read<ContasCubit>().carregar();
    await tester.pumpAndSettle();

    expect(find.text('Paga'), findsOneWidget);
    expect(faturas.obtidas.skip(cargas), [DateTime(2026, 10)]);
  });

  testWidgets('Lista de faturas recarrega quando as contas recarregam', (
    tester,
  ) async {
    _telaAlta(tester);
    final faturas = com();
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => FaturasCubit(faturas, 'k1')..carregar(),
          child: const FaturasTela(contaId: 'k1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Paga'), findsNothing);

    faturas.lista = com(
      outubro: outubroExemplo.copyWith(
        status: StatusFatura.paga,
        valorPago: Decimal.parse('1032.15'),
      ),
    ).lista;
    tester.element(find.byType(FaturasTela)).read<ContasCubit>().carregar();
    await tester.pumpAndSettle();

    expect(find.text('Paga'), findsOneWidget);
  });

  testWidgets('Registrar pagamento abre o formulário com cartão e fatura', (
    tester,
  ) async {
    _telaAlta(tester);
    final faturas = FaturasRepositorioFalso();
    final router = GoRouter(
      initialLocation: rotaFatura('k1', DateTime(2026, 10)),
      routes: [
        GoRoute(
          path: '/mais/contas/cartao/:id/fatura/:competencia',
          builder: (_, _) => BlocProvider(
            create: (_) => FaturaCubit(faturas, 'k1'),
            child: FaturaTela(contaId: 'k1', competencia: DateTime(2026, 10)),
          ),
          routes: [
            GoRoute(
              path: 'pagar',
              builder: (_, _) => MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) =>
                        LancamentoCubit(TransacoesRepositorioFalso(), faturas),
                  ),
                  BlocProvider(
                    create: (_) =>
                        TransferenciaCubit(TransacoesRepositorioFalso()),
                  ),
                  BlocProvider(create: (_) => PagamentoCubit(faturas)),
                ],
                child: LancamentoTela(
                  pagamentoInicial: PagamentoInicial(
                    cartaoId: 'k1',
                    competencia: DateTime(2026, 10),
                  ),
                ),
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
          ContasRepositorioFalso(contas: [contaExemplo(), cartaoExemplo()]),
        )..carregar(),
        child: comCategorias(
          MaterialApp.router(theme: temaClaro(), routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar pagamento'));
    await tester.pumpAndSettle();

    expect(find.text('Cartão Exemplo · Banco Exemplo'), findsOneWidget);
    expect(find.text('Outubro · fechada · vence ter, 13 out'), findsOneWidget);
    await tester.tap(find.text('Salvar pagamento'));
    await tester.pumpAndSettle();

    expect(faturas.pagamentos.single.competencia, DateTime(2026, 10));
    expect(find.text('Fatura de outubro de 2026'), findsOneWidget);
  });
}
