import 'package:api_client/api_client.dart';

/// Endereço da API, definido no build: `--dart-define=API_URL=...`.
const urlApi = String.fromEnvironment('API_URL');

/// Cria o cliente gerado do OpenAPI. Só `core/api/` fala com a API: as
/// features usam o cliente através dos seus repositórios.
ApiClient criarClienteApi({String baseUrl = urlApi}) {
  return ApiClient(basePathOverride: baseUrl);
}
