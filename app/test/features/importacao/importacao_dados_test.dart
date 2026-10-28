import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/importacao/data/importacao.dart';
import 'package:financas/features/importacao/data/importacoes_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';
import '../../apoio/importacoes_falso.dart';

const _id = '7a1c2b3a-0000-4000-8000-000000000001';
const _conta = '7a1c2b3a-0000-4000-8000-0000000000c1';

Map<String, Object?> _importacaoJson({
  String tipoConta = 'corrente',
  Map<String, Object?>? saldo,
  Map<String, Object?>? fatura,
}) => {
  'id': _id,
  'criado_em': '2026-10-28T12:00:00Z',
  'nome_arquivo': 'extrato-outubro.ofx',
  'fonte': 'ofx',
  'conta': {'id': _conta, 'nome': 'Conta principal', 'tipo': tipoConta},
  'periodo_inicio': '2026-10-01',
  'periodo_fim': '2026-10-25',
  'qtd_novas': 36,
  'qtd_possiveis_duplicatas': 2,
  'qtd_ja_importadas': 4,
  'qtd_parcelas': 0,
  'qtd_confirmadas': 0,
  'qtd_pendentes': 38,
  'pode_desfazer': true,
  'saldo_extrato': saldo,
  'fatura': fatura,
};

void main() {
  group('tipoDoArquivo', () {
    test('reconhece OFX de conta e de fatura pela marca', () {
      expect(tipoDoArquivo(ofxFicticio()), TipoArquivo.ofxConta);
      expect(tipoDoArquivo(ofxFicticio(fatura: true)), TipoArquivo.ofxFatura);
    });

    test('o que não é OFX é outro', () {
      final csv = Uint8List.fromList(utf8.encode('Data,Valor\n'));
      expect(tipoDoArquivo(csv), TipoArquivo.outro);
    });

    test('lê OFX em cp1252 sem quebrar', () {
      final bytes = Uint8List.fromList([
        ...ascii.encode('<OFX><BANKMSGSRSV1><MEMO>Caf'),
        0xE9, // é em cp1252: UTF-8 inválido
        ...ascii.encode('</MEMO></BANKMSGSRSV1></OFX>'),
      ]);
      expect(tipoDoArquivo(bytes), TipoArquivo.ofxConta);
    });
  });

  group('ImportacoesRepositorioApi', () {
    late AdaptadorFalso adaptador;
    late ImportacoesRepositorioApi repositorio;

    void responder(RespostaFalsa resposta) {
      adaptador = AdaptadorFalso((_) => resposta);
      final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
      cliente.dio.httpClientAdapter = adaptador;
      repositorio = ImportacoesRepositorioApi(cliente);
    }

    test('listar converte o resumo da conta, com o saldo do extrato', () async {
      responder((
        status: 200,
        corpo: [
          _importacaoJson(saldo: {'valor': '2340.15', 'data': '2026-10-25'}),
        ],
      ));

      final importacao = (await repositorio.listar()).single;

      expect(importacao.contaTipo, TipoConta.corrente);
      expect(importacao.tipoArquivo, TipoArquivo.ofxConta);
      expect(importacao.periodoFim, DateTime(2026, 10, 25));
      expect(importacao.qtdRascunhos, 38);
      expect(importacao.saldoExtrato?.valor, Decimal.parse('2340.15'));
      expect(importacao.fatura, isNull);
    });

    test('obter converte a fatura', () async {
      responder((
        status: 200,
        corpo: _importacaoJson(
          tipoConta: 'cartao_credito',
          fatura: {
            'competencia': '2026-10-01',
            'valor_informado': '1032.15',
            'data_fechamento': '2026-10-03',
          },
        ),
      ));

      final importacao = await repositorio.obter(_id);

      expect(adaptador.requisicoes.single.path, '/importacoes/$_id');
      expect(importacao.tipoArquivo, TipoArquivo.ofxFatura);
      expect(importacao.fatura?.valorInformado, Decimal.parse('1032.15'));
      expect(importacao.fatura?.dataFechamento, DateTime(2026, 10, 3));
    });

    test('importar manda o arquivo e a conta em multipart', () async {
      responder((
        status: 201,
        corpo: {'ja_importada': false, 'importacao': _importacaoJson()},
      ));

      final resultado = await repositorio.importar(
        contaId: _conta,
        arquivo: arquivoExemplo(),
      );

      final dados = adaptador.requisicoes.single.data as FormData;
      expect(Map.fromEntries(dados.fields), {'conta_id': _conta});
      expect(dados.files.single.key, 'arquivo');
      expect(dados.files.single.value.filename, 'extrato-outubro.ofx');
      expect(resultado.jaImportada, isFalse);
    });

    test('arquivo já importado volta com a importação anterior', () async {
      responder((
        status: 200,
        corpo: {'ja_importada': true, 'importacao': _importacaoJson()},
      ));

      final resultado = await repositorio.importar(
        contaId: _conta,
        arquivo: arquivoExemplo(),
      );

      expect(resultado.jaImportada, isTrue);
      expect(resultado.importacao.id, _id);
    });

    test('FITID repetido vira ErroFitidRepetido com as linhas', () async {
      responder((
        status: 422,
        corpo: {
          'detail': 'Nada foi importado.',
          'linhas_repetidas': [
            {
              'fitid': '1b2c3d4e-0000-4000-8000-000000000005',
              'data': '2026-10-02',
              'valor': '-64.90',
              'descricao': 'Mercado do Bairro',
            },
          ],
        },
      ));

      final erro = await repositorio
          .importar(contaId: _conta, arquivo: arquivoExemplo())
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(erro, isA<ErroFitidRepetido>());
      final linha = (erro! as ErroFitidRepetido).linhas.single;
      expect(linha.valor, Decimal.parse('-64.90'));
      expect(linha.data, DateTime(2026, 10, 2));
    });

    test('conta incompatível vira erro no campo conta_id', () async {
      responder((
        status: 422,
        corpo: {
          'detail': 'Dados inválidos.',
          'campos': [
            {
              'campo': 'body.conta_id',
              'mensagem': 'Este OFX é de fatura de cartão. Escolha um cartão.',
            },
          ],
        },
      ));

      expect(
        repositorio.importar(contaId: _conta, arquivo: arquivoExemplo()),
        throwsA(
          isA<ErroApi>()
              .having((e) => e is ErroFitidRepetido, 'fitid', isFalse)
              .having((e) => e.campos.keys, 'campos', ['conta_id']),
        ),
      );
    });

    test('desfazer com confirmada é 409', () async {
      responder((status: 409, corpo: {'detail': 'Não dá mais para desfazer.'}));

      expect(
        repositorio.desfazer(_id),
        throwsA(isA<ErroApi>().having((e) => e.status, 'status', 409)),
      );
    });
  });
}
