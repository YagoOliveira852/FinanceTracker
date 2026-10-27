import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';

part 'decisao_cubit.freezed.dart';

@freezed
abstract class DecisaoEstado with _$DecisaoEstado {
  const factory DecisaoEstado({
    @Default(false) bool enviando,
    String? erro,

    /// Aviso para a lista quando a ação terminou; a folha então fecha.
    String? concluido,
  }) = _DecisaoEstado;
}

/// Uma folha de decisão (par, duplicata, sumiu da origem): roda a ação
/// escolhida, mostra o erro na folha ou conclui com o aviso para a lista.
class DecisaoCubit extends Cubit<DecisaoEstado> {
  DecisaoCubit() : super(const DecisaoEstado());

  Future<void> executar(
    Future<void> Function() acao, {
    required String aviso,
  }) async {
    if (state.enviando) return;
    emit(state.copyWith(enviando: true, erro: null));
    try {
      await acao();
      if (isClosed) return;
      emit(state.copyWith(enviando: false, concluido: aviso));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(
        state.copyWith(
          enviando: false,
          erro: erro.campos.values.firstOrNull ?? erro.mensagem,
        ),
      );
    }
  }
}
