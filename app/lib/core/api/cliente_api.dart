import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';

/// Endereço da API, definido no build: `--dart-define=API_URL=...`.
const urlApi = String.fromEnvironment('API_URL');

/// Dio configurado para a API (endereço e tempos de espera).
Dio criarDio({String baseUrl = urlApi}) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
}

/// Cria o cliente gerado do OpenAPI. Só `core/api/` monta o cliente; as
/// features o usam através dos seus repositórios.
///
/// [interceptors] substitui os interceptors de autenticação que o cliente
/// gerado registra por padrão: o token é responsabilidade do
/// `InterceptorAuth`.
ApiClient criarClienteApi({
  String baseUrl = urlApi,
  Dio? dio,
  List<Interceptor> interceptors = const [],
}) {
  return ApiClient(
    dio: dio ?? criarDio(baseUrl: baseUrl),
    interceptors: interceptors,
  );
}
