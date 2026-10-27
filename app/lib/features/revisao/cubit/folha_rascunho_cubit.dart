import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../contas/data/conta.dart';
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

    /// Na transferência: a outra conta ("Para" numa saída, "De" numa entrada).
    String? outraContaId,
    required String descricao,
    @Default(false) bool enviando,
    String? erro,

    /// Aviso para a lista quando a ação terminou; a folha então fecha.
    String? concluido,
  }) = _FolhaRascunhoEstado;
}

/// A folha de um rascunho comum: descrição, tipo e categoria escolhidos, o
/// efeito que a escolha terá nas regras, Confirmar e Ignorar. Como
/// transferência, escolhe a outra conta em vez da categoria.
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

  /// Os tipos do rascunho, no mesmo sentido (como a API): saída é despesa;
  /// entrada, receita ou estorno; em corrente e carteira, também
  /// transferência entre contas próprias.
  static List<TipoTransacao> tiposPara(ItemRevisao item) {
    final transfere = item.contaTipo != TipoConta.cartaoCredito;
    return item.tipo.entrada
        ? [
            TipoTransacao.receita,
            TipoTransacao.estorno,
            if (transfere) TipoTransacao.transferenciaEntrada,
          ]
        : [
            TipoTransacao.despesa,
            if (transfere) TipoTransacao.transferenciaSaida,
          ];
  }

  bool get eTransferencia =>
      state.tipo == TipoTransacao.transferenciaSaida ||
      state.tipo == TipoTransacao.transferenciaEntrada;

  /// O que confirmar faz com as regras, com a categoria escolhida. Nulo sem
  /// categoria ou com o tipo trocado (a sugestão era para o tipo original).
  EfeitoRegra? get efeito {
    final categoriaId = state.categoriaId;
    if (categoriaId == null || state.tipo != rascunho.item.tipo) return null;
    if (eTransferencia) return null;
    return rascunho.efeitoPara(categoriaId);
  }

  bool get podeConfirmar =>
      (eTransferencia ? state.outraContaId : state.categoriaId) != null &&
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

  void escolherOutraConta(String id) =>
      emit(state.copyWith(outraContaId: id, erro: null));

  void escolherCategoria(String id) =>
      emit(state.copyWith(categoriaId: id, erro: null));

  void mudarDescricao(String descricao) =>
      emit(state.copyWith(descricao: descricao, erro: null));

  Future<void> confirmar() async {
    if (!podeConfirmar) return;
    final descricao = state.descricao.trim();
    if (eTransferencia) {
      return _enviar(() async {
        await _revisao.transferir(
          rascunho.item.id,
          contaId: state.outraContaId!,
          descricao: descricao,
        );
        return '$descricao ligada como transferência.';
      });
    }
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
