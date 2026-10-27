import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../transacoes/data/transacao.dart';
import '../data/revisao.dart';
import '../data/revisao_repositorio.dart';

part 'folha_rascunho_cubit.freezed.dart';

@freezed
abstract class FolhaRascunhoEstado with _$FolhaRascunhoEstado {
  const factory FolhaRascunhoEstado({
    required TipoTransacao tipo,

    /// Começa na sugestão; nula até o usuário escolher, sem sugestão.
    String? categoriaId,
    required String descricao,
    @Default(false) bool enviando,
    String? erro,

    /// Aviso para a lista quando a ação terminou; a folha então fecha.
    String? concluido,
  }) = _FolhaRascunhoEstado;
}

/// A folha de um rascunho comum: descrição, tipo e categoria escolhidos, o
/// efeito que a escolha terá nas regras, Confirmar e Ignorar.
class FolhaRascunhoCubit extends Cubit<FolhaRascunhoEstado> {
  FolhaRascunhoCubit(this._revisao, this.rascunho)
    : super(
        FolhaRascunhoEstado(
          tipo: tiposPara(rascunho.item).contains(rascunho.item.tipo)
              ? rascunho.item.tipo
              : tiposPara(rascunho.item).first,
          categoriaId: rascunho.sugestao?.categoria.id,
          descricao: rascunho.item.descricao,
        ),
      );

  final RevisaoRepositorio _revisao;
  final Rascunho rascunho;

  /// Os tipos em que o rascunho pode ser confirmado com categoria, no mesmo
  /// sentido (como a API): saída é despesa; entrada, receita ou estorno.
  static List<TipoTransacao> tiposPara(ItemRevisao item) => item.tipo.entrada
      ? const [TipoTransacao.receita, TipoTransacao.estorno]
      : const [TipoTransacao.despesa];

  /// O que confirmar faz com as regras, com a categoria escolhida. Nulo sem
  /// categoria ou com o tipo trocado (a sugestão era para o tipo original).
  EfeitoRegra? get efeito {
    final categoriaId = state.categoriaId;
    if (categoriaId == null || state.tipo != rascunho.item.tipo) return null;
    return rascunho.efeitoPara(categoriaId);
  }

  bool get podeConfirmar =>
      state.categoriaId != null &&
      state.descricao.trim().isNotEmpty &&
      !state.enviando;

  /// Trocar o tipo muda os grupos que combinam: a categoria volta à sugestão
  /// (no tipo original) ou fica para escolher.
  void escolherTipo(TipoTransacao tipo) => emit(
    state.copyWith(
      tipo: tipo,
      categoriaId: tipo == rascunho.item.tipo
          ? rascunho.sugestao?.categoria.id
          : null,
      erro: null,
    ),
  );

  void escolherCategoria(String id) =>
      emit(state.copyWith(categoriaId: id, erro: null));

  void mudarDescricao(String descricao) =>
      emit(state.copyWith(descricao: descricao, erro: null));

  Future<void> confirmar() async {
    if (!podeConfirmar) return;
    final descricao = state.descricao.trim();
    await _enviar(() async {
      await _revisao.confirmar(
        rascunho.item.id,
        descricao: descricao,
        categoriaId: state.categoriaId!,
        tipo: state.tipo == rascunho.item.tipo ? null : state.tipo,
      );
      return '$descricao confirmada.';
    });
  }

  Future<void> ignorar() async {
    if (state.enviando) return;
    await _enviar(() async {
      await _revisao.ignorar(rascunho.item.id);
      return '${rascunho.item.descricao} ignorada.';
    });
  }

  Future<void> _enviar(Future<String> Function() acao) async {
    emit(state.copyWith(enviando: true, erro: null));
    try {
      final aviso = await acao();
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
