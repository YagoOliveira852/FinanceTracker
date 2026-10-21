import 'package:financas/core/auth/armazenamento_tokens.dart';

/// Tokens só em memória, para os testes.
class ArmazenamentoTokensMemoria implements ArmazenamentoTokens {
  ArmazenamentoTokensMemoria([this.tokens]);

  TokensSessao? tokens;

  @override
  Future<TokensSessao?> ler() async => tokens;

  @override
  Future<void> salvar(TokensSessao tokens) async => this.tokens = tokens;

  @override
  Future<void> apagar() async => tokens = null;
}
