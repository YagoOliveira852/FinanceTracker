import 'package:bloc_test/bloc_test.dart';
import 'package:decimal/decimal.dart';
import 'package:financas/app/tema.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/contas/cubit/editar_cartao_cubit.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/contas/data/contas_repositorio.dart';
import 'package:financas/features/contas/ui/editar_cartao_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';
import '../../apoio/contas_falso.dart';

void main() {
  late ContasRepositorioFalso repositorio;

  setUp(
    () => repositorio = ContasRepositorioFalso(
      contas: [contaExemplo(), cartaoExemplo()],
    ),
  );

  test('editarCartao manda PUT com os campos e ativa', () async {
    final adaptador = AdaptadorFalso(
      (_) => (status: 422, corpo: {'detail': 'Dados inválidos.'}),
    );
    final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
    cliente.dio.httpClientAdapter = adaptador;

    await expectLater(
      ContasRepositorioApi(cliente).editarCartao(
        'k1',
        const EdicaoCartao(
          nome: 'Cartão Exemplo',
          instituicao: 'Banco Exemplo',
          contaPagamentoId: 'c1',
          diaFechamento: 20,
          diaVencimento: 27,
          ativa: false,
        ),
      ),
      throwsA(isA<ErroApi>()),
    );

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.method, 'PUT');
    expect(requisicao.path, '/cartoes/k1');
    expect(corpoDe(requisicao), {
      'nome': 'Cartão Exemplo',
      'instituicao': 'Banco Exemplo',
      'conta_pagamento_id': 'c1',
      'dia_fechamento': 20,
      'dia_vencimento': 27,
      // Sem limite, o campo vai omitido: na API isso apaga o limite.
      'ativa': false,
    });
  });

  group('EditarCartaoCubit', () {
    EditarCartaoCubit criar() =>
        EditarCartaoCubit(repositorio, cartaoExemplo());

    blocTest<EditarCartaoCubit, EditarCartaoEstado>(
      'valida como o cadastro',
      build: criar,
      act: (cubit) => cubit.salvar(
        nome: '',
        instituicao: 'Banco Exemplo',
        contaPagamentoId: 'c1',
        diaFechamento: '10',
        diaVencimento: '10',
        limite: '',
      ),
      expect: () => [
        const EditarCartaoEstado(
          erros: {
            'nome': 'Dê um nome ao cartão, por exemplo: Cartão principal.',
            'dia_vencimento':
                'O vencimento precisa ser num dia diferente do fechamento.',
          },
        ),
      ],
      verify: (_) => expect(repositorio.cartoesEditados, isEmpty),
    );

    blocTest<EditarCartaoCubit, EditarCartaoEstado>(
      'salva os dados mantendo o cartão ativo',
      build: criar,
      act: (cubit) => cubit.salvar(
        nome: 'Cartão do dia a dia',
        instituicao: 'Banco Exemplo',
        contaPagamentoId: 'c1',
        diaFechamento: '20',
        diaVencimento: '27',
        limite: '',
      ),
      skip: 1,
      expect: () => [
        isA<EditarCartaoEstado>().having((e) => e.salva, 'salva', isNotNull),
      ],
      verify: (_) => expect(repositorio.cartoesEditados.single, (
        contaId: 'k1',
        dados: const EdicaoCartao(
          nome: 'Cartão do dia a dia',
          instituicao: 'Banco Exemplo',
          contaPagamentoId: 'c1',
          diaFechamento: 20,
          diaVencimento: 27,
          ativa: true,
        ),
      )),
    );

    blocTest<EditarCartaoCubit, EditarCartaoEstado>(
      'desativar manda os dados atuais com ativa falso',
      build: criar,
      act: (cubit) => cubit.mudarAtivo(false),
      skip: 1,
      expect: () => [
        isA<EditarCartaoEstado>().having((e) => e.salva, 'salva', isNotNull),
      ],
      verify: (_) {
        final edicao = repositorio.cartoesEditados.single.dados;
        expect(edicao.ativa, isFalse);
        expect(edicao.diaFechamento, 3);
        expect(edicao.limite, Decimal.parse('3000.00'));
      },
    );

    blocTest<EditarCartaoCubit, EditarCartaoEstado>(
      'dias que inverteriam a ordem: erro do servidor no campo',
      build: () {
        repositorio.erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {
            'dia_fechamento':
                'Com esses dias, a próxima fatura fecharia antes da atual.',
          },
        );
        return criar();
      },
      act: (cubit) => cubit.salvar(
        nome: 'Cartão Exemplo',
        instituicao: 'Banco Exemplo',
        contaPagamentoId: 'c1',
        diaFechamento: '2',
        diaVencimento: '1',
        limite: '',
      ),
      skip: 1,
      expect: () => [
        const EditarCartaoEstado(
          erros: {
            'dia_fechamento':
                'Com esses dias, a próxima fatura fecharia antes da atual.',
          },
        ),
      ],
    );
  });

  Widget tela(Conta cartao) => MaterialApp(
    theme: temaClaro(),
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ContasCubit(repositorio)..carregar()),
        BlocProvider(create: (_) => EditarCartaoCubit(repositorio, cartao)),
      ],
      child: EditarCartaoTela(conta: cartao),
    ),
  );

  void telaAlta(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('Editar cartão vem preenchido e avisa sobre os dias', (
    tester,
  ) async {
    telaAlta(tester);
    await tester.pumpWidget(tela(cartaoExemplo()));
    await tester.pumpAndSettle();

    expect(find.text('Editar cartão'), findsOneWidget);
    expect(find.text('Cartão Exemplo'), findsOneWidget);
    expect(find.text('Conta principal · Banco Exemplo'), findsOneWidget);
    expect(find.text('3.000,00'), findsOneWidget);
    expect(
      find.text(
        'Dias novos valem a partir da próxima fatura (dezembro); a de '
        'novembro mantém as datas.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Desativar com fatura em aberto pede confirmação', (
    tester,
  ) async {
    telaAlta(tester);
    await tester.pumpWidget(tela(cartaoExemplo()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Desativar cartão').last,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final desativar = find.widgetWithText(OutlinedButton, 'Desativar cartão');
    await tester.ensureVisible(desativar);
    await tester.pumpAndSettle();
    await tester.tap(desativar);
    await tester.pumpAndSettle();

    expect(find.text('Desativar o Cartão Exemplo?'), findsOneWidget);
    expect(
      find.text(
        'A fatura de novembro está aberta com R\$ 544,80. Ela continua '
        'visível em Contas, mas o cartão não recebe compras novas até ser '
        'reativado.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Desativar'));
    await tester.pumpAndSettle();

    expect(repositorio.cartoesEditados.single.dados.ativa, isFalse);
  });

  testWidgets('Cartão desativado oferece reativar', (tester) async {
    telaAlta(tester);
    await tester.pumpWidget(tela(cartaoExemplo(ativa: false)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Reativar cartão'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Reativar cartão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reativar cartão'));
    await tester.pumpAndSettle();

    expect(repositorio.cartoesEditados.single.dados.ativa, isTrue);
  });
}
