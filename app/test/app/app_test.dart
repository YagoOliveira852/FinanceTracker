import 'package:financas/app/app.dart';
import 'package:financas/app/injecao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../apoio/auth_falso.dart';
import '../apoio/categorias_falso.dart';
import '../apoio/contas_falso.dart';
import '../apoio/faturas_falso.dart';
import '../apoio/importacoes_falso.dart';
import '../apoio/notificador_falso.dart';
import '../apoio/planejamento_falso.dart';
import '../apoio/preferencia_tema_falsa.dart';
import '../apoio/revisao_falso.dart';
import '../apoio/transacoes_falso.dart';

/// App inteiro (router, abas, providers) com repositórios falsos.
Future<Dependencias> _abrir(
  WidgetTester tester, {
  bool sessao = true,
  ImportacoesRepositorioFalso? importacoes,
  FonteCompartilhamentoFalsa? compartilhamento,
  PreferenciaTemaFalsa? preferenciaTema,
  PlanejamentoRepositorioFalso? planejamento,
  NotificadorFalso? notificador,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final dependencias = Dependencias(
    auth: AuthRepositorioFalso(sessao: sessao),
    contas: ContasRepositorioFalso(contas: [contaExemplo()]),
    transacoes: TransacoesRepositorioFalso(),
    faturas: FaturasRepositorioFalso(),
    categorias: CategoriasRepositorioFalso(),
    revisao: RevisaoRepositorioFalso(),
    planejamento: planejamento ?? PlanejamentoRepositorioFalso(),
    importacoes: importacoes ?? ImportacoesRepositorioFalso(),
    seletorArquivo: SeletorArquivoFalso(arquivoExemplo()),
    compartilhamento: compartilhamento ?? FonteCompartilhamentoFalsa(),
    preferenciaTema: preferenciaTema ?? PreferenciaTemaFalsa(),
    notificador: notificador ?? NotificadorFalso(),
  );
  await Future.wait([
    dependencias.sessao.iniciar(),
    dependencias.tema.iniciar(),
  ]);
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

  testWidgets('com sessão, agenda os lembretes de salário ao abrir', (
    tester,
  ) async {
    final notificador = NotificadorFalso();
    await _abrir(
      tester,
      planejamento: PlanejamentoRepositorioFalso(rendas: [rendaExemplo()]),
      notificador: notificador,
    );

    expect(notificador.agendados.map((l) => l.quando), [
      DateTime(2026, 11, 10, 9),
    ]);
  });

  testWidgets('login leva ao Início e agenda os lembretes', (tester) async {
    final notificador = NotificadorFalso();
    await _abrir(
      tester,
      sessao: false,
      planejamento: PlanejamentoRepositorioFalso(rendas: [rendaExemplo()]),
      notificador: notificador,
    );
    expect(notificador.agendados, isEmpty);

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
    expect(notificador.agendados, hasLength(1));
  });

  testWidgets('tocar no lembrete com o app aberto volta ao Início', (
    tester,
  ) async {
    final notificador = NotificadorFalso();
    await _abrir(tester, notificador: notificador);
    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contas'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo disponível'), findsNothing);

    notificador.tocar();
    await tester.pumpAndSettle();

    expect(find.text('Saldo disponível'), findsOneWidget);
  });

  testWidgets('aba Revisão mostra o contador e a lista', (tester) async {
    await _abrir(tester);

    final contador = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(Badge),
    );
    expect(
      find.descendant(of: contador.first, matching: find.text('3')),
      findsOneWidget,
    );

    await tester.tap(find.text('Revisão'));
    await tester.pumpAndSettle();
    expect(find.text('3 para revisar'), findsOneWidget);
    expect(find.text('Padaria Pão Quente'), findsOneWidget);
  });

  testWidgets('a folha do rascunho cobre a barra de abas', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Revisão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Padaria Pão Quente'));
    await tester.pumpAndSettle();

    expect(find.text('Como veio do banco'), findsOneWidget);
    expect(
      tester.getRect(find.byType(ModalBarrier).last).bottom,
      tester.getRect(find.byType(NavigationBar)).bottom,
    );
  });

  testWidgets('Mais → Contas, com itens em breve visíveis', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    expect(find.text('Open Finance'), findsOneWidget);
    expect(find.text('Em breve'), findsNWidgets(4));

    await tester.tap(find.text('Contas'));
    await tester.pumpAndSettle();
    expect(find.text('Total disponível'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('Transações → Lançar → Transferência abre o formulário', (
    tester,
  ) async {
    final dependencias = await _abrir(tester);
    (dependencias.transacoes as TransacoesRepositorioFalso).transacoes.add(
      transacaoExemplo(data: DateTime.now()),
    );

    await tester.tap(find.text('Transações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferência'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputDecorator, 'De'), findsOneWidget);
    expect(find.widgetWithText(InputDecorator, 'Para'), findsOneWidget);
  });

  testWidgets('Pagamento sem cartão: cadastrar o cartão e voltar ao '
      'formulário com ele', (tester) async {
    final dependencias = await _abrir(tester);
    (dependencias.transacoes as TransacoesRepositorioFalso).transacoes.add(
      transacaoExemplo(data: DateTime.now()),
    );
    await tester.tap(find.text('Transações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagamento de fatura'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cadastrar cartão'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome do cartão'),
      'Cartão Exemplo',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Instituição'),
      'Banco Exemplo',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Dia de fechamento'),
      '3',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Dia de vencimento'),
      '10',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar cartão'));
    await tester.pumpAndSettle();

    // De volta ao pagamento, já com o cartão novo.
    expect(find.text('Nova transação'), findsOneWidget);
    expect(find.text('Cadastrar cartão'), findsNothing);
    expect(find.text('Cartão Exemplo · Banco Exemplo'), findsOneWidget);
  });

  testWidgets('Mais → Categorias e regras: editar e voltar à lista nova', (
    tester,
  ) async {
    await _abrir(tester);

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    // O item fica atrás da barra de navegação: rola até ele antes do toque.
    await tester.drag(find.text('Contas'), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categorias e regras'));
    await tester.pumpAndSettle();
    expect(find.text('Essencial'), findsOneWidget);

    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();
    expect(find.text('Editar categoria'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Feira');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Categorias e regras'), findsOneWidget);
    expect(find.text('Feira'), findsOneWidget);
    expect(find.text('Mercado'), findsNothing);
  });

  testWidgets('Mais → Planejamento: primeira renda, volta à lista e agenda o '
      'lembrete', (tester) async {
    final notificador = NotificadorFalso();
    await _abrir(tester, notificador: notificador);
    expect(notificador.agendados, isEmpty);

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Contas'), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planejamento'));
    await tester.pumpAndSettle();
    expect(find.text('Para começar'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar renda'));
    await tester.pumpAndSettle();
    expect(find.text('Nova renda'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Descrição'),
      'Salário',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '4.200,00');
    await tester.enterText(
      find.widgetWithText(TextField, 'Dia previsto'),
      '10',
    );
    await tester.tap(find.text('Escolha a conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conta principal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar renda'));
    await tester.pumpAndSettle();

    expect(find.text('Planejamento'), findsOneWidget);
    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Próxima: terça, 10 nov'), findsOneWidget);
    expect(notificador.agendados.map((l) => l.corpo), [
      'Salário: veja quanto aportar e o ritmo dos gastos.',
    ]);
  });

  testWidgets('abre no tema guardado', (tester) async {
    await _abrir(tester, preferenciaTema: PreferenciaTemaFalsa(ThemeMode.dark));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('Mais → Aparência troca o tema e guarda a escolha', (
    tester,
  ) async {
    final preferencia = PreferenciaTemaFalsa();
    await _abrir(tester, preferenciaTema: preferencia);

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    // Até o Sair, logo abaixo: assim a Aparência sai de baixo da barra de abas.
    await tester.scrollUntilVisible(find.text('Sair'), 200);
    expect(find.text('Tema: Do sistema'), findsOneWidget);

    await tester.tap(find.text('Aparência'));
    await tester.pumpAndSettle();
    // A folha cobre a barra de abas: o fundo escurecido vai até embaixo.
    expect(
      tester.getRect(find.byType(ModalBarrier).last).bottom,
      tester.getRect(find.byType(NavigationBar)).bottom,
    );
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(preferencia.modo, ThemeMode.dark);
    expect(find.text('Tema: Escuro'), findsOneWidget);
    expect(find.byType(RadioListTile<ThemeMode>), findsNothing);
  });

  testWidgets('Sair volta ao login e cancela os lembretes', (tester) async {
    final notificador = NotificadorFalso();
    await _abrir(
      tester,
      planejamento: PlanejamentoRepositorioFalso(rendas: [rendaExemplo()]),
      notificador: notificador,
    );

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sair'), 200);
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(find.text('Acesse suas finanças'), findsOneWidget);
    expect(find.textContaining('Sessão expirada.'), findsNothing);
    expect(notificador.cancelamentos, 1);
    expect(notificador.agendados, isEmpty);
  });

  testWidgets('sessão expirada leva ao login com o aviso e mantém os '
      'lembretes', (tester) async {
    final notificador = NotificadorFalso();
    final dependencias = await _abrir(
      tester,
      planejamento: PlanejamentoRepositorioFalso(rendas: [rendaExemplo()]),
      notificador: notificador,
    );

    dependencias.sessao.expirou();
    await tester.pumpAndSettle();

    expect(find.text('Acesse suas finanças'), findsOneWidget);
    expect(find.textContaining('Sessão expirada.'), findsOneWidget);
    expect(notificador.cancelamentos, 0);
    expect(notificador.agendados, hasLength(1));
  });

  testWidgets('Compartilhar um OFX abre a importação já preenchida', (
    tester,
  ) async {
    final compartilhamento = FonteCompartilhamentoFalsa();
    await _abrir(tester, compartilhamento: compartilhamento);

    compartilhamento.controlador.add(
      arquivoExemplo(nome: 'fatura-novembro.ofx', compartilhado: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Importar extrato'), findsOneWidget);
    expect(find.text('fatura-novembro.ofx'), findsOneWidget);
    expect(find.textContaining('Recebido pelo Compartilhar'), findsOneWidget);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo disponível'), findsOneWidget);
  });

  testWidgets('Compartilhar com a sessão expirada abre depois do login', (
    tester,
  ) async {
    final compartilhamento = FonteCompartilhamentoFalsa();
    await _abrir(tester, sessao: false, compartilhamento: compartilhamento);

    compartilhamento.controlador.add(arquivoExemplo(compartilhado: true));
    await tester.pumpAndSettle();
    expect(find.text('Acesse suas finanças'), findsOneWidget);

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

    expect(find.text('extrato-outubro.ofx'), findsOneWidget);
    expect(find.textContaining('Recebido pelo Compartilhar'), findsOneWidget);
  });

  testWidgets('Revisão → ícone de importar abre a importação', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Revisão'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Importar extrato'));
    await tester.pumpAndSettle();

    expect(find.text('Escolher arquivo'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('3 para revisar'), findsOneWidget);
  });
}
