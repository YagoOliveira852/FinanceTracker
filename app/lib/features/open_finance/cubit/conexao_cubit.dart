import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/open_finance.dart';
import '../data/open_finance_repositorio.dart';

part 'conexao_cubit.freezed.dart';

/// A escolha para uma conta da Pluggy: criar nova ou alimentar uma do app.
@freezed
sealed class Escolha with _$Escolha {
  const factory Escolha.criar() = EscolhaCriar;
  const factory Escolha.vincular(String contaId) = EscolhaVincular;
}

@freezed
abstract class ConexaoEstado with _$ConexaoEstado {
  const factory ConexaoEstado({
    @Default(false) bool verificando,

    /// Erro do campo do ID (item inexistente, formato).
    String? erroItem,
    PreviaConexao? previa,

    /// Depois do "Continuar": o passo dos vínculos.
    @Default(false) bool vinculando,

    /// Por `pluggyAccountId`; ausente = ainda sem escolha (cartão que não
    /// pode ser criado e não tem sugestão).
    @Default({}) Map<String, Escolha> escolhas,
    @Default(false) bool salvando,
    String? erro,
    @Default(false) bool salvo,
  }) = _ConexaoEstado;
}

/// Adicionar conexão ou renovar uma ([conexaoId]): verificar o ID na Pluggy,
/// escolher o vínculo de cada conta e salvar.
class ConexaoCubit extends Cubit<ConexaoEstado> {
  ConexaoCubit(this._repositorio, {this.conexaoId})
    : super(const ConexaoEstado());

  final OpenFinanceRepositorio _repositorio;

  /// Nula ao adicionar; a conexão renovada.
  final String? conexaoId;

  Future<void> verificar(String itemId) async {
    final id = itemId.trim();
    if (id.isEmpty) {
      emit(state.copyWith(erroItem: 'Cole o ID do item do Meu Pluggy.'));
      return;
    }
    emit(state.copyWith(verificando: true, erroItem: null, previa: null));
    try {
      final previa = await _repositorio.previa(id, conexaoId: conexaoId);
      if (isClosed) return;
      emit(
        state.copyWith(
          verificando: false,
          previa: previa,
          escolhas: {
            for (final conta in previa.contas)
              conta.pluggyAccountId: ?_padrao(conta),
          },
        ),
      );
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(
        state.copyWith(
          verificando: false,
          erroItem: erro.campos['item_id'] ?? erro.mensagem,
        ),
      );
    }
  }

  void continuar() {
    if (state.previa == null) return;
    emit(state.copyWith(vinculando: true, erro: null));
  }

  void voltar() => emit(state.copyWith(vinculando: false, erro: null));

  void escolher(String pluggyAccountId, Escolha escolha) {
    emit(
      state.copyWith(
        escolhas: {...state.escolhas, pluggyAccountId: escolha},
        erro: null,
      ),
    );
  }

  Future<void> salvar() async {
    final previa = state.previa;
    if (previa == null || state.salvando) return;
    final faltando = previa.contas.where(
      (c) => !state.escolhas.containsKey(c.pluggyAccountId),
    );
    if (faltando.isNotEmpty) {
      emit(
        state.copyWith(
          erro: 'Escolha a conta do app para ${faltando.first.nome}.',
        ),
      );
      return;
    }
    final vinculos = [
      for (final conta in previa.contas)
        Vinculo(
          pluggyAccountId: conta.pluggyAccountId,
          contaId: switch (state.escolhas[conta.pluggyAccountId]!) {
            EscolhaCriar() => null,
            EscolhaVincular(:final contaId) => contaId,
          },
        ),
    ];
    emit(state.copyWith(salvando: true, erro: null));
    try {
      if (conexaoId case final id?) {
        await _repositorio.renovar(id, previa.itemId, vinculos);
      } else {
        await _repositorio.criar(previa.itemId, vinculos);
      }
      if (isClosed) return;
      emit(state.copyWith(salvando: false, salvo: true));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(
        state.copyWith(
          salvando: false,
          erro: erro.campos['vinculos'] ?? erro.mensagem,
        ),
      );
    }
  }

  /// A sugestão pelo final do número; sem ela, criar nova (padrão), se der.
  static Escolha? _padrao(ContaDaPrevia conta) {
    if (conta.sugestao case final sugestao?) {
      return Escolha.vincular(sugestao.id);
    }
    return conta.podeCriar ? const Escolha.criar() : null;
  }
}
