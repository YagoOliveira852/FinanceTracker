import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/fatura.dart';
import '../data/faturas_repositorio.dart';
import '../data/pagamento.dart';

part 'pagamento_cubit.freezed.dart';

@freezed
abstract class PagamentoEstado with _$PagamentoEstado {
  const factory PagamentoEstado({
    /// Cartão escolhido; as faturas são as dele.
    String? cartaoId,

    /// Faturas oferecidas (ver [faturasParaPagar]).
    @Default([]) List<ResumoFatura> faturas,

    /// Competência da fatura escolhida.
    DateTime? competencia,
    @Default(false) bool carregando,
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes do formulário: `conta_id`, `valor`,
    /// `data`.
    @Default({}) Map<String, String> erros,
    String? erroGeral,

    /// O detalhe da fatura depois do pagamento: a tela fecha.
    DetalheFatura? salvo,
  }) = _PagamentoEstado;

  const PagamentoEstado._();

  ResumoFatura? get fatura =>
      faturas.where((f) => f.competencia == competencia).firstOrNull;
}

/// Formulário de pagamento de fatura: cartão, fatura, conta que paga, valor
/// e data.
class PagamentoCubit extends Cubit<PagamentoEstado> {
  PagamentoCubit(this._faturas) : super(const PagamentoEstado());

  final FaturasRepositorio _faturas;

  /// Só a resposta do cartão escolhido por último vale.
  var _versao = 0;

  static const _camposDoFormulario = {
    'conta_id': 'conta_id',
    'valor': 'valor',
    'data': 'data',
  };

  /// Carrega as faturas do cartão e escolhe a padrão; [competencia] é a da
  /// tela de onde o formulário foi aberto.
  Future<void> escolherCartao(String cartaoId, {DateTime? competencia}) async {
    final versao = ++_versao;
    emit(
      PagamentoEstado(cartaoId: cartaoId, carregando: true, erros: state.erros),
    );
    try {
      final lista = await _faturas.listar(cartaoId);
      if (isClosed || versao != _versao) return;
      final faturas = faturasParaPagar(lista, incluir: competencia);
      emit(
        state.copyWith(
          carregando: false,
          faturas: faturas,
          competencia: faturaPadrao(faturas, incluir: competencia).competencia,
        ),
      );
    } on ErroApi catch (erro) {
      if (isClosed || versao != _versao) return;
      emit(state.copyWith(carregando: false, erroGeral: erro.mensagem));
    }
  }

  void escolherFatura(DateTime competencia) =>
      emit(state.copyWith(competencia: competencia));

  /// O usuário mexeu no campo: o erro dele some até o próximo envio.
  void limparErro(String campo) {
    if (!state.erros.containsKey(campo)) return;
    emit(state.copyWith(erros: {...state.erros}..remove(campo)));
  }

  Future<void> salvar({
    required String? contaId,
    required String valor,
    required DateTime data,
  }) async {
    final cartaoId = state.cartaoId;
    final competencia = state.competencia;
    if (cartaoId == null || competencia == null) return;
    final erros = <String, String>{
      if (contaId == null) 'conta_id': 'Escolha a conta que paga.',
      'valor': ?validarDinheiro(valor, exigePositivo: true),
    };
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }

    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final detalhe = await _faturas.pagar(
        cartaoId,
        competencia,
        NovoPagamento(
          contaId: contaId!,
          valor: lerDinheiro(valor)!,
          data: somenteData(data),
        ),
      );
      if (isClosed) return;
      emit(state.copyWith(enviando: false, salvo: detalhe));
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
