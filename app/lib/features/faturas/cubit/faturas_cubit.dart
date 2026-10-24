import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/fatura.dart';
import '../data/faturas_repositorio.dart';

part 'faturas_cubit.freezed.dart';

@freezed
sealed class FaturasEstado with _$FaturasEstado {
  const factory FaturasEstado.carregando() = FaturasCarregando;
  const factory FaturasEstado.carregado(ListaFaturas lista) = FaturasCarregado;
  const factory FaturasEstado.erro(String mensagem) = FaturasErro;
}

/// Lista de faturas de um cartão (próximas, atual e anteriores).
class FaturasCubit extends Cubit<FaturasEstado> {
  FaturasCubit(this._faturas, this._contaId)
    : super(const FaturasEstado.carregando());

  final FaturasRepositorio _faturas;
  final String _contaId;

  Future<void> carregar() async {
    emit(const FaturasEstado.carregando());
    try {
      final lista = await _faturas.listar(_contaId);
      if (isClosed) return;
      emit(FaturasEstado.carregado(lista));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(FaturasEstado.erro(erro.mensagem));
    }
  }
}
