import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/transacao.dart';
import '../data/transacoes_repositorio.dart';

part 'transferencia_cubit.freezed.dart';

@freezed
abstract class TransferenciaEstado with _$TransferenciaEstado {
  const factory TransferenciaEstado({
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes do formulário: `origem`, `destino`,
    /// `valor`, `data`, `descricao`.
    @Default({}) Map<String, String> erros,
    String? erroGeral,

    /// O lado da saída, quando a transferência foi salva: a tela fecha.
    Transacao? salva,
  }) = _TransferenciaEstado;
}

/// Formulário de transferência entre contas próprias (corrente e carteira).
class TransferenciaCubit extends Cubit<TransferenciaEstado> {
  TransferenciaCubit(this._transacoes) : super(const TransferenciaEstado());

  final TransacoesRepositorio _transacoes;

  /// Campo da API → campo do formulário.
  static const _camposDoFormulario = {
    'conta_origem_id': 'origem',
    'conta_destino_id': 'destino',
    'valor': 'valor',
    'data': 'data',
    'descricao': 'descricao',
  };

  /// O usuário mexeu no campo: o erro dele some até o próximo envio.
  void limparErro(String campo) {
    if (!state.erros.containsKey(campo)) return;
    emit(state.copyWith(erros: {...state.erros}..remove(campo)));
  }

  Future<void> salvar({
    required String? origemId,
    required String? destinoId,
    required String valor,
    required DateTime data,
    required String descricao,
  }) async {
    final erros = <String, String>{
      if (origemId == null) 'origem': 'Escolha a conta de origem.',
      if (destinoId == null) 'destino': 'Escolha a conta de destino.',
      'valor': ?validarDinheiro(valor, exigePositivo: true),
    };
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }

    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final saida = await _transacoes.transferir(
        NovaTransferencia(
          contaOrigemId: origemId!,
          contaDestinoId: destinoId!,
          valor: lerDinheiro(valor)!,
          data: somenteData(data),
          descricao: descricao.trim().isEmpty ? null : descricao.trim(),
        ),
      );
      if (isClosed) return;
      emit(state.copyWith(enviando: false, salva: saida));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      final doFormulario = {
        for (final MapEntry(:key, :value) in erro.campos.entries)
          ?_camposDoFormulario[key]: value,
      };
      emit(
        state.copyWith(
          enviando: false,
          erros: doFormulario,
          erroGeral: doFormulario.isEmpty ? erro.mensagem : null,
        ),
      );
    }
  }
}
