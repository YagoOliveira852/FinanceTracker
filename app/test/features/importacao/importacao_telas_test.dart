import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:financas/app/app.dart';
import 'package:financas/app/injecao.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/importacao/data/importacao.dart';
import 'package:financas/features/importacao/data/importacoes_repositorio.dart';
import 'package:flutter/material.dart';
import 'package:financas/app/widgets/campos.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/auth_falso.dart';
import '../../apoio/categorias_falso.dart';
import '../../apoio/contas_falso.dart';
import '../../apoio/faturas_falso.dart';
import '../../apoio/importacoes_falso.dart';
import '../../apoio/preferencia_tema_falsa.dart';
import '../../apoio/revisao_falso.dart';
import '../../apoio/transacoes_falso.dart';

/// O app inteiro com repositórios falsos, já em Mais → Importar extrato.
Future<void> _abrirImportar(
  WidgetTester tester,
  ImportacoesRepositorioFalso importacoes, {
  SeletorArquivoFalso? seletor,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final dependencias = Dependencias(
    auth: AuthRepositorioFalso(sessao: true),
    contas: ContasRepositorioFalso(contas: [contaExemplo(), cartaoExemplo()]),
    transacoes: TransacoesRepositorioFalso(),
    faturas: FaturasRepositorioFalso(),
    categorias: CategoriasRepositorioFalso(),
    revisao: RevisaoRepositorioFalso(),
    importacoes: importacoes,
    seletorArquivo: seletor ?? SeletorArquivoFalso(arquivoExemplo()),
    compartilhamento: FonteCompartilhamentoFalsa(),
    preferenciaTema: PreferenciaTemaFalsa(),
  );
  await dependencias.sessao.iniciar();
  await tester.pumpWidget(FinancasApp(dependencias));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mais'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Importar extrato'));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('primeira vez: escolher arquivo, conta vazia e sem histórico', (
    tester,
  ) async {
    await _abrirImportar(tester, ImportacoesRepositorioFalso());

    expect(find.text('Escolher arquivo'), findsOneWidget);
    expect(
      find.text('Depois de escolher o arquivo, o app sugere a conta.'),
      findsOneWidget,
    );
    expect(find.textContaining('Nenhum extrato importado ainda'), findsOne);
    final importar = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Importar'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(importar.onPressed, isNull);
  });

  testWidgets('arquivo escolhido: conta sugerida e histórico', (tester) async {
    await _abrirImportar(
      tester,
      ImportacoesRepositorioFalso(
        historico: [importacaoDeFaturaExemplo(), importacaoExemplo()],
      ),
    );

    await _tocar(tester, find.text('Escolher arquivo'));

    expect(find.text('extrato-outubro.ofx'), findsOneWidget);
    expect(find.text('OFX · 1 KB'), findsOneWidget);
    expect(find.text('Conta principal · Banco Exemplo'), findsOneWidget);
    expect(
      find.text('A mesma da última importação de OFX de conta.'),
      findsOneWidget,
    );
    expect(find.text('fatura-outubro.ofx'), findsOneWidget);
    expect(find.text('Cartão Exemplo · 6 out'), findsOneWidget);
    expect(find.text('21 novas'), findsOneWidget);
  });

  testWidgets('importa e abre o resumo do extrato; Ir para a Revisão', (
    tester,
  ) async {
    final importacoes = ImportacoesRepositorioFalso(
      historico: [importacaoExemplo()],
    );
    await _abrirImportar(tester, importacoes);
    await _tocar(tester, find.text('Escolher arquivo'));

    await _tocar(tester, find.text('Importar'));

    expect(importacoes.enviados.single.contaId, 'c1');
    expect(find.text('Extrato importado'), findsOneWidget);
    expect(find.text('38 rascunhos na Revisão'), findsOneWidget);
    expect(find.text('Novas'), findsOneWidget);
    expect(find.text('Possíveis duplicatas'), findsOneWidget);
    expect(find.text('Já importadas'), findsOneWidget);
    expect(find.text('Saldo no extrato'), findsOneWidget);
    expect(find.text('R\$ 2.340,15'), findsOneWidget);
    expect(find.text('Desfazer importação'), findsOneWidget);

    await _tocar(tester, find.text('Ir para a Revisão'));
    expect(find.text('3 para revisar'), findsOneWidget);
  });

  testWidgets('mostra o processando enquanto envia', (tester) async {
    final importacoes = ImportacoesRepositorioFalso()..segurar = Completer();
    await _abrirImportar(tester, importacoes);
    await _tocar(tester, find.text('Escolher arquivo'));
    await tester.tap(find.byType(CampoSelecao<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conta principal').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar'));
    await tester.pump();

    expect(find.text('Importando extrato-outubro.ofx'), findsOneWidget);
    importacoes.segurar!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Extrato importado'), findsOneWidget);
  });

  testWidgets('desfazer pede confirmação e volta ao formulário', (
    tester,
  ) async {
    final importacoes = ImportacoesRepositorioFalso(
      historico: [importacaoExemplo()],
    );
    await _abrirImportar(tester, importacoes);
    await _tocar(tester, find.text('Escolher arquivo'));
    await _tocar(tester, find.text('Importar'));

    await _tocar(tester, find.text('Desfazer importação'));
    expect(find.text('Desfazer a importação?'), findsOneWidget);
    expect(find.textContaining('saem da Revisão'), findsOneWidget);
    await _tocar(tester, find.widgetWithText(FilledButton, 'Desfazer'));

    expect(importacoes.desfeitas, ['nova']);
    expect(find.text('Importação desfeita.'), findsOneWidget);
    expect(find.text('Importar extrato'), findsOneWidget);
  });

  testWidgets('resumo da fatura pelo histórico, sem desfazer', (tester) async {
    final fatura = importacaoDeFaturaExemplo().copyWith(
      qtdConfirmadas: 12,
      qtdPendentes: 9,
      podeDesfazer: false,
    );
    await _abrirImportar(
      tester,
      ImportacoesRepositorioFalso(historico: [fatura]),
    );

    await _tocar(tester, find.text('fatura-outubro.ofx'));

    expect(find.text('Importação de 6 out'), findsOneWidget);
    expect(find.text('12 já confirmadas, 9 ainda na Revisão'), findsOneWidget);
    expect(find.text('Parcelas'), findsOneWidget);
    expect(find.text('Fatura de outubro'), findsOneWidget);
    expect(find.text('R\$ 1.032,15'), findsOneWidget);
    expect(
      find.textContaining('Não dá mais para desfazer: 12 transações'),
      findsOneWidget,
    );
    expect(find.text('Revisar as 9 pendentes'), findsOneWidget);
    expect(find.text('Desfazer importação'), findsNothing);
  });

  testWidgets('arquivo já importado: aviso com Ver importação', (tester) async {
    final anterior = importacaoExemplo(qtdNovas: 41);
    await _abrirImportar(
      tester,
      ImportacoesRepositorioFalso(
        historico: [anterior],
        resultado: ResultadoImportacao(jaImportada: true, importacao: anterior),
      ),
    );
    await _tocar(tester, find.text('Escolher arquivo'));

    await _tocar(tester, find.text('Importar'));

    expect(
      find.textContaining(
        'Este arquivo já foi importado em 2 out, na Conta principal, com 41 novas.',
      ),
      findsOneWidget,
    );
    await _tocar(tester, find.text('Ver importação'));
    expect(find.text('Importação de 2 out'), findsOneWidget);
  });

  testWidgets('FITID repetido: aviso e as linhas', (tester) async {
    final linha = LinhaRepetida(
      fitid: '7c1e0000-0000-4000-8000-00000000a42f',
      data: DateTime(2026, 10, 12),
      valor: Decimal.parse('-64.90'),
      descricao: 'Mercado do Bairro',
    );
    await _abrirImportar(
      tester,
      ImportacoesRepositorioFalso(
        historico: [importacaoExemplo()],
        erroImportar: ErroFitidRepetido('Nada foi importado.', [linha, linha]),
      ),
    );
    await _tocar(tester, find.text('Escolher arquivo'));

    await _tocar(tester, find.text('Importar'));

    expect(
      find.textContaining('O arquivo tem 2 lançamentos com o mesmo'),
      findsOneWidget,
    );
    expect(find.text('Mercado do Bairro'), findsNWidgets(2));
    expect(find.text('12 out · id 7c1e…a42f'), findsNWidgets(2));
    expect(find.textContaining('Baixe o extrato de novo'), findsOneWidget);
  });

  testWidgets('conta incompatível: erro no campo da conta', (tester) async {
    await _abrirImportar(
      tester,
      ImportacoesRepositorioFalso(
        historico: [importacaoExemplo()],
        erroImportar: const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {
            'conta_id': 'Este OFX é de fatura de cartão. Escolha um cartão.',
          },
        ),
      ),
    );
    await _tocar(tester, find.text('Escolher arquivo'));

    await _tocar(tester, find.text('Importar'));

    expect(
      find.text('Este OFX é de fatura de cartão. Escolha um cartão.'),
      findsOneWidget,
    );
  });

  testWidgets('formato não reconhecido: aviso do arquivo', (tester) async {
    await _abrirImportar(
      tester,
      ImportacoesRepositorioFalso(
        historico: [importacaoExemplo()],
        erroImportar: const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {'arquivo': 'Não reconheci este arquivo: não é um OFX.'},
        ),
      ),
    );
    await _tocar(tester, find.text('Escolher arquivo'));

    await _tocar(tester, find.text('Importar'));

    expect(
      find.textContaining('Não reconheci este arquivo: não é um OFX.'),
      findsOneWidget,
    );
  });
}
