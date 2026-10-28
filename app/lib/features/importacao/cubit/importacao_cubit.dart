import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/importacao.dart';
import '../data/importacoes_repositorio.dart';

part 'importacao_cubit.freezed.dart';

@freezed
abstract class ImportacaoEstado with _$ImportacaoEstado {
  const factory ImportacaoEstado({
    /// Nula enquanto carrega (aberta pelo id).
    Importacao? importacao,
    String? erro,
    @Default(false) bool desfazendo,

    /// Erro ao desfazer (ex.: alguém confirmou uma transação nesse meio-tempo).
    String? erroDesfazer,

    /// Desfeita: a tela fecha.
    @Default(false) bool desfeita,
  }) = _ImportacaoEstado;
}

/// Resumo de uma importação, aberto logo depois de importar ou pelo
/// histórico, e o "Desfazer".
class ImportacaoCubit extends Cubit<ImportacaoEstado> {
  ImportacaoCubit(this._importacoes, this._id, {Importacao? inicial})
    : super(ImportacaoEstado(importacao: inicial));

  final ImportacoesRepositorio _importacoes;
  final String _id;

  /// Recarrega: confirmadas e pendentes mudam conforme a Revisão avança.
  Future<void> carregar() async {
    try {
      final importacao = await _importacoes.obter(_id);
      if (isClosed) return;
      emit(state.copyWith(importacao: importacao, erro: null));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(state.copyWith(erro: erro.mensagem));
    }
  }

  Future<void> desfazer() async {
    emit(state.copyWith(desfazendo: true, erroDesfazer: null));
    try {
      await _importacoes.desfazer(_id);
      if (isClosed) return;
      emit(state.copyWith(desfazendo: false, desfeita: true));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(state.copyWith(desfazendo: false, erroDesfazer: erro.mensagem));
      // O 409 quer dizer que algo foi confirmado: o resumo mostra quantas.
      await carregar();
    }
  }
}
