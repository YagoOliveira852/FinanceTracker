import 'package:financas/app/tema.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/open_finance/cubit/conexao_cubit.dart';
import 'package:financas/features/open_finance/cubit/open_finance_cubit.dart';
import 'package:financas/features/open_finance/data/open_finance.dart';
import 'package:financas/features/open_finance/ui/conexao_tela.dart';
import 'package:financas/features/open_finance/ui/open_finance_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../apoio/contas_falso.dart';
import '../../apoio/open_finance_falso.dart';

/// Os estados do design "Open Finance" (dados fictícios). "Agora" = 04/11,
/// 09:40 no aparelho.
void main() {
  late OpenFinanceRepositorioFalso repositorio;
  final agora = DateTime(2026, 11, 4, 9, 40);

  void telaAlta(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> abrirLista(WidgetTester tester, List<Conexao> conexoes) async {
    telaAlta(tester);
    repositorio = OpenFinanceRepositorioFalso(
      lista: ListaConexoes(conexoes: conexoes),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: temaClaro(),
        home: BlocProvider(
          create: (_) => OpenFinanceCubit(repositorio)..carregar(),
          child: OpenFinanceTela(agora: () => agora),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Open Finance', () {
    testWidgets('conexão em dia: estado, contas e ações', (tester) async {
      await abrirLista(tester, [conexaoExemplo()]);

      expect(find.text('Banco Exemplo'), findsOneWidget);
      expect(find.text('Em dia'), findsOneWidget);
      expect(find.text('Conta principal'), findsOneWidget);
      expect(find.text('até 15 ago 2027'), findsOneWidget);
      expect(find.text('Buscar agora'), findsOneWidget);
      expect(find.text('Desativar'), findsOneWidget);
      expect(find.text('Renovar'), findsNothing);
    });

    testWidgets('com erro mostra a mensagem; vencendo mostra Renovar', (
      tester,
    ) async {
      await abrirLista(tester, [
        conexaoExemplo(
          problema: ProblemaOpenFinance.erro,
          ultimoErro: 'O banco não respondeu.',
        ),
        conexaoExemplo(
          id: 'x2',
          instituicao: 'Banco Fictício',
          problema: ProblemaOpenFinance.vencendo,
          consentimentoExpiraEm: DateTime(2026, 11, 16, 12),
        ),
      ]);

      expect(find.text('Com erro'), findsOneWidget);
      expect(find.text('O banco não respondeu.'), findsOneWidget);
      expect(find.text('Vencendo'), findsOneWidget);
      expect(find.textContaining('vence em 12 dias'), findsOneWidget);
      expect(find.text('Renovar'), findsOneWidget);
    });

    testWidgets('buscar agora fica travado até a hora certa', (tester) async {
      await abrirLista(tester, [
        conexaoExemplo(buscarAPartirDe: DateTime(2026, 11, 4, 10, 40)),
      ]);

      final botao = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Buscar agora'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(botao.onPressed, isNull);
      expect(find.textContaining('a partir de hoje, 10:40'), findsOneWidget);
    });

    testWidgets('buscar agora roda e avisa', (tester) async {
      await abrirLista(tester, [conexaoExemplo()]);

      await tester.tap(find.text('Buscar agora'));
      await tester.pumpAndSettle();

      expect(repositorio.buscas, ['x1']);
      expect(find.text('3 transações novas na Revisão.'), findsOneWidget);
    });

    testWidgets('desativar confirma antes e explica que as contas ficam', (
      tester,
    ) async {
      await abrirLista(tester, [conexaoExemplo()]);

      await tester.tap(find.text('Desativar'));
      await tester.pumpAndSettle();
      expect(find.text('Desativar Banco Exemplo?'), findsOneWidget);
      expect(find.textContaining('dá para reativar depois'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Desativar').last);
      await tester.pumpAndSettle();

      expect(repositorio.alteracoes.single, (conexaoId: 'x1', ativa: false));
      expect(find.text('Desativada'), findsOneWidget);
      expect(find.text('Reativar'), findsOneWidget);
    });

    testWidgets('sem conexões convida a adicionar', (tester) async {
      await abrirLista(tester, []);

      expect(find.textContaining('Nenhuma conexão ainda'), findsOneWidget);
      expect(find.text('Adicionar conexão'), findsOneWidget);
    });

    testWidgets('tema escuro renderiza', (tester) async {
      telaAlta(tester);
      repositorio = OpenFinanceRepositorioFalso(
        lista: ListaConexoes(
          conexoes: [conexaoExemplo(problema: ProblemaOpenFinance.vencido)],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: temaEscuro(),
          home: BlocProvider(
            create: (_) => OpenFinanceCubit(repositorio)..carregar(),
            child: OpenFinanceTela(agora: () => agora),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vencido'), findsOneWidget);
    });
  });

  group('Adicionar conexão', () {
    late List<bool?> resultados;

    Future<void> abrir(WidgetTester tester, {Conexao? conexao}) async {
      telaAlta(tester);
      resultados = [];
      repositorio = OpenFinanceRepositorioFalso();
      final roteador = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => TextButton(
              onPressed: () async =>
                  resultados.add(await context.push<bool>('/conexao')),
              child: const Text('abrir'),
            ),
          ),
          GoRoute(
            path: '/conexao',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => ContasCubit(
                    ContasRepositorioFalso(contas: [contaExemplo()]),
                  )..carregar(),
                ),
                BlocProvider(
                  create: (_) =>
                      ConexaoCubit(repositorio, conexaoId: conexao?.id),
                ),
              ],
              child: ConexaoTela(conexao: conexao),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: temaClaro(), routerConfig: roteador),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('verifica o ID, mostra o banco e vincula as contas', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Adicionar conexão'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '8f3c2a91');
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Banco Exemplo encontrado'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Vincular contas'), findsOneWidget);
      expect(find.text('Conta corrente'), findsWidgets);
      expect(
        find.text('Sugestão: Conta principal (mesmo final 3456)'),
        findsOneWidget,
      );

      await tester.tap(find.text('Salvar vínculos'));
      await tester.pumpAndSettle();

      expect(repositorio.criadas.single.vinculos, const [
        Vinculo(pluggyAccountId: 'conta-1', contaId: 'c1'),
        Vinculo(pluggyAccountId: 'cartao-1'),
      ]);
      expect(resultados, [true]);
    });

    testWidgets('ID inválido mostra o erro no campo', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), ' ');
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();

      expect(find.text('Cole o ID do item do Meu Pluggy.'), findsOneWidget);
    });

    testWidgets('renovação muda os textos e o botão', (tester) async {
      await abrir(tester, conexao: conexaoExemplo());

      expect(find.text('Renovar conexão'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'item-novo');
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Renovar conexão'));
      await tester.pumpAndSettle();

      expect(repositorio.renovadas.single.conexaoId, 'x1');
    });
  });
}
