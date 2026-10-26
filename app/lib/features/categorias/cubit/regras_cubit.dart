import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/categorias_repositorio.dart';
import '../data/regra.dart';

part 'regras_cubit.freezed.dart';

@freezed
sealed class RegrasEstado with _$RegrasEstado {
  const factory RegrasEstado.carregando() = RegrasCarregando;
  const factory RegrasEstado.carregado(List<Regra> regras) = RegrasCarregado;
  const factory RegrasEstado.erro(String mensagem) = RegrasErro;
}

/// Aba Regras: manuais primeiro, depois as aprendidas mais usadas.
class RegrasCubit extends Cubit<RegrasEstado> {
  RegrasCubit(this._categorias) : super(const RegrasEstado.carregando());

  final CategoriasRepositorio _categorias;

  /// Só a resposta da carga mais recente vale.
  var _versao = 0;

  Future<void> carregar() async {
    final versao = ++_versao;
    emit(const RegrasEstado.carregando());
    try {
      final regras = await _categorias.listarRegras();
      if (isClosed || versao != _versao) return;
      emit(RegrasEstado.carregado(regras));
    } on ErroApi catch (erro) {
      if (isClosed || versao != _versao) return;
      emit(RegrasEstado.erro(erro.mensagem));
    }
  }
}
