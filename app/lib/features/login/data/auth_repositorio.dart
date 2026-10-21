import 'package:api_client/api_client.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/auth/armazenamento_tokens.dart';

/// Login e sessão. Erros da API chegam como [ErroApi].
abstract interface class AuthRepositorio {
  Future<void> entrar({required String email, required String senha});
  Future<void> sair();
  Future<bool> temSessao();
}

class AuthRepositorioApi implements AuthRepositorio {
  AuthRepositorioApi(this._cliente, this._armazenamento);

  final ApiClient _cliente;
  final ArmazenamentoTokens _armazenamento;

  @override
  Future<void> entrar({required String email, required String senha}) async {
    try {
      final resposta = await _cliente.getAuthApi().login(
        loginEntrada: LoginEntrada(
          (b) => b
            ..email = email.trim()
            ..senha = senha,
        ),
      );
      final tokens = resposta.data!;
      await _armazenamento.salvar(
        TokensSessao(access: tokens.accessToken, refresh: tokens.refreshToken),
      );
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  /// Não há logout na API: sair é esquecer os tokens deste aparelho.
  @override
  Future<void> sair() => _armazenamento.apagar();

  @override
  Future<bool> temSessao() async => await _armazenamento.ler() != null;
}
