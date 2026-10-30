import 'package:decimal/decimal.dart';
import 'package:financas/app/tema.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/planejamento/cubit/ajustes_calculo_cubit.dart';
import 'package:financas/features/planejamento/cubit/editar_renda_cubit.dart';
import 'package:financas/features/planejamento/cubit/planejamento_cubit.dart';
import 'package:financas/features/planejamento/data/planejamento.dart';
import 'package:financas/features/planejamento/ui/ajustes_calculo_tela.dart';
import 'package:financas/features/planejamento/ui/editar_renda_tela.dart';
import 'package:financas/features/planejamento/ui/planejamento_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/contas_falso.dart';
import '../../apoio/planejamento_falso.dart';

void main() {
  late ContasRepositorioFalso contas;
  late PlanejamentoRepositorioFalso planejamento;

  setUp(() {
    contas = ContasRepositorioFalso(
      contas: [
        contaExemplo(),
        contaExemplo(id: 'w1', nome: 'Carteira', tipo: TipoConta.carteira),
        cartaoExemplo(),
      ],
    );
    planejamento = PlanejamentoRepositorioFalso(
      rendas: [
        rendaExemplo(),
        freelaExemplo(),
        rendaExemplo(
          id: 'r3',
          descricao: 'Aulas particulares',
          valor: '350.00',
          dia: 5,
          contaId: 'w1',
          ativa: false,
        ),
      ],
      leitura: leituraExemplo(),
    );
  });

  void telaAlta(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> abrirLista(WidgetTester tester, {ThemeData? tema}) async {
    telaAlta(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: tema ?? temaClaro(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ContasCubit(contas)..carregar()),
            BlocProvider(
              create: (_) => PlanejamentoCubit(planejamento)..carregar(),
            ),
          ],
          child: const PlanejamentoTela(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Planejamento', () {
    testWidgets('lista as rendas com a próxima data e o motivo', (
      tester,
    ) async {
      await abrirLista(tester);

      expect(find.text('Rendas previstas'), findsOneWidget);
      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('R\$ 4.200,00'), findsOneWidget);
      expect(find.text('Dia 10 · Conta principal'), findsOneWidget);
      expect(find.text('Próxima: terça, 10 nov'), findsOneWidget);
      expect(
        find.text('Próxima: segunda, 16 nov (dia 15 é domingo e feriado)'),
        findsOneWidget,
      );
      // Inativa: com selo e sem próxima data.
      expect(find.text('Dia 5 · Carteira'), findsOneWidget);
      expect(find.text('Inativa'), findsOneWidget);
      expect(find.textContaining('5 nov'), findsNothing);
      expect(find.text('Adicionar renda'), findsOneWidget);
      expect(find.text('Para começar'), findsNothing);
    });

    testWidgets('mostra a configuração com o automático e os meses de hoje', (
      tester,
    ) async {
      await abrirLista(tester);

      expect(find.text('Aporte e reserva'), findsOneWidget);
      expect(find.text('R\$ 500,00'), findsOneWidget);
      expect(find.text('R\$ 40,00 por dia'), findsOneWidget);
      expect(find.text('R\$ 280,00'), findsOneWidget);
      expect(find.text('Hoje: 4,2 meses'), findsOneWidget);
      expect(find.text('6 meses'), findsOneWidget);
      expect(find.text('Automático: média de jul a set'), findsOneWidget);
      expect(find.text('R\$ 3.000,00'), findsOneWidget);
    });

    testWidgets('valor fixo aparece como fixo', (tester) async {
      planejamento.leitura = leituraExemplo(mensalFixo: '3200.00');
      await abrirLista(tester);

      expect(find.text('Valor fixo'), findsOneWidget);
      expect(find.text('R\$ 3.200,00'), findsOneWidget);
    });

    testWidgets('primeira vez: os dois passos e a lista vazia', (tester) async {
      planejamento = PlanejamentoRepositorioFalso();
      await abrirLista(tester);

      expect(find.text('Para começar'), findsOneWidget);
      expect(find.text('Cadastre sua renda'), findsOneWidget);
      expect(find.text('Defina colchão e gastos'), findsOneWidget);
      expect(
        find.text(
          'Nenhuma renda cadastrada. Sem ela, o Início mostra só o saldo '
          'disponível.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Adicionar renda'), findsOne);
      expect(find.widgetWithText(OutlinedButton, 'Definir'), findsOne);
      expect(find.text('Aporte e reserva'), findsNothing);
    });

    testWidgets('com renda e sem configuração, o passo 1 aparece feito', (
      tester,
    ) async {
      planejamento = PlanejamentoRepositorioFalso(rendas: [rendaExemplo()]);
      await abrirLista(tester);

      expect(find.text('Para começar'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Adicionar renda'),
        findsNothing,
      );
      expect(find.text('Próxima: terça, 10 nov'), findsOneWidget);
    });

    testWidgets('erro ao carregar oferece tentar de novo', (tester) async {
      planejamento.erro = const ErroApi('Sem conexão com o servidor.');
      await abrirLista(tester);

      expect(find.text('Não deu para carregar'), findsOneWidget);
      planejamento.erro = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(find.text('Salário'), findsOneWidget);
    });

    testWidgets('tema escuro desenha sem erro', (tester) async {
      await abrirLista(tester, tema: temaEscuro());

      expect(find.text('Freela mensal'), findsOneWidget);
    });
  });

  group('Nova e Editar renda', () {
    Future<void> abrir(WidgetTester tester, {Renda? existente}) async {
      telaAlta(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: temaClaro(),
          home: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => ContasCubit(contas)..carregar()),
              BlocProvider(
                create: (_) =>
                    EditarRendaCubit(planejamento, existente: existente),
              ),
            ],
            child: EditarRendaTela(existente: existente),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Nova renda mostra os quatro erros de uma vez', (tester) async {
      await abrir(tester);

      expect(find.text('Nova renda'), findsOneWidget);
      expect(find.text('Renda ativa'), findsNothing);
      await tester.tap(find.text('Salvar renda'));
      await tester.pumpAndSettle();

      expect(
        find.text('Dê um nome à renda, por exemplo: Salário.'),
        findsOneWidget,
      );
      expect(find.text('O valor precisa ser maior que zero.'), findsOneWidget);
      expect(find.text('Use um dia de 1 a 31.'), findsOneWidget);
      expect(
        find.text('Escolha a conta corrente ou a carteira onde a renda cai.'),
        findsOneWidget,
      );
      expect(planejamento.criadas, isEmpty);
    });

    testWidgets('a conta só oferece corrente e carteira ativas', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.text('Escolha a conta'));
      await tester.pumpAndSettle();

      expect(find.text('Conta principal'), findsOneWidget);
      expect(find.text('Carteira'), findsOneWidget);
      expect(find.text('Cartão Exemplo'), findsNothing);
    });

    testWidgets('digitar o dia mostra a próxima data', (tester) async {
      await abrir(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Dia previsto'),
        '12',
      );
      await tester.pumpAndSettle();

      expect(find.text('Próxima data: quinta, 12 nov'), findsOneWidget);
      expect(planejamento.previas, [12]);
    });

    testWidgets('Nova renda salva com os campos preenchidos', (tester) async {
      await abrir(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Descrição'),
        'Freela',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '600');
      await tester.enterText(
        find.widgetWithText(TextField, 'Dia previsto'),
        '15',
      );
      await tester.tap(find.text('Escolha a conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carteira').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar renda'));
      await tester.pumpAndSettle();

      expect(
        planejamento.criadas.single,
        DadosRenda(
          descricao: 'Freela',
          valor: Decimal.parse('600'),
          diaPrevisto: 15,
          contaId: 'w1',
        ),
      );
    });

    testWidgets('Editar renda vem preenchida e desativa pelo interruptor', (
      tester,
    ) async {
      await abrir(tester, existente: freelaExemplo());

      expect(find.text('Editar renda'), findsOneWidget);
      expect(find.text('Freela mensal'), findsOneWidget);
      expect(find.text('600,00'), findsOneWidget);
      expect(find.text('Conta principal · Banco Exemplo'), findsOneWidget);
      expect(
        find.text('Próxima data: segunda, 16 nov (dia 15 é domingo e feriado)'),
        findsOneWidget,
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final editada = planejamento.editadas.single;
      expect(editada.id, 'r2');
      expect(editada.dados.ativa, isFalse);
    });
  });

  group('Aporte e reserva', () {
    Future<void> abrir(WidgetTester tester, LeituraConfiguracao leitura) async {
      telaAlta(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: temaClaro(),
          home: BlocProvider(
            create: (_) => AjustesCalculoCubit(planejamento, leitura),
            child: AjustesCalculoTela(leitura: leitura),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('vem preenchido e explica cada campo', (tester) async {
      await abrir(tester, leituraExemplo());

      expect(find.text('500,00'), findsOneWidget);
      expect(find.text('280,00'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(
        find.text(
          'R\$ 40,00 por dia. É o mínimo usado nos gastos previstos: com 4 '
          'semanas de histórico, vale o maior entre ele e a média real (hoje '
          'R\$ 252,00 por semana).',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Em meses de gasto. Hoje a reserva cobre 4,2 meses.'),
        findsOneWidget,
      );
      expect(find.text('Média de jul, ago e set'), findsOneWidget);
      expect(find.text('R\$ 3.000,00'), findsOneWidget);
    });

    testWidgets('primeira vez: campos vazios e sem histórico', (tester) async {
      await abrir(tester, const LeituraConfiguracao());

      expect(
        find.text(
          'É o mínimo usado nos gastos previstos: com 4 semanas de '
          'histórico, vale o maior entre ele e a média real.',
        ),
        findsOneWidget,
      );
      expect(find.text('Em meses de gasto.'), findsOneWidget);
      expect(
        find.text('Ainda não há um mês fechado inteiro no histórico.'),
        findsOneWidget,
      );
    });

    testWidgets('valor fixo pede o valor e salva', (tester) async {
      await abrir(tester, leituraExemplo());

      await tester.tap(find.text('Valor fixo'));
      await tester.pumpAndSettle();
      expect(find.text('Média de jul, ago e set'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Gasto mensal fixo'),
        '3.200,00',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(
        planejamento.configuracoesSalvas.single.gastoMensalReferencia,
        Decimal.parse('3200'),
      );
    });
  });
}
