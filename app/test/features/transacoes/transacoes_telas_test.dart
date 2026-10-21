import 'package:financas/app/tema.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/transacoes/cubit/lancamento_cubit.dart';
import 'package:financas/features/transacoes/cubit/transacoes_cubit.dart';
import 'package:financas/features/transacoes/data/transacao.dart';
import 'package:financas/features/transacoes/ui/lancamento_tela.dart';
import 'package:financas/features/transacoes/ui/transacoes_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/contas_falso.dart';
import '../../apoio/transacoes_falso.dart';

final _hoje = DateTime(2026, 10, 20);

Widget _app(Widget tela) => MaterialApp(theme: temaClaro(), home: tela);

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

  testWidgets('Lançamento: transferência e pagamento desabilitados', (
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
              create: (_) => LancamentoCubit(TransacoesRepositorioFalso()),
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
    expect(chip('Transferência').onSelected, isNull);
    expect(chip('Pagamento de fatura').onSelected, isNull);
    expect(find.text('Categorias: em breve.'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pump();

    expect(find.text('Escolha uma conta.'), findsOneWidget);
    expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
  });
}
