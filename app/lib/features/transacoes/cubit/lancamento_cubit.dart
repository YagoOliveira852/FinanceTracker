import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/transacao.dart';
import '../data/transacoes_repositorio.dart';

part 'lancamento_cubit.freezed.dart';

@freezed
abstract class LancamentoEstado with _$LancamentoEstado {
  const factory LancamentoEstado({
    @Default(TipoTransacao.despesa) TipoTransacao tipo,
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes da API: `conta_id`, `valor`, `data`,
    /// `descricao`.
    @Default({}) Map<String, String> erros,
    String? erroGeral,

    /// Preenchida quando o lançamento foi salvo: a tela fecha.
    Transacao? salva,
  }) = _LancamentoEstado;
}

/// Formulário de lançamento manual (despesa ou receita).
class LancamentoCubit extends Cubit<LancamentoEstado> {
  LancamentoCubit(this._transacoes) : super(const LancamentoEstado());

  final TransacoesRepositorio _transacoes;

  static const _camposDoFormulario = {'conta_id', 'valor', 'data', 'descricao'};

  void escolherTipo(TipoTransacao tipo) {
    assert(tipo == TipoTransacao.despesa || tipo == TipoTransacao.receita);
    emit(state.copyWith(tipo: tipo));
  }

  Future<void> salvar({
    required String? contaId,
    required String valor,
    required DateTime data,
    required String descricao,
  }) async {
    final erros = <String, String>{
      if (contaId == null) 'conta_id': 'Escolha uma conta.',
      'valor': ?validarDinheiro(valor, exigePositivo: true),
      if (descricao.trim().isEmpty)
        'descricao': 'Descreva a transação, por exemplo: Mercado.',
    };
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }

    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final transacao = await _transacoes.lancar(
        NovoLancamento(
          contaId: contaId!,
          tipo: state.tipo,
          valor: lerDinheiro(valor)!,
          data: somenteData(data),
          descricao: descricao.trim(),
        ),
      );
      if (isClosed) return;
      emit(state.copyWith(enviando: false, salva: transacao));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      final doFormulario = {
        for (final MapEntry(:key, :value) in erro.campos.entries)
          if (_camposDoFormulario.contains(key)) key: value,
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
