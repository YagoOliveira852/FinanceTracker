import 'package:decimal/decimal.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/planejamento.dart';
import '../data/planejamento_repositorio.dart';

part 'ajustes_calculo_cubit.freezed.dart';

@freezed
abstract class AjustesCalculoEstado with _$AjustesCalculoEstado {
  const factory AjustesCalculoEstado({
    /// Gasto mensal de referência: automático (média) ou valor fixo.
    required bool automatico,
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes da API.
    @Default({}) Map<String, String> erros,
    String? erroGeral,

    /// Preenchida quando salvou: a tela fecha.
    LeituraConfiguracao? salva,
  }) = _AjustesCalculoEstado;
}

/// Aporte e reserva: colchão, gasto semanal estimado, meta da reserva e
/// gasto mensal de referência. O primeiro salvamento cria a configuração.
class AjustesCalculoCubit extends Cubit<AjustesCalculoEstado> {
  AjustesCalculoCubit(this._planejamento, LeituraConfiguracao leitura)
    : super(
        AjustesCalculoEstado(
          automatico: leitura.configuracao?.gastoMensalReferencia == null,
        ),
      );

  final PlanejamentoRepositorio _planejamento;

  static const _camposDoFormulario = {
    'colchao',
    'gasto_semanal_estimado',
    'meta_reserva_meses',
    'gasto_mensal_referencia',
  };

  void limparErro(String campo) {
    if (!state.erros.containsKey(campo)) return;
    emit(state.copyWith(erros: {...state.erros}..remove(campo)));
  }

  /// No automático, o valor fixo digitado não vale (nem o erro dele).
  void escolherAutomatico(bool automatico) {
    emit(
      state.copyWith(
        automatico: automatico,
        erros: {...state.erros}..remove('gasto_mensal_referencia'),
      ),
    );
  }

  Future<void> salvar({
    required String colchao,
    required String gastoSemanal,
    required String meta,
    required String gastoMensal,
  }) async {
    final metaLida = lerMeses(meta);
    final erros = {
      'colchao': ?validarDinheiro(colchao),
      'gasto_semanal_estimado': ?validarDinheiro(gastoSemanal),
      if (metaLida == null)
        'meta_reserva_meses':
            'Informe a meta em meses, com até uma casa: 6 ou 4,5.'
      else if (metaLida <= Decimal.zero)
        'meta_reserva_meses': 'A meta precisa ser maior que zero.',
      if (!state.automatico)
        'gasto_mensal_referencia': ?validarDinheiro(
          gastoMensal,
          exigePositivo: true,
        ),
    };
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }
    final configuracao = Configuracao(
      colchao: lerDinheiro(colchao)!,
      metaReservaMeses: metaLida!,
      gastoSemanalEstimado: lerDinheiro(gastoSemanal)!,
      gastoMensalReferencia: state.automatico ? null : lerDinheiro(gastoMensal),
    );
    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final leitura = await _planejamento.salvarConfiguracao(configuracao);
      if (isClosed) return;
      emit(state.copyWith(enviando: false, salva: leitura));
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

/// Meta da reserva digitada (`6`, `4,5`): até 3 dígitos e uma casa, ou nulo.
Decimal? lerMeses(String texto) {
  final limpo = texto.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,3}(\.\d)?$').hasMatch(limpo)) return null;
  return Decimal.parse(limpo);
}
