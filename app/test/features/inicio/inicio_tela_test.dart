import 'package:financas/app/tema.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/inicio/cubit/inicio_cubit.dart';
import 'package:financas/features/inicio/ui/inicio_tela.dart';
import 'package:financas/features/planejamento/data/resumo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/aporte_dispensado_falso.dart';
import '../../apoio/contas_falso.dart';
import '../../apoio/planejamento_falso.dart';

/// Os estados do design "Início": no ritmo, atenção, risco, salário chegou e
/// sem salário cadastrado (valores fictícios).
void main() {
  late PlanejamentoRepositorioFalso planejamento;
  late AporteDispensadoFalso dispensado;

  setUp(() {
    planejamento = PlanejamentoRepositorioFalso();
    dispensado = AporteDispensadoFalso();
  });

  Future<void> abrir(
    WidgetTester tester,
    Resumo resumo, {
    DateTime? hoje,
    ThemeData? tema,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    planejamento.resumo = resumo;
    await tester.pumpWidget(
      MaterialApp(
        theme: tema ?? temaClaro(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  ContasCubit(ContasRepositorioFalso(contas: [contaExemplo()]))
                    ..carregar(),
            ),
            BlocProvider(
              create: (_) => InicioCubit(
                planejamento,
                dispensado,
                hoje: () => hoje ?? DateTime(2026, 10, 20),
              )..carregar(),
            ),
          ],
          child: const InicioTela(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no ritmo: sobra, chip, conta, rascunhos e reserva', (
    tester,
  ) async {
    await abrir(tester, resumoComPrevisao());

    expect(find.text('Terça, 20 de outubro'), findsOneWidget);
    expect(find.text('Sobra prevista até o salário'), findsOneWidget);
    expect(find.text('No ritmo'), findsOneWidget);
    expect(find.text('R\$ 1.307,95'), findsOneWidget);
    expect(
      find.text(
        'Salário previsto para terça, 10 nov. A sobra cobre o colchão de '
        'R\$ 500,00.',
      ),
      findsOneWidget,
    );
    expect(find.text('Saldo disponível'), findsOneWidget);
    expect(find.text('R\$ 3.180,10'), findsOneWidget);
    expect(find.text('Fatura Cartão Exemplo · vence 10 nov'), findsOneWidget);
    expect(find.text('− R\$ 1.032,15'), findsOneWidget);
    expect(find.text('Gastos previstos · 21 dias'), findsOneWidget);
    expect(find.text('− R\$ 840,00'), findsOneWidget);
    expect(find.text('Considera 2 rascunhos não revisados'), findsOneWidget);
    expect(find.text('Revisar'), findsOneWidget);
    expect(find.text('Reserva de emergência'), findsOneWidget);
    expect(find.text('meta 6 meses'), findsOneWidget);
    expect(find.text('Em breve'), findsOneWidget);
  });

  testWidgets('atenção: a sobra não cobre o colchão, pela média recente', (
    tester,
  ) async {
    await abrir(tester, resumoComPrevisao(nivel: NivelRitmo.amarelo));

    expect(find.text('Atenção'), findsOneWidget);
    expect(find.text('R\$ 347,95'), findsOneWidget);
    expect(find.textContaining('faltam R\$ 152,05'), findsOneWidget);
    expect(
      find.text('Gastos previstos · 21 dias, pela média recente'),
      findsOneWidget,
    );
  });

  testWidgets('risco: sobra negativa em vermelho', (tester) async {
    await abrir(tester, resumoComPrevisao(nivel: NivelRitmo.vermelho));

    expect(find.text('Risco'), findsOneWidget);
    final sobra = tester.widget<Text>(find.text('− R\$ 252,05'));
    expect(sobra.style?.color, CoresFinancas.claro.ritmoRisco);
    expect(
      find.textContaining('seria preciso resgatar da reserva'),
      findsOneWidget,
    );
  });

  testWidgets('sem rascunhos, sem o aviso', (tester) async {
    await abrir(tester, resumoComPrevisao(rascunhos: 0));

    expect(find.textContaining('rascunho'), findsNothing);
  });

  testWidgets('sem salário cadastrado: convite e saldo oficial das contas', (
    tester,
  ) async {
    await abrir(tester, resumoSemSalario());

    expect(find.text('Cadastre seu salário'), findsOneWidget);
    expect(find.text('Cadastrar salário'), findsOneWidget);
    expect(find.text('Saldo disponível'), findsOneWidget);
    // O da aba Contas (só confirmadas), não o do cálculo.
    expect(find.text('R\$ 2.350,00'), findsOneWidget);
    expect(find.text('Sobra prevista até o salário'), findsNothing);
    expect(find.text('Reserva de emergência'), findsNothing);
    expect(find.textContaining('rascunho'), findsNothing);
  });

  testWidgets('salário chegou: aporte com a conta e o colchão', (tester) async {
    await abrir(tester, resumoSalarioRecebido(), hoje: DateTime(2026, 11, 10));

    expect(find.text('Terça, 10 de novembro'), findsOneWidget);
    expect(find.text('Salário recebido: você pode aportar'), findsOneWidget);
    expect(find.text('R\$ 2.319,80'), findsOneWidget);
    expect(
      find.text(
        'O salário de R\$ 4.200,00 caiu hoje na Conta principal. O resto fica '
        'na conta até o próximo salário, em 10 dez.',
      ),
      findsOneWidget,
    );
    expect(find.text('R\$ 5.430,10'), findsOneWidget);
    expect(find.text('Fatura Cartão Exemplo · vence 10 dez'), findsOneWidget);
    expect(find.text('Gastos previstos · 30 dias'), findsOneWidget);
    expect(find.text('Colchão na conta'), findsOneWidget);
    expect(find.text('− R\$ 500,00'), findsOneWidget);
    expect(find.text('Sobra prevista até o salário'), findsNothing);
  });

  testWidgets('"Registrar aporte" fica em breve', (tester) async {
    await abrir(tester, resumoSalarioRecebido(), hoje: DateTime(2026, 11, 10));

    final botao = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Registrar aporte'),
    );
    expect(botao.onPressed, isNull);
    expect(
      find.text('Registrar o aporte chega em breve, com os investimentos.'),
      findsOneWidget,
    );
  });

  testWidgets('"Agora não" volta à sobra e guarda a dispensa', (tester) async {
    await abrir(tester, resumoSalarioRecebido(), hoje: DateTime(2026, 11, 10));

    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();

    expect(find.text('Salário recebido: você pode aportar'), findsNothing);
    expect(find.text('Sobra prevista até o salário'), findsOneWidget);
    expect(find.text('R\$ 2.819,80'), findsOneWidget);
    expect(dispensado.chave, 'r1:2026-11-10');
  });

  testWidgets('salário chegou sem sobra acima do colchão: o alerta assume', (
    tester,
  ) async {
    await abrir(
      tester,
      resumoSalarioRecebido(aporte: '0.00'),
      hoje: DateTime(2026, 11, 10),
    );

    expect(find.text('Salário recebido: você pode aportar'), findsNothing);
    expect(find.text('Sobra prevista até o salário'), findsOneWidget);
  });

  testWidgets('erro mostra a mensagem e tenta de novo', (tester) async {
    planejamento.erro = const ErroApi('Sem conexão com o servidor.');
    await abrir(tester, resumoComPrevisao());

    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);

    planejamento.erro = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Sobra prevista até o salário'), findsOneWidget);
  });

  testWidgets('tema escuro: os mesmos estados renderizam', (tester) async {
    await abrir(
      tester,
      resumoComPrevisao(nivel: NivelRitmo.vermelho),
      tema: temaEscuro(),
    );

    final sobra = tester.widget<Text>(find.text('− R\$ 252,05'));
    expect(sobra.style?.color, CoresFinancas.escuro.ritmoRisco);
  });
}
