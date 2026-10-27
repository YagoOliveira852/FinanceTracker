import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/datas.dart';
import '../data/revisao.dart';
import '../data/revisao_repositorio.dart';

part 'revisao_cubit.freezed.dart';

/// Os rascunhos comuns de um dia, como a lista agrupa.
typedef DiaDeRascunhos = ({DateTime data, List<Rascunho> rascunhos});

@freezed
abstract class RevisaoEstado with _$RevisaoEstado {
  const factory RevisaoEstado({
    /// Para "Ontem · dom, 25 out".
    required DateTime hoje,

    /// Nula até a primeira carga terminar.
    Revisao? revisao,
    @Default(false) bool carregando,

    /// Falha ao carregar.
    String? erro,

    /// Um ✓ ou o lote em andamento.
    @Default(false) bool enviando,

    /// Mensagem de uma vez (SnackBar) ao terminar uma ação, com ou sem erro.
    String? aviso,
  }) = _RevisaoEstado;

  const RevisaoEstado._();

  /// O contador da aba e do cabeçalho.
  int get total => revisao?.total ?? 0;

  /// Rascunhos comuns agrupados por dia, do mais recente.
  List<DiaDeRascunhos> get dias {
    final dias = <DiaDeRascunhos>[];
    for (final rascunho in revisao?.rascunhos ?? const <Rascunho>[]) {
      final data = somenteData(rascunho.item.data);
      if (dias.isEmpty || dias.last.data != data) {
        dias.add((data: data, rascunhos: [rascunho]));
      } else {
        dias.last.rascunhos.add(rascunho);
      }
    }
    return dias;
  }
}

/// A lista da revisão. Fica no topo do app, como o `ContasCubit`: a barra de
/// abas mostra o contador, e as ações na tela atualizam os dois juntos.
class RevisaoCubit extends Cubit<RevisaoEstado> {
  RevisaoCubit(this._revisao, {DateTime Function()? hoje})
    : _hoje = hoje ?? DateTime.now,
      super(RevisaoEstado(hoje: somenteData((hoje ?? DateTime.now)())));

  final RevisaoRepositorio _revisao;

  /// Relido a cada carga: o app fica aberto por dias, e "hoje" muda.
  final DateTime Function() _hoje;

  /// Só a resposta da carga mais recente vale.
  var _versao = 0;

  Future<void> carregar() async {
    final versao = ++_versao;
    emit(
      state.copyWith(hoje: somenteData(_hoje()), carregando: true, erro: null),
    );
    try {
      final revisao = await _revisao.carregar();
      if (isClosed || versao != _versao) return;
      emit(state.copyWith(revisao: revisao, carregando: false));
    } on ErroApi catch (erro) {
      if (isClosed || versao != _versao) return;
      emit(state.copyWith(carregando: false, erro: erro.mensagem));
    }
  }

  /// O ✓ da linha: confirma com a categoria sugerida.
  Future<void> confirmarComSugestao(Rascunho rascunho) async {
    final sugestao = rascunho.sugestao;
    if (sugestao == null || state.enviando) return;
    await _acao(() async {
      await _revisao.confirmar(
        rascunho.item.id,
        descricao: rascunho.item.descricao,
        categoriaId: sugestao.categoria.id,
      );
      return '${rascunho.item.descricao} confirmada como '
          '${sugestao.categoria.nome}.';
    });
  }

  /// "Confirmar N": os rascunhos comuns com sugestão que a tela mostra.
  Future<void> confirmarLote() async {
    final ids = [
      for (final r in state.revisao?.sugeridos ?? const <Rascunho>[]) r.item.id,
    ];
    if (ids.isEmpty || state.enviando) return;
    await _acao(() async {
      final confirmados = await _revisao.confirmarLote(ids);
      return confirmados == 1
          ? '1 rascunho confirmado.'
          : '$confirmados rascunhos confirmados.';
    });
  }

  /// Uma folha terminou uma ação: mostra o [aviso] e recarrega a lista.
  Future<void> concluiu(String aviso) async {
    emit(state.copyWith(aviso: aviso));
    await carregar();
  }

  /// Roda a ação, mostra o aviso (ou o erro) e recarrega: depois de um erro
  /// como "Esta transação já foi revisada.", a lista do app estava velha.
  Future<void> _acao(Future<String> Function() acao) async {
    emit(state.copyWith(enviando: true, aviso: null));
    String aviso;
    try {
      aviso = await acao();
    } on ErroApi catch (erro) {
      aviso = erro.mensagem;
    }
    if (isClosed) return;
    emit(state.copyWith(enviando: false, aviso: aviso));
    await carregar();
  }
}
