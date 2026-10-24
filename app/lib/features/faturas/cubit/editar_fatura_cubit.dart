import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/fatura.dart';
import '../data/faturas_repositorio.dart';

part 'editar_fatura_cubit.freezed.dart';

@freezed
abstract class EditarFaturaEstado with _$EditarFaturaEstado {
  const factory EditarFaturaEstado({
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes da API: `data_fechamento`,
    /// `data_vencimento`, `valor_informado`.
    @Default({}) Map<String, String> erros,
    String? erroGeral,

    /// Preenchido quando salvou: a tela fecha devolvendo o detalhe novo.
    DetalheFatura? salva,
  }) = _EditarFaturaEstado;
}

/// Formulário Editar fatura: datas de fechamento e vencimento e o valor que
/// o banco informou.
class EditarFaturaCubit extends Cubit<EditarFaturaEstado> {
  EditarFaturaCubit(this._faturas, this._contaId, this._competencia)
    : super(const EditarFaturaEstado());

  final FaturasRepositorio _faturas;
  final String _contaId;
  final DateTime _competencia;

  static const _camposDoFormulario = {
    'data_fechamento',
    'data_vencimento',
    'valor_informado',
  };

  /// O usuário mexeu no campo: o erro dele some até o próximo envio.
  void limparErro(String campo) {
    if (!state.erros.containsKey(campo)) return;
    emit(state.copyWith(erros: {...state.erros}..remove(campo)));
  }

  Future<void> salvar({
    required DateTime dataFechamento,
    required DateTime dataVencimento,
    required String valorInformado,
  }) async {
    final semValor = valorInformado.trim().isEmpty;
    final erros = <String, String>{
      if (!somenteData(dataVencimento).isAfter(somenteData(dataFechamento)))
        'data_vencimento': 'O vencimento precisa ser depois do fechamento.',
      if (!semValor) 'valor_informado': ?validarDinheiro(valorInformado),
    };
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }

    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final detalhe = await _faturas.editar(
        _contaId,
        _competencia,
        dataFechamento: somenteData(dataFechamento),
        dataVencimento: somenteData(dataVencimento),
        valorInformado: semValor ? null : lerDinheiro(valorInformado),
      );
      if (isClosed) return;
      emit(state.copyWith(enviando: false, salva: detalhe));
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
