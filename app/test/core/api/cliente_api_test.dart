import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde toda requisição com o mesmo JSON, sem rede.
class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.corpo);

  final Map<String, Object?> corpo;
  RequestOptions? ultimaRequisicao;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultimaRequisicao = options;
    return ResponseBody.fromString(
      jsonEncode(corpo),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('cliente gerado lê GET /contas com dinheiro em String', () async {
    final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
    final adaptador = _AdaptadorFalso({
      'total_disponivel': '1234.56',
      'contas': [
        {
          'id': '6f1c2b3a-0000-4000-8000-000000000001',
          'nome': 'Conta de exemplo',
          'tipo': 'corrente',
          'instituicao': {
            'id': '6f1c2b3a-0000-4000-8000-000000000002',
            'nome': 'Banco Fictício',
          },
          'saldo_inicial': '1000.00',
          'data_saldo_inicial': '2026-10-01',
          'saldo_atual': '1234.56',
          'ativa': true,
        },
      ],
    });
    cliente.dio.httpClientAdapter = adaptador;

    final resposta = await cliente.getContasApi().listar();

    expect(adaptador.ultimaRequisicao!.uri.toString(),
        'http://api.exemplo.test/contas');
    final resumo = resposta.data!;
    // Dinheiro continua String: a conversão para Decimal é do repositório,
    // nunca para double.
    expect(resumo.totalDisponivel, '1234.56');
    expect(resumo.contas.single.saldoAtual, '1234.56');
    expect(resumo.contas.single.instituicao!.nome, 'Banco Fictício');
  });
}
