import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';

import '../auth/armazenamento_tokens.dart';

/// Põe o access token em cada requisição e, num 401, renova a sessão com o
/// refresh token e repete a requisição.
///
/// É um [QueuedInterceptor]: os erros passam por [onError] um de cada vez.
/// Essa é a fila que garante **um refresh por vez** — com rotação, dois
/// refresh com o mesmo token contariam como reuso e derrubariam a sessão.
/// Quando vários 401 chegam juntos, o primeiro renova; os seguintes veem que o
/// token mudou e só repetem.
///
/// O refresh e a repetição usam [dioSemAuth], um dio sem este interceptor:
/// repetir pelo próprio dio enfileiraria o erro da repetição atrás do erro que
/// está sendo tratado, e a fila travaria.
class InterceptorAuth extends QueuedInterceptor {
  InterceptorAuth({
    required this.armazenamento,
    required this.dioSemAuth,
    required this.aoExpirarSessao,
  });

  final ArmazenamentoTokens armazenamento;
  final Dio dioSemAuth;

  /// Chamado quando o refresh é recusado: os tokens já foram apagados.
  final void Function() aoExpirarSessao;

  /// 401 nestas rotas é resposta final (credencial errada, sessão expirada):
  /// não leva token e não tenta refresh.
  static const _rotasDeAuth = {'/auth/login', '/auth/refresh'};

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_ehRotaDeAuth(options)) {
      final tokens = await armazenamento.ler();
      if (tokens != null) _autorizar(options, tokens.access);
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requisicao = err.requestOptions;
    if (err.response?.statusCode != 401 || _ehRotaDeAuth(requisicao)) {
      return handler.next(err);
    }

    var tokens = await armazenamento.ler();
    if (tokens == null) return handler.next(err);

    final tokenUsado = requisicao.headers['Authorization'];
    if (tokenUsado == 'Bearer ${tokens.access}') {
      try {
        tokens = await _renovar(tokens.refresh);
      } on DioException catch (erroRefresh) {
        if (erroRefresh.response?.statusCode == 401) {
          await armazenamento.apagar();
          aoExpirarSessao();
        }
        // Sem rede no refresh: a sessão continua; devolve o erro original.
        return handler.next(err);
      }
    }

    try {
      _autorizar(requisicao, tokens.access);
      handler.resolve(await dioSemAuth.fetch<dynamic>(requisicao));
    } on DioException catch (erroRepeticao) {
      handler.next(erroRepeticao);
    }
  }

  Future<TokensSessao> _renovar(String refresh) async {
    final resposta = await AuthApi(
      dioSemAuth,
      standardSerializers,
    ).refresh(refreshEntrada: RefreshEntrada((b) => b..refreshToken = refresh));
    final novos = TokensSessao(
      access: resposta.data!.accessToken,
      refresh: resposta.data!.refreshToken,
    );
    await armazenamento.salvar(novos);
    return novos;
  }

  static bool _ehRotaDeAuth(RequestOptions options) =>
      _rotasDeAuth.contains(options.path);

  static void _autorizar(RequestOptions options, String access) {
    options.headers['Authorization'] = 'Bearer $access';
  }
}
