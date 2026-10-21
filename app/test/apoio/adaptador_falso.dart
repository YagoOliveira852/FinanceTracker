import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Resposta fingida: status HTTP e corpo JSON.
typedef RespostaFalsa = ({int status, Object? corpo});

/// Adaptador HTTP do dio que responde sem rede, pela função [responder].
/// Guarda cada requisição recebida em [requisicoes].
class AdaptadorFalso implements HttpClientAdapter {
  AdaptadorFalso(this.responder);

  final FutureOr<RespostaFalsa> Function(RequestOptions options) responder;
  final requisicoes = <RequestOptions>[];

  int chamadasA(String caminho) =>
      requisicoes.where((r) => r.path == caminho).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requisicoes.add(options);
    final resposta = await responder(options);
    return ResponseBody.fromString(
      jsonEncode(resposta.corpo),
      resposta.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Corpo JSON da requisição, já decodificado.
Map<String, Object?> corpoDe(RequestOptions options) {
  final dados = options.data;
  return (dados is String ? jsonDecode(dados) : dados) as Map<String, Object?>;
}
