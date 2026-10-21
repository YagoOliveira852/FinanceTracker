import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../data/auth_repositorio.dart';

part 'sessao_cubit.freezed.dart';

/// Estado da sessão, que decide entre a tela de login e o resto do app.
@freezed
sealed class SessaoEstado with _$SessaoEstado {
  /// Lendo os tokens guardados, logo ao abrir o app.
  const factory SessaoEstado.verificando() = SessaoVerificando;

  /// [expirou]: o refresh foi recusado; o login mostra "Sessão expirada".
  const factory SessaoEstado.desconectada({@Default(false) bool expirou}) =
      SessaoDesconectada;

  const factory SessaoEstado.conectada() = SessaoConectada;
}

class SessaoCubit extends Cubit<SessaoEstado> {
  SessaoCubit(this._auth) : super(const SessaoEstado.verificando());

  final AuthRepositorio _auth;

  /// Com tokens guardados, entra direto: se o access venceu, o primeiro 401
  /// renova a sessão ou leva ao login com "Sessão expirada".
  Future<void> iniciar() async {
    emit(
      await _auth.temSessao()
          ? const SessaoEstado.conectada()
          : const SessaoEstado.desconectada(),
    );
  }

  void entrou() => emit(const SessaoEstado.conectada());

  /// Chamado pelo interceptor quando o refresh é recusado.
  void expirou() => emit(const SessaoEstado.desconectada(expirou: true));

  Future<void> sair() async {
    await _auth.sair();
    emit(const SessaoEstado.desconectada());
  }
}
