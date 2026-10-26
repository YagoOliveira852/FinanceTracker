import 'package:financas/app/tema.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/transacoes/cubit/lancamento_cubit.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/transacoes/cubit/transacoes_cubit.dart';
import 'package:financas/features/transacoes/cubit/transferencia_cubit.dart';
import 'package:financas/features/transacoes/data/transacao.dart';
import 'package:financas/features/transacoes/ui/lancamento_tela.dart';
import 'package:financas/features/transacoes/ui/transacoes_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../apoio/contas_falso.dart';
import '../../apoio/faturas_falso.dart';
import '../../apoio/transacoes_falso.dart';

final _hoje = DateTime(2026, 10, 20);

/// App mínimo. A tela de Transações ouve o ContasCubit do topo do app; aqui
/// ele fica parado, e os testes que precisam dele passam o próprio.
Widget _app(Widget tela) => MaterialApp(
  theme: temaClaro(),
  home: BlocProvider(
    create: (_) => ContasCubit(ContasRepositorioFalso()),
    child: tela,
  ),
);

void main() {
  testWidgets('lista agrupada por dia, com sinal e rascunho', (tester) async {
    final contas = ContasRepositorioFalso(
      contas: [
        contaExemplo(),
        contaExemplo(id: 'c2', nome: 'Carteira', tipo: TipoConta.carteira),
      ],
    );
    final transacoes = TransacoesRepositorioFalso(
      transacoes: [
        transacaoExemplo(contaId: 'c1'),
        transacaoExemplo(
          id: 't2',
          contaId: 'c2',
          descricao: 'Padaria Pão Quente',
          valor: '18.50',
          status: StatusTransacao.rascunho,
        ),
        transacaoExemplo(
          id: 't3',
          tipo: TipoTransacao.receita,
          descricao: 'Freela de design',
          valor: '850',
          data: DateTime(2026, 10, 16),
        ),
        transacaoExemplo(
          id: 't4',
          tipo: TipoTransacao.pagamentoFatura,
          descricao: 'Pagamento de fatura',
          valor: '1032.15',
          data: DateTime(2026, 10, 19),
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) =>
              TransacoesCubit(transacoes, contas, hoje: () => _hoje)
                ..carregar(),
          child: const TransacoesTela(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('Hoje · 20 out'), findsOneWidget);
    expect(find.text('Ontem · 19 out'), findsOneWidget);
    expect(find.text('Sex · 16 out'), findsOneWidget);
    expect(find.text('− R\$ 187,40'), findsOneWidget);
    expect(find.text('+ R\$ 850,00'), findsOneWidget);
    expect(find.text('R\$ 1.032,15'), findsOneWidget);
    expect(find.text('Rascunho'), findsOneWidget);
    // Chips de filtro: Todas + contas.
    expect(find.widgetWithText(FilterChip, 'Carteira'), findsOneWidget);
    final proximo = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    expect(proximo.onPressed, isNull);
  });

  testWidgets('mês sem transações mostra o vazio', (tester) async {
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => TransacoesCubit(
            TransacoesRepositorioFalso(),
            ContasRepositorioFalso(contas: [contaExemplo()]),
            hoje: () => _hoje,
          )..carregar(),
          child: const TransacoesTela(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma transação em outubro'), findsOneWidget);
    expect(find.text('Lançar transação'), findsOneWidget);
  });

  testWidgets('Lançamento: transferência habilitada, pagamento em breve', (
    tester,
  ) async {
    // Tela de celular (390 × 844), para o formulário caber inteiro.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  ContasCubit(ContasRepositorioFalso(contas: [contaExemplo()]))
                    ..carregar(),
            ),
            BlocProvider(
              create: (_) => LancamentoCubit(
                TransacoesRepositorioFalso(),
                FaturasRepositorioFalso(),
              ),
            ),
          ],
          child: const LancamentoTela(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    FilterChip chip(String rotulo) =>
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, rotulo));
    expect(chip('Despesa').selected, isTrue);
    expect(chip('Receita').onSelected, isNotNull);
    expect(chip('Transferência').onSelected, isNotNull);
    expect(chip('Pagamento de fatura').onSelected, isNull);
    expect(find.text('Categorias: em breve.'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pump();

    expect(find.text('Escolha uma conta.'), findsOneWidget);
    expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
  });

  testWidgets('Lançamento não envia a conta do filtro se ela está '
      'desativada', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final transacoes = TransacoesRepositorioFalso();
    await tester.pumpWidget(
      _app(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ContasCubit(
                ContasRepositorioFalso(
                  contas: [
                    contaExemplo(),
                    contaExemplo(
                      id: 'antiga',
                      nome: 'Conta antiga',
                      ativa: false,
                    ),
                  ],
                ),
              )..carregar(),
            ),
            BlocProvider(
              create: (_) =>
                  LancamentoCubit(transacoes, FaturasRepositorioFalso()),
            ),
          ],
          child: const LancamentoTela(contaInicial: 'antiga'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '10');
    await tester.enterText(
      find.widgetWithText(TextField, 'Descrição'),
      'Mercado',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pump();

    expect(find.text('Escolha uma conta.'), findsOneWidget);
    expect(transacoes.lancados, isEmpty);
  });

  testWidgets('Lançamento usa a conta do filtro quando ela vale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final transacoes = TransacoesRepositorioFalso();
    // Router mínimo: ao salvar, a tela fecha com context.pop(true).
    final router = GoRouter(
      initialLocation: '/lancar',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SizedBox(),
          routes: [
            GoRoute(
              path: 'lancar',
              builder: (_, _) => MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) => ContasCubit(
                      ContasRepositorioFalso(contas: [contaExemplo()]),
                    )..carregar(),
                  ),
                  BlocProvider(
                    create: (_) =>
                        LancamentoCubit(transacoes, FaturasRepositorioFalso()),
                  ),
                ],
                child: const LancamentoTela(contaInicial: 'c1'),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: temaClaro(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conta principal · Banco Exemplo'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '10');
    await tester.enterText(
      find.widgetWithText(TextField, 'Descrição'),
      'Mercado',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(transacoes.lancados.single.contaId, 'c1');
    expect(find.byType(LancamentoTela), findsNothing);
  });

  testWidgets('chips de filtro acompanham conta criada depois', (tester) async {
    final contas = ContasRepositorioFalso(contas: [contaExemplo()]);
    final contasCubit = ContasCubit(contas)..carregar();
    addTearDown(contasCubit.close);
    await tester.pumpWidget(
      _app(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: contasCubit),
            BlocProvider(
              create: (_) => TransacoesCubit(
                TransacoesRepositorioFalso(),
                contas,
                hoje: () => _hoje,
              )..carregar(),
            ),
          ],
          child: const TransacoesTela(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'Carteira'), findsNothing);

    contas.contas.add(
      contaExemplo(id: 'c2', nome: 'Carteira', tipo: TipoConta.carteira),
    );
    await contasCubit.carregar();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Carteira'), findsOneWidget);
  });

  Widget lancamento({
    required List<Conta> contas,
    String? contaInicial,
    FaturasRepositorioFalso? faturas,
  }) => _app(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              ContasCubit(ContasRepositorioFalso(contas: contas))..carregar(),
        ),
        BlocProvider(
          create: (_) => LancamentoCubit(
            TransacoesRepositorioFalso(),
            faturas ?? FaturasRepositorioFalso(),
          ),
        ),
      ],
      child: LancamentoTela(contaInicial: contaInicial),
    ),
  );

  testWidgets('Lançamento: despesa lista o cartão e receita não', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      lancamento(contas: [contaExemplo(), cartaoExemplo()]),
    );
    await tester.pumpAndSettle();

    // O tipo vem antes da conta.
    expect(
      tester.getTopLeft(find.text('Despesa')).dy,
      lessThan(tester.getTopLeft(find.text('Conta')).dy),
    );

    await tester.tap(find.text('Selecione uma conta'));
    await tester.pumpAndSettle();
    expect(find.text('Cartão Exemplo · Banco Exemplo'), findsWidgets);
    await tester.tap(find.text('Conta principal · Banco Exemplo').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conta principal · Banco Exemplo'));
    await tester.pumpAndSettle();
    expect(find.text('Cartão Exemplo · Banco Exemplo'), findsNothing);
  });

  testWidgets('Lançamento no cartão: entra na fatura e tem parcelas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final faturas = FaturasRepositorioFalso();
    await tester.pumpWidget(
      lancamento(
        contas: [contaExemplo(), cartaoExemplo()],
        contaInicial: 'k1',
        faturas: faturas,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entra na fatura de novembro'), findsOneWidget);
    expect(find.text('Fecha ter, 3 nov · vence ter, 10 nov'), findsOneWidget);
    expect(find.text('Parcelas'), findsOneWidget);
    expect(find.text('À vista'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Valor total'), findsOneWidget);
    expect(find.textContaining('A última parcela'), findsNothing);
    expect(faturas.consultasParaCompra.single.contaId, 'k1');
  });

  testWidgets('Lançamento em conta comum não mostra fatura', (tester) async {
    final faturas = FaturasRepositorioFalso();
    await tester.pumpWidget(
      lancamento(
        contas: [contaExemplo()],
        contaInicial: 'c1',
        faturas: faturas,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Entra na fatura'), findsNothing);
    expect(find.text('Parcelas'), findsNothing);
    expect(faturas.consultasParaCompra, isEmpty);
  });

  /// Lançamento dentro de um router mínimo: ao salvar, a tela fecha com
  /// context.pop(true).
  Future<void> abrirLancamento(
    WidgetTester tester, {
    required TransacoesRepositorioFalso transacoes,
    required String contaInicial,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/lancar',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SizedBox(),
          routes: [
            GoRoute(
              path: 'lancar',
              builder: (_, _) => MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) => ContasCubit(
                      ContasRepositorioFalso(
                        contas: [contaExemplo(), cartaoExemplo()],
                      ),
                    )..carregar(),
                  ),
                  BlocProvider(
                    create: (_) =>
                        LancamentoCubit(transacoes, FaturasRepositorioFalso()),
                  ),
                ],
                child: LancamentoTela(contaInicial: contaInicial),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: temaClaro(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  Future<void> escolherParcelas(WidgetTester tester, String opcao) async {
    await tester.tap(find.text('À vista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(opcao).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Lançamento parcelado: divisão, última fatura e salvar', (
    tester,
  ) async {
    final transacoes = TransacoesRepositorioFalso();
    await abrirLancamento(tester, transacoes: transacoes, contaInicial: 'k1');

    await escolherParcelas(tester, '3x');
    await tester.enterText(
      find.widgetWithText(TextField, 'Valor total'),
      '1.000,00',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('3x de R\$ 333,33; a 1ª parcela fica com R\$ 333,34.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('A última parcela cai na fatura de janeiro de 2027.'),
      findsOneWidget,
    );

    final descricao = find.widgetWithText(TextField, 'Descrição');
    await tester.scrollUntilVisible(
      descricao,
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(descricao, 'Fone de ouvido');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(transacoes.lancados, isEmpty);
    final compra = transacoes.parceladas.single;
    expect(compra.qtdParcelas, 3);
    expect(compra.contaId, 'k1');
    expect(find.byType(LancamentoTela), findsNothing);
  });

  testWidgets('Lançamento: trocar o cartão por conta comum volta a à vista', (
    tester,
  ) async {
    final transacoes = TransacoesRepositorioFalso();
    await abrirLancamento(tester, transacoes: transacoes, contaInicial: 'k1');

    await escolherParcelas(tester, '3x');
    await tester.tap(find.text('Cartão Exemplo · Banco Exemplo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conta principal · Banco Exemplo').last);
    await tester.pumpAndSettle();

    expect(find.text('Parcelas'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '90');
    await tester.enterText(
      find.widgetWithText(TextField, 'Descrição'),
      'Mercado',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(transacoes.parceladas, isEmpty);
    expect(transacoes.lancados.single.contaId, 'c1');
  });

  testWidgets('Transações mostra a parcela ao lado da conta', (tester) async {
    final transacoes = TransacoesRepositorioFalso(
      transacoes: [
        transacaoExemplo(
          contaId: 'k1',
          descricao: 'Notebook Loja Exemplo',
          parcela: const Parcela(numero: 3, total: 10),
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => TransacoesCubit(
            transacoes,
            ContasRepositorioFalso(contas: [contaExemplo(), cartaoExemplo()]),
            hoje: () => _hoje,
          )..carregar(),
          child: const TransacoesTela(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cartão Exemplo · Parcela 3/10'), findsOneWidget);
  });

  group('transferência', () {
    final contas = [
      contaExemplo(),
      contaExemplo(id: 'c3', nome: 'Carteira', tipo: TipoConta.carteira),
      cartaoExemplo(),
    ];

    Future<void> abrirTransferencia(
      WidgetTester tester,
      TransacoesRepositorioFalso transacoes,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/lancar',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Text('Fechou'),
            routes: [
              GoRoute(
                path: 'lancar',
                builder: (_, _) => MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) =>
                          ContasCubit(ContasRepositorioFalso(contas: contas))
                            ..carregar(),
                    ),
                    BlocProvider(
                      create: (_) => LancamentoCubit(
                        transacoes,
                        FaturasRepositorioFalso(),
                      ),
                    ),
                    BlocProvider(create: (_) => TransferenciaCubit(transacoes)),
                  ],
                  child: const LancamentoTela(),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: temaClaro(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transferência'));
      await tester.pumpAndSettle();
    }

    Future<void> escolher(
      WidgetTester tester,
      String campo,
      String opcao,
    ) async {
      await tester.tap(find.widgetWithText(InputDecorator, campo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(opcao).last);
      await tester.pumpAndSettle();
    }

    testWidgets('De e Para sem cartão, inverter e salvar', (tester) async {
      final transacoes = TransacoesRepositorioFalso();
      await abrirTransferencia(tester, transacoes);

      expect(
        find.text(
          'Entre contas próprias: não conta como gasto nem como renda. '
          'Para pagar cartão, use Pagamento de fatura.',
        ),
        findsOneWidget,
      );
      await escolher(tester, 'De', 'Conta principal · Banco Exemplo');
      await tester.tap(find.widgetWithText(InputDecorator, 'Para'));
      await tester.pumpAndSettle();
      // Para não oferece a conta de origem nem o cartão.
      expect(find.text('Conta principal · Banco Exemplo'), findsOneWidget);
      expect(find.text('Cartão Exemplo · Banco Exemplo'), findsNothing);
      await tester.tap(find.text('Carteira').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Inverter origem e destino'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '200');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final enviada = transacoes.transferencias.single;
      expect(enviada.contaOrigemId, 'c3');
      expect(enviada.contaDestinoId, 'c1');
      expect(enviada.valor.toString(), '200');
      expect(enviada.descricao, isNull);
      expect(find.text('Fechou'), findsOneWidget);
    });

    testWidgets('erro da API no destino aparece no Para', (tester) async {
      final transacoes = TransacoesRepositorioFalso()
        ..erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {'conta_destino_id': 'Esta conta está desativada.'},
        );
      await abrirTransferencia(tester, transacoes);
      await escolher(tester, 'De', 'Conta principal · Banco Exemplo');
      await escolher(tester, 'Para', 'Carteira');
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '50');

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Esta conta está desativada.'), findsOneWidget);
    });
  });

  testWidgets('Transações mostra a transferência numa linha só', (
    tester,
  ) async {
    const par = ParTransferencia(
      parId: 'x',
      contaOrigemId: 'c1',
      contaDestinoId: 'c3',
    );
    final contas = ContasRepositorioFalso(
      contas: [
        contaExemplo(),
        contaExemplo(
          id: 'c3',
          nome: 'Carteira',
          tipo: TipoConta.carteira,
          ativa: false,
        ),
      ],
    );
    final transacoes = TransacoesRepositorioFalso(
      transacoes: [
        transacaoExemplo(
          id: 'saida',
          tipo: TipoTransacao.transferenciaSaida,
          valor: '200',
          descricao: 'Transferência',
          transferencia: par.copyWith(parId: 'entrada'),
        ),
        transacaoExemplo(
          id: 'entrada',
          contaId: 'c3',
          tipo: TipoTransacao.transferenciaEntrada,
          valor: '200',
          descricao: 'Transferência',
          transferencia: par.copyWith(parId: 'saida'),
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) =>
              TransacoesCubit(transacoes, contas, hoje: () => _hoje)
                ..carregar(),
          child: const TransacoesTela(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conta principal → Carteira'), findsOneWidget);
    expect(find.text('R\$ 200,00'), findsOneWidget);
    // A conta desativada aparece no subtítulo, mas não vira filtro.
    expect(find.widgetWithText(FilterChip, 'Carteira'), findsNothing);
  });
}
