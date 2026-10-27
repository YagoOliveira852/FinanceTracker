import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/revisao.dart';
import '../data/revisao_repositorio.dart';

part 'pagamento_revisao_cubit.freezed.dart';

@freezed
abstract class PagamentoRevisaoEstado with _$PagamentoRevisaoEstado {
  const factory PagamentoRevisaoEstado({
    @Default(true) bool carregando,
    @Default([]) List<FaturaCandidata> candidatas,

    /// Começa na sugerida; nula sem sugestão até o usuário escolher.
    FaturaCandidata? escolhida,
    @Default(false) bool enviando,
    String? erro,

    /// Aviso para a lista quando o pagamento foi confirmado.
    String? concluido,
  }) = _PagamentoRevisaoEstado;
}

/// Folha "Pagamento de fatura?": carrega as faturas candidatas, começa na
/// sugerida e confirma o pagamento na escolhida.
class PagamentoRevisaoCubit extends Cubit<PagamentoRevisaoEstado> {
  PagamentoRevisaoCubit(this._revisao, this.pagamento)
    : super(const PagamentoRevisaoEstado());

  final RevisaoRepositorio _revisao;
  final ItemRevisao pagamento;

  Future<void> carregar() async {
    emit(state.copyWith(carregando: true, erro: null));
    try {
      final candidatas = await _revisao.faturasDoPagamento(pagamento.id);
      if (isClosed) return;
      emit(
        state.copyWith(
          carregando: false,
          candidatas: candidatas,
          escolhida: candidatas.where((f) => f.sugerida).firstOrNull,
        ),
      );
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(state.copyWith(carregando: false, erro: erro.mensagem));
    }
  }

  void escolher(FaturaCandidata fatura) =>
      emit(state.copyWith(escolhida: fatura, erro: null));

  Future<void> confirmar() async {
    final fatura = state.escolhida;
    if (fatura == null || state.enviando) return;
    emit(state.copyWith(enviando: true, erro: null));
    try {
      await _revisao.pagar(
        pagamento.id,
        cartaoId: fatura.cartaoId,
        competencia: fatura.competencia,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          enviando: false,
          concluido: 'Pagamento ligado à fatura de ${fatura.cartaoNome}.',
        ),
      );
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
