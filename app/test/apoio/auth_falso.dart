import 'dart:async';

import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/login/data/auth_repositorio.dart';

/// Repositório de auth sem API. [erroAoEntrar] faz o login falhar;
/// [esperaEntrar] segura o login até ser completado (estado "Entrando").
class AuthRepositorioFalso implements AuthRepositorio {
  AuthRepositorioFalso({this.sessao = false, this.erroAoEntrar});

  bool sessao;
  ErroApi? erroAoEntrar;
  Completer<void>? esperaEntrar;
  final entradas = <({String email, String senha})>[];

  @override
  Future<void> entrar({required String email, required String senha}) async {
    entradas.add((email: email, senha: senha));
    await esperaEntrar?.future;
    if (erroAoEntrar != null) throw erroAoEntrar!;
    sessao = true;
  }

  @override
  Future<void> sair() async => sessao = false;

  @override
  Future<bool> temSessao() async => sessao;
}
