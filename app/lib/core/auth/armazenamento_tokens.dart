import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Par de tokens da sessão: access (curto, vai no `Authorization`) e refresh
/// (longo, troca por um par novo em `POST /auth/refresh`).
class TokensSessao {
  const TokensSessao({required this.access, required this.refresh});

  final String access;
  final String refresh;
}

/// Onde a sessão fica guardada entre aberturas do app.
abstract interface class ArmazenamentoTokens {
  Future<TokensSessao?> ler();
  Future<void> salvar(TokensSessao tokens);
  Future<void> apagar();
}

/// Tokens no flutter_secure_storage (Keystore do Android), com cópia em
/// memória para não ler o armazenamento a cada requisição.
class ArmazenamentoTokensSeguro implements ArmazenamentoTokens {
  ArmazenamentoTokensSeguro([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _chaveAccess = 'access_token';
  static const _chaveRefresh = 'refresh_token';

  final FlutterSecureStorage _storage;
  TokensSessao? _cache;
  bool _carregado = false;

  @override
  Future<TokensSessao?> ler() async {
    if (_carregado) return _cache;
    final access = await _storage.read(key: _chaveAccess);
    final refresh = await _storage.read(key: _chaveRefresh);
    _cache = access != null && refresh != null
        ? TokensSessao(access: access, refresh: refresh)
        : null;
    _carregado = true;
    return _cache;
  }

  @override
  Future<void> salvar(TokensSessao tokens) async {
    await _storage.write(key: _chaveAccess, value: tokens.access);
    await _storage.write(key: _chaveRefresh, value: tokens.refresh);
    _cache = tokens;
    _carregado = true;
  }

  @override
  Future<void> apagar() async {
    await _storage.delete(key: _chaveAccess);
    await _storage.delete(key: _chaveRefresh);
    _cache = null;
    _carregado = true;
  }
}
