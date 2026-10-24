import 'package:bloc_test/bloc_test.dart';
import 'package:decimal/decimal.dart';
import 'package:financas/app/tema.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/cubit/contas_cubit.dart';
import 'package:financas/features/faturas/cubit/editar_fatura_cubit.dart';
import 'package:financas/features/faturas/cubit/fatura_cubit.dart';
import 'package:financas/features/faturas/data/faturas_repositorio.dart';
import 'package:financas/features/faturas/ui/editar_fatura_tela.dart';
import 'package:financas/features/faturas/ui/fatura_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';
import '../../apoio/contas_falso.dart';
import '../../apoio/faturas_falso.dart';

Widget _app(Widget tela) => MaterialApp(
  theme: temaClaro(),
  home: BlocProvider(
    create: (_) => ContasCubit(
      ContasRepositorioFalso(contas: [contaExemplo(), cartaoExemplo()]),
    )..carregar(),
    child: tela,
  ),
);

void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  late FaturasRepositorioFalso repositorio;

  setUp(() => repositorio = FaturasRepositorioFalso());

  group('repositório', () {
    late AdaptadorFalso adaptador;
    late FaturasRepositorioApi api;

    setUp(() {
      adaptador = AdaptadorFalso(
        (_) => (status: 422, corpo: {'detail': 'Dados inválidos.'}),
      );
      final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
      cliente.dio.httpClientAdapter = adaptador;
      api = FaturasRepositorioApi(cliente);
    });

    test('editar manda as datas e o informado nulo', () async {
      await expectLater(
        api.editar(
          'k1',
          DateTime(2026, 10),
          dataFechamento: DateTime(2026, 10, 8),
          dataVencimento: DateTime(2026, 10, 13),
        ),
        throwsA(isA<ErroApi>()),
      );

      final requisicao = adaptador.requisicoes.single;
      expect(requisicao.method, 'PUT');
      expect(requisicao.path, '/cartoes/k1/faturas/2026-10');
      expect(corpoDe(requisicao), {
        'data_fechamento': '2026-10-08',
        'data_vencimento': '2026-10-13',
        'valor_informado': null,
      });
    });

    test('ajustar manda o valor real com duas casas', () async {
      await expectLater(
        api.ajustar(
          'k1',
          DateTime(2026, 10),
          valorReal: Decimal.parse('1032.15'),
          descricao: 'IOF não veio no extrato',
        ),
        throwsA(isA<ErroApi>()),
      );

      final requisicao = adaptador.requisicoes.single;
      expect(requisicao.path, '/cartoes/k1/faturas/2026-10/ajuste');
      expect(corpoDe(requisicao), {
        'valor_real': '1032.15',
        'descricao': 'IOF não veio no extrato',
      });
    });
  });

  group('EditarFaturaCubit', () {
    EditarFaturaCubit criar() =>
        EditarFaturaCubit(repositorio, 'k1', DateTime(2026, 10));

    blocTest<EditarFaturaCubit, EditarFaturaEstado>(
      'valida vencimento e valor no aparelho',
      build: criar,
      act: (cubit) => cubit.salvar(
        dataFechamento: DateTime(2026, 10, 13),
        dataVencimento: DateTime(2026, 10, 13),
        valorInformado: '-1,00',
      ),
      expect: () => [
        const EditarFaturaEstado(
          erros: {
            'data_vencimento': 'O vencimento precisa ser depois do fechamento.',
            'valor_informado': 'O valor não pode ser negativo.',
          },
        ),
      ],
      verify: (_) => expect(repositorio.edicoes, isEmpty),
    );

    blocTest<EditarFaturaCubit, EditarFaturaEstado>(
      'salva com o informado vazio virando nulo',
      build: criar,
      act: (cubit) => cubit.salvar(
        dataFechamento: DateTime(2026, 10, 8),
        dataVencimento: DateTime(2026, 10, 13),
        valorInformado: ' ',
      ),
      skip: 1,
      expect: () => [
        isA<EditarFaturaEstado>().having((e) => e.salva, 'salva', isNotNull),
      ],
      verify: (_) {
        final edicao = repositorio.edicoes.single;
        expect(edicao.dataFechamento, DateTime(2026, 10, 8));
        expect(edicao.valorInformado, isNull);
      },
    );

    blocTest<EditarFaturaCubit, EditarFaturaEstado>(
      'erro do servidor no fechamento aparece no campo',
      build: () {
        repositorio.erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {
            'data_fechamento':
                'O fechamento precisa ficar depois do da fatura anterior e '
                'antes do da seguinte.',
          },
        );
        return criar();
      },
      act: (cubit) => cubit.salvar(
        dataFechamento: DateTime(2026, 11, 5),
        dataVencimento: DateTime(2026, 11, 13),
        valorInformado: '',
      ),
      skip: 1,
      expect: () => [
        const EditarFaturaEstado(
          erros: {
            'data_fechamento':
                'O fechamento precisa ficar depois do da fatura anterior e '
                'antes do da seguinte.',
          },
        ),
      ],
    );
  });

  group('FaturaCubit.ajustar', () {
    blocTest<FaturaCubit, FaturaEstado>(
      'valor inválido não chama a API',
      build: () => FaturaCubit(repositorio, 'k1'),
      seed: () => FaturaEstado.carregada(detalheExemplo(outubroExemplo)),
      act: (cubit) => cubit.ajustar(valorReal: 'abc', descricao: ''),
      expect: () => [
        FaturaEstado.carregada(
          detalheExemplo(outubroExemplo),
          erroAjuste: 'Valor inválido. Use o formato 1.234,56.',
        ),
      ],
      verify: (_) => expect(repositorio.ajustes, isEmpty),
    );

    blocTest<FaturaCubit, FaturaEstado>(
      'ajusta e mostra o detalhe novo',
      build: () => FaturaCubit(repositorio, 'k1'),
      seed: () => FaturaEstado.carregada(detalheExemplo(outubroExemplo)),
      act: (cubit) => cubit.ajustar(valorReal: '1.032,15', descricao: ' '),
      expect: () => [
        FaturaEstado.carregada(detalheExemplo(outubroExemplo), ajustando: true),
        isA<FaturaCarregada>()
            .having((e) => e.ajustando, 'ajustando', isFalse)
            .having(
              (e) => e.detalhe.resumo.valorCalculado,
              'calculado',
              Decimal.parse('1032.15'),
            ),
      ],
      verify: (_) => expect(repositorio.ajustes.single, (
        valorReal: Decimal.parse('1032.15'),
        descricao: null,
      )),
    );
  });

  testWidgets('Editar fatura: volta às datas calculadas', (tester) async {
    _telaAlta(tester);
    final detalhe = detalheExemplo(outubroExemplo);
    final editado = detalhe.copyWith(
      resumo: detalhe.resumo.copyWith(dataFechamento: DateTime(2026, 10, 8)),
    );
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) =>
              EditarFaturaCubit(repositorio, 'k1', DateTime(2026, 10)),
          child: EditarFaturaTela(contaId: 'k1', detalhe: editado),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('08/10/2026'), findsOneWidget);
    expect(find.text('Editada. A calculada é 05/10/2026.'), findsOneWidget);
    expect(find.text('1.032,15'), findsOneWidget);

    await tester.tap(find.text('Voltar às datas calculadas'));
    await tester.pumpAndSettle();

    expect(find.text('05/10/2026'), findsOneWidget);
    expect(
      find.text('Dia 3 caiu num sábado: passou para o próximo dia útil.'),
      findsOneWidget,
    );
    expect(repositorio.edicoes, isEmpty);
  });

  testWidgets('Ajustar para o valor real: folha preenchida e envio', (
    tester,
  ) async {
    _telaAlta(tester);
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => FaturaCubit(repositorio, 'k1'),
          child: FaturaTela(contaId: 'k1', competencia: DateTime(2026, 10)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajustar para o valor real'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Valor real da fatura'),
      findsOneWidget,
    );
    expect(find.text('1.032,15'), findsOneWidget);
    expect(
      find.text('Vai lançar um ajuste de R\$ 45,90 nesta fatura.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Ajustar'));
    await tester.pumpAndSettle();

    expect(repositorio.ajustes.single.valorReal, Decimal.parse('1032.15'));
    expect(
      find.widgetWithText(TextField, 'Valor real da fatura'),
      findsNothing,
    );
    expect(find.text('Faltam R\$ 45,90 em lançamentos.'), findsNothing);
  });
}
