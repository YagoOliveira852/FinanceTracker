import 'package:dio/dio.dart';

/// Erro de uma chamada à API, já em pt-BR, para cubits e telas.
///
/// Os repositórios convertem [DioException] em [ErroApi]: assim cubit e tela
/// não sabem de dio nem do cliente gerado.
class ErroApi implements Exception {
  const ErroApi(this.mensagem, {this.status, this.campos = const {}});

  /// Converte qualquer erro de uma chamada à API.
  ///
  /// A API responde `{"detail": "...", "campos": [{"campo": "body.valor",
  /// "mensagem": "..."}]}` (ver `backend/app/core/erros.py`); [campos] fica
  /// indexado pelo nome do campo sem o prefixo (`valor`).
  factory ErroApi.de(Object erro) {
    if (erro is ErroApi) return erro;
    if (erro is! DioException) return const ErroApi(_mensagemGenerica);

    final resposta = erro.response;
    if (resposta == null) return const ErroApi(semConexao);

    final status = resposta.statusCode;
    if (status != null && status >= 500) {
      return ErroApi(_erroServidor, status: status);
    }

    final corpo = resposta.data;
    if (corpo is! Map) return ErroApi(_mensagemGenerica, status: status);

    final detail = corpo['detail'];
    return ErroApi(
      detail is String ? detail : _mensagemGenerica,
      status: status,
      campos: _lerCampos(corpo['campos']),
    );
  }

  static const semConexao = 'Não foi possível falar com o servidor.';
  static const _erroServidor = 'Erro no servidor. Tente de novo.';
  static const _mensagemGenerica = 'Algo deu errado. Tente de novo.';

  final String mensagem;
  final int? status;

  /// Mensagem por campo do formulário (`valor`, `data_saldo_inicial`...).
  final Map<String, String> campos;

  static Map<String, String> _lerCampos(Object? campos) {
    if (campos is! List) return const {};
    return {
      for (final item in campos.whereType<Map>())
        if (item['campo'] is String && item['mensagem'] is String)
          (item['campo'] as String).split('.').last: item['mensagem'] as String,
    };
  }

  @override
  String toString() => 'ErroApi($status, $mensagem, $campos)';
}
