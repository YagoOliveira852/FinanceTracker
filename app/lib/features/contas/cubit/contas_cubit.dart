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

  /// Só a resposta da carga mais recente vale (atualizar e lançar ao mesmo
  /// tempo, por exemplo).
  var _versao = 0;

  Future<void> carregar() async {
    final versao = ++_versao;
    emit(const ContasEstado.carregando());
    try {
      final resumo = await _contas.listar();
      if (isClosed || versao != _versao) return;
      emit(ContasEstado.carregado(resumo));
    } on ErroApi catch (erro) {
      if (isClosed || versao != _versao) return;
      emit(ContasEstado.erro(erro.mensagem));
    }
  }
}
