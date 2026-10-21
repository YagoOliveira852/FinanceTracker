import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/auth_repositorio.dart';
import 'sessao_cubit.dart';

part 'login_cubit.freezed.dart';

@freezed
abstract class LoginEstado with _$LoginEstado {
  const factory LoginEstado({@Default(false) bool enviando, String? erro}) =
      _LoginEstado;
}

/// Formulário de login. No sucesso, avisa o [SessaoCubit], e o router sai
/// da tela de login.
class LoginCubit extends Cubit<LoginEstado> {
  LoginCubit(this._auth, this._sessao) : super(const LoginEstado());

  final AuthRepositorio _auth;
  final SessaoCubit _sessao;

  Future<void> entrar({required String email, required String senha}) async {
    if (email.trim().isEmpty || senha.isEmpty) {
      emit(const LoginEstado(erro: 'Informe o e-mail e a senha.'));
      return;
    }
    emit(const LoginEstado(enviando: true));
    try {
      await _auth.entrar(email: email, senha: senha);
      if (isClosed) return;
      emit(const LoginEstado());
      _sessao.entrou();
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(LoginEstado(erro: erro.mensagem));
    }
  }
}
