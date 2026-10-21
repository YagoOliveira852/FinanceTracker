import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/conta.dart';
import '../data/contas_repositorio.dart';

part 'contas_cubit.freezed.dart';

@freezed
sealed class ContasEstado with _$ContasEstado {
  const factory ContasEstado.carregando() = ContasCarregando;
  const factory ContasEstado.carregado(ResumoContas resumo) = ContasCarregado;
  const factory ContasEstado.erro(String mensagem) = ContasErro;
}

/// Lista de contas e total disponível (tela Contas e card do Início).
class ContasCubit extends Cubit<ContasEstado> {
  ContasCubit(this._contas) : super(const ContasEstado.carregando());

  final ContasRepositorio _contas;

  Future<void> carregar() async {
    emit(const ContasEstado.carregando());
    try {
      emit(ContasEstado.carregado(await _contas.listar()));
    } on ErroApi catch (erro) {
      emit(ContasEstado.erro(erro.mensagem));
    }
  }
}
