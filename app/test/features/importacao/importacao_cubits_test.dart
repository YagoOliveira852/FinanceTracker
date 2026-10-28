import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/importacao/cubit/compartilhado_cubit.dart';
import 'package:financas/features/importacao/cubit/importacao_cubit.dart';
import 'package:financas/features/importacao/cubit/importar_cubit.dart';
import 'package:financas/features/importacao/data/importacao.dart';
import 'package:financas/features/importacao/data/importacoes_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/importacoes_falso.dart';

void main() {
  group('ImportarCubit', () {
    late ImportacoesRepositorioFalso repositorio;
    late SeletorArquivoFalso seletor;

    setUp(() {
      repositorio = ImportacoesRepositorioFalso(
        historico: [importacaoDeFaturaExemplo(), importacaoExemplo()],
      );
      seletor = SeletorArquivoFalso(arquivoExemplo());
    });

    ImportarCubit criar() => ImportarCubit(repositorio, seletor);

    test('sugere a conta da última importação do mesmo tipo', () async {
      final cubit = criar();
      await cubit.carregar();

      cubit.receberArquivo(arquivoExemplo(fatura: true));
      expect((cubit.state.contaId, cubit.state.contaSugerida), ('k1', true));

      cubit.receberArquivo(arquivoExemplo());
      expect((cubit.state.contaId, cubit.state.contaSugerida), ('c1', true));
    });

    test('arquivo do Compartilhar antes do histórico também sugere', () async {
      final cubit = criar()..receberArquivo(arquivoExemplo(fatura: true));
      expect(cubit.state.contaId, isNull);

      await cubit.carregar();

      expect(cubit.state.contaId, 'k1');
    });

    test('conta escolhida pelo usuário não é trocada pela sugestão', () async {
      final cubit = criar();
      await cubit.carregar();
      cubit.escolherConta('outra');

      cubit.receberArquivo(arquivoExemplo(fatura: true));

      expect(
        (cubit.state.contaId, cubit.state.contaSugerida),
        ('outra', false),
      );
    });

    test('sem importação anterior do tipo, nada é sugerido', () async {
      repositorio.historico = [importacaoExemplo()];
      final cubit = criar();
      await cubit.carregar();

      cubit.receberArquivo(arquivoExemplo(fatura: true));

      expect(cubit.state.contaId, isNull);
    });

    test('escolher arquivo usa o seletor; fechar não muda nada', () async {
      final cubit = criar();
      await cubit.escolherArquivo();
      expect(cubit.state.arquivo?.nome, 'extrato-outubro.ofx');

      seletor.arquivo = null;
      await cubit.escolherArquivo();
      expect(cubit.state.arquivo?.nome, 'extrato-outubro.ofx');
    });

    blocTest<ImportarCubit, ImportarEstado>(
      'sem arquivo e conta, aponta os dois campos',
      build: criar,
      act: (cubit) => cubit.importar(),
      expect: () => [
        isA<ImportarEstado>().having((e) => e.erros.keys, 'erros', [
          'arquivo',
          'conta_id',
        ]),
      ],
    );

    test('importa e entrega a importação nova', () async {
      final cubit = criar()
        ..receberArquivo(arquivoExemplo())
        ..escolherConta('c1');

      await cubit.importar();

      expect(repositorio.enviados.single.contaId, 'c1');
      expect(cubit.state.importada?.id, 'nova');
      expect(cubit.state.arquivo, isNull);
      expect(cubit.state.historico?.first.id, 'nova');
      expect(cubit.state.enviando, isFalse);
    });

    test('arquivo já importado mostra a anterior e mantém o arquivo', () async {
      repositorio.resultado = ResultadoImportacao(
        jaImportada: true,
        importacao: importacaoExemplo(),
      );
      final cubit = criar()
        ..receberArquivo(arquivoExemplo())
        ..escolherConta('c1');

      await cubit.importar();

      expect(cubit.state.jaImportada?.id, 'imp1');
      expect(cubit.state.importada, isNull);
      expect(cubit.state.arquivo, isNotNull);
    });

    test('FITID repetido guarda as linhas', () async {
      repositorio.erroImportar = ErroFitidRepetido('Nada foi importado.', [
        LinhaRepetida(
          fitid: 'f1',
          data: DateTime(2026, 10, 2),
          valor: Decimal.parse('-64.90'),
          descricao: 'Mercado do Bairro',
        ),
      ]);
      final cubit = criar()
        ..receberArquivo(arquivoExemplo())
        ..escolherConta('c1');

      await cubit.importar();

      expect(cubit.state.linhasRepetidas.single.descricao, 'Mercado do Bairro');
      expect(cubit.state.erroGeral, isNull);

      // Trocar o arquivo limpa o erro.
      cubit.receberArquivo(arquivoExemplo(nome: 'baixado-de-novo.ofx'));
      expect(cubit.state.linhasRepetidas, isEmpty);
    });

    test('erro da API no campo vai para o campo; sem campo, geral', () async {
      repositorio.erroImportar = const ErroApi(
        'Dados inválidos.',
        status: 422,
        campos: {'conta_id': 'Este OFX é de fatura de cartão.'},
      );
      final cubit = criar()
        ..receberArquivo(arquivoExemplo(fatura: true))
        ..escolherConta('c1');

      await cubit.importar();
      expect(cubit.state.erros, {
        'conta_id': 'Este OFX é de fatura de cartão.',
      });
      expect(cubit.state.erroGeral, isNull);

      repositorio.erroImportar = const ErroApi(ErroApi.semConexao);
      await cubit.importar();
      expect(cubit.state.erroGeral, ErroApi.semConexao);
    });

    test('arquivo acima de 5 MB é recusado no aparelho', () async {
      final grande = ArquivoEscolhido(
        nome: 'grande.ofx',
        bytes: Uint8List(tamanhoMaximoArquivo + 1),
      );
      final cubit = criar()
        ..receberArquivo(grande)
        ..escolherConta('c1');

      await cubit.importar();

      expect(cubit.state.erros, {'arquivo': 'O arquivo passa de 5 MB.'});
      expect(repositorio.enviados, isEmpty);
    });
  });

  group('ImportacaoCubit', () {
    test('aberta pelo histórico, carrega as contagens de agora', () async {
      final repositorio = ImportacoesRepositorioFalso(
        historico: [importacaoExemplo(qtdConfirmadas: 12)],
      );
      final cubit = ImportacaoCubit(repositorio, 'imp1');

      await cubit.carregar();

      expect(cubit.state.importacao?.qtdConfirmadas, 12);
      expect(cubit.state.importacao?.podeDesfazer, isFalse);
    });

    test('desfazer conclui', () async {
      final repositorio = ImportacoesRepositorioFalso(
        historico: [importacaoExemplo()],
      );
      final cubit = ImportacaoCubit(
        repositorio,
        'imp1',
        inicial: importacaoExemplo(),
      );

      await cubit.desfazer();

      expect(repositorio.desfeitas, ['imp1']);
      expect(cubit.state.desfeita, isTrue);
    });

    test('desfazer recusado mostra o erro e recarrega', () async {
      final repositorio = ImportacoesRepositorioFalso(
        historico: [importacaoExemplo(qtdConfirmadas: 1)],
        erroDesfazer: const ErroApi('Não dá mais para desfazer.', status: 409),
      );
      final cubit = ImportacaoCubit(
        repositorio,
        'imp1',
        inicial: importacaoExemplo(),
      );

      await cubit.desfazer();

      expect(cubit.state.erroDesfazer, 'Não dá mais para desfazer.');
      expect(cubit.state.desfeita, isFalse);
      expect(cubit.state.importacao?.podeDesfazer, isFalse);
    });
  });

  group('CompartilhadoCubit', () {
    test('guarda o arquivo recebido até ser consumido uma vez', () async {
      final fonte = FonteCompartilhamentoFalsa();
      final cubit = CompartilhadoCubit(fonte);

      fonte.controlador.add(arquivoExemplo(compartilhado: true));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.consumir()?.compartilhado, isTrue);
      expect(cubit.consumir(), isNull);
      await cubit.close();
    });
  });
}
