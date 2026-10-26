import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/datas.dart';
import '../../contas/data/conta.dart';
import '../../contas/data/contas_repositorio.dart';
import '../data/transacao.dart';
import '../data/transacoes_repositorio.dart';

part 'transacoes_cubit.freezed.dart';

/// Transações de um dia, para o cabeçalho "Hoje · 20 out".
@freezed
abstract class DiaDeTransacoes with _$DiaDeTransacoes {
  const factory DiaDeTransacoes({
    required DateTime data,
    required List<Transacao> transacoes,
  }) = _DiaDeTransacoes;
}

@freezed
abstract class TransacoesEstado with _$TransacoesEstado {
  const factory TransacoesEstado({
    required DateTime hoje,

    /// Primeiro dia do mês mostrado.
    required DateTime mes,

    /// Filtro por conta; `null` = todas.
    String? contaId,

    /// Todas as contas: o nome em cada item (a transferência pode citar uma
    /// conta desativada); os chips de filtro usam só as ativas.
    @Default([]) List<Conta> contas,
    @Default([]) List<DiaDeTransacoes> dias,
    @Default(true) bool carregando,
    String? erro,
  }) = _TransacoesEstado;

  const TransacoesEstado._();

  bool get noMesAtual => mes.year == hoje.year && mes.month == hoje.month;

  String? nomeDaConta(String id) =>
      contas.where((c) => c.id == id).firstOrNull?.nome;
}

/// Transações do mês, agrupadas por dia, com filtro por conta.
class TransacoesCubit extends Cubit<TransacoesEstado> {
  TransacoesCubit(this._transacoes, this._contas, {DateTime Function()? hoje})
    : _hoje = hoje ?? DateTime.now,
      super(_inicial(somenteData((hoje ?? DateTime.now)())));

  final TransacoesRepositorio _transacoes;
  final ContasRepositorio _contas;

  /// Relido a cada carga: a aba fica viva por dias, e "hoje" muda.
  final DateTime Function() _hoje;

  /// Só a resposta da carga mais recente vale (troca rápida de mês/filtro).
  var _versao = 0;

  static TransacoesEstado _inicial(DateTime hoje) =>
      TransacoesEstado(hoje: hoje, mes: DateTime(hoje.year, hoje.month));

  Future<void> carregar() async {
    final versao = ++_versao;
    emit(
      state.copyWith(hoje: somenteData(_hoje()), carregando: true, erro: null),
    );
    final mes = state.mes;
    try {
      final resumo = await _contas.listar();
      final transacoes = await _transacoes.listar(
        contaId: state.contaId,
        de: mes,
        ate: DateTime(mes.year, mes.month + 1, 0),
      );
      if (isClosed || versao != _versao) return;
      emit(
        state.copyWith(
          carregando: false,
          contas: resumo.contas,
          dias: _agruparPorDia(transacoes, todas: state.contaId == null),
        ),
      );
    } on ErroApi catch (erro) {
      if (isClosed || versao != _versao) return;
      emit(state.copyWith(carregando: false, erro: erro.mensagem));
    }
  }

  Future<void> mesAnterior() {
    final mes = state.mes;
    emit(state.copyWith(mes: DateTime(mes.year, mes.month - 1), dias: []));
    return carregar();
  }

  Future<void> proximoMes() async {
    final hoje = somenteData(_hoje());
    if (!state.mes.isBefore(DateTime(hoje.year, hoje.month))) return;
    final mes = state.mes;
    emit(state.copyWith(mes: DateTime(mes.year, mes.month + 1), dias: []));
    return carregar();
  }

  Future<void> filtrar(String? contaId) {
    emit(state.copyWith(contaId: contaId, dias: []));
    return carregar();
  }

  /// Ignoradas não aparecem. Com [todas] as contas, a transferência ligada
  /// aparece uma vez só, pelo lado da saída. A API já ordena da mais recente
  /// para a mais antiga; o agrupamento mantém essa ordem.
  static List<DiaDeTransacoes> _agruparPorDia(
    List<Transacao> transacoes, {
    required bool todas,
  }) {
    final porDia = <DateTime, List<Transacao>>{};
    for (final t in transacoes) {
      if (t.status == StatusTransacao.ignorada) continue;
      if (todas &&
          t.tipo == TipoTransacao.transferenciaEntrada &&
          t.transferencia != null) {
        continue;
      }
      porDia.putIfAbsent(somenteData(t.data), () => []).add(t);
    }
    final datas = porDia.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final data in datas)
        DiaDeTransacoes(data: data, transacoes: porDia[data]!),
    ];
  }
}
