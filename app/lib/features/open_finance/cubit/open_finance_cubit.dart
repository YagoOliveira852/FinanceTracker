import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/open_finance.dart';
import '../data/open_finance_repositorio.dart';

part 'open_finance_cubit.freezed.dart';

@freezed
sealed class OpenFinanceEstado with _$OpenFinanceEstado {
  const factory OpenFinanceEstado.carregando() = OpenFinanceCarregando;
  const factory OpenFinanceEstado.carregado({
    required ListaConexoes lista,

    /// A conexão com uma ação em andamento (buscar, desativar, reativar).
    String? ocupada,

    /// Resultado da última ação, para o snackbar.
    String? aviso,
  }) = OpenFinanceCarregado;
  const factory OpenFinanceEstado.erro(String mensagem) = OpenFinanceErro;
}

/// Mais → Open Finance: as conexões e o estado do sync.
class OpenFinanceCubit extends Cubit<OpenFinanceEstado> {
  OpenFinanceCubit(this._repositorio)
    : super(const OpenFinanceEstado.carregando());

  final OpenFinanceRepositorio _repositorio;

  Future<void> carregar() async {
    if (state is! OpenFinanceCarregado) {
      emit(const OpenFinanceEstado.carregando());
    }
    try {
      final lista = await _repositorio.listar();
      if (isClosed) return;
      emit(OpenFinanceEstado.carregado(lista: lista));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(OpenFinanceEstado.erro(erro.mensagem));
    }
  }

  /// "Buscar agora": roda o nosso sync da conexão e recarrega o estado.
  Future<void> buscarAgora(String conexaoId) => _acao(conexaoId, () async {
    final resultado = await _repositorio.buscarAgora(conexaoId);
    if (!resultado.ok) return resultado.erro ?? 'A busca falhou.';
    return switch (resultado.novas) {
      0 => 'Nada novo desde a última busca.',
      1 => '1 transação nova na Revisão.',
      final n => '$n transações novas na Revisão.',
    };
  });

  Future<void> desativar(String conexaoId) => _acao(conexaoId, () async {
    await _repositorio.alterarAtiva(conexaoId, ativa: false);
    return 'Conexão desativada. As contas continuam no app.';
  });

  Future<void> reativar(String conexaoId) => _acao(conexaoId, () async {
    await _repositorio.alterarAtiva(conexaoId, ativa: true);
    return 'Conexão reativada. Os dados chegam no próximo sync.';
  });

  void avisoMostrado() {
    if (state case final OpenFinanceCarregado carregado) {
      emit(carregado.copyWith(aviso: null));
    }
  }

  Future<void> _acao(String conexaoId, Future<String> Function() acao) async {
    final atual = state;
    if (atual is! OpenFinanceCarregado || atual.ocupada != null) return;
    emit(atual.copyWith(ocupada: conexaoId, aviso: null));
    String aviso;
    try {
      aviso = await acao();
    } on ErroApi catch (erro) {
      aviso = erro.mensagem;
    }
    try {
      final lista = await _repositorio.listar();
      if (isClosed) return;
      emit(OpenFinanceEstado.carregado(lista: lista, aviso: aviso));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(atual.copyWith(ocupada: null, aviso: erro.mensagem));
    }
  }
}
