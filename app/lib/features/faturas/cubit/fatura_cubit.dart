import 'package:decimal/decimal.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../transacoes/data/transacao.dart';
import '../data/fatura.dart';
import '../data/faturas_repositorio.dart';

part 'fatura_cubit.freezed.dart';

@freezed
sealed class FaturaEstado with _$FaturaEstado {
  const factory FaturaEstado.carregando() = FaturaCarregando;
  const factory FaturaEstado.carregada(
    DetalheFatura detalhe, {

    /// O ajuste para o valor real está sendo enviado.
    @Default(false) bool ajustando,

    /// Por que o último ajuste não foi feito (valor inválido, erro da API).
    String? erroAjuste,
  }) = FaturaCarregada;
  const factory FaturaEstado.erro(String mensagem) = FaturaErro;
}

/// Detalhe de uma fatura do cartão; as setas da tela trocam a competência.
class FaturaCubit extends Cubit<FaturaEstado> {
  FaturaCubit(this._faturas, this._contaId)
    : super(const FaturaEstado.carregando());

  final FaturasRepositorio _faturas;
  final String _contaId;

  /// Só a resposta da competência pedida por último vale.
  var _versao = 0;

  Future<void> carregar(DateTime competencia) async {
    final versao = ++_versao;
    emit(const FaturaEstado.carregando());
    try {
      final detalhe = await _faturas.obter(_contaId, competencia);
      if (isClosed || versao != _versao) return;
      emit(FaturaEstado.carregada(detalhe));
    } on ErroApi catch (erro) {
      if (isClosed || versao != _versao) return;
      emit(FaturaEstado.erro(erro.mensagem));
    }
  }

  /// Fatura editada em outra tela: mostra o detalhe que ela devolveu.
  void atualizar(DetalheFatura detalhe) =>
      emit(FaturaEstado.carregada(detalhe));

  /// Ajusta a fatura para [valorReal] (texto digitado, `1.032,15`).
  Future<void> ajustar({
    required String valorReal,
    required String descricao,
  }) async {
    final atual = state;
    if (atual is! FaturaCarregada || atual.ajustando) return;
    final erro = validarDinheiro(valorReal);
    if (erro != null) {
      emit(atual.copyWith(erroAjuste: erro));
      return;
    }
    emit(atual.copyWith(ajustando: true, erroAjuste: null));
    try {
      final detalhe = await _faturas.ajustar(
        _contaId,
        atual.detalhe.resumo.competencia,
        valorReal: lerDinheiro(valorReal)!,
        descricao: descricao.trim().isEmpty ? null : descricao.trim(),
      );
      if (isClosed) return;
      emit(FaturaEstado.carregada(detalhe));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(
        atual.copyWith(
          ajustando: false,
          erroAjuste:
              erro.campos['valor_real'] ??
              erro.campos['descricao'] ??
              erro.mensagem,
        ),
      );
    }
  }
}

/// Calculado sem o ajuste que a fatura já tem: base para dizer quanto o
/// próximo ajuste vai lançar.
Decimal calculadoSemAjuste(DetalheFatura detalhe) {
  var total = detalhe.resumo.valorCalculado;
  for (final t in detalhe.transacoes) {
    if (t.tipo == TipoTransacao.ajusteSaida) total -= t.valor;
    if (t.tipo == TipoTransacao.ajusteEntrada) total += t.valor;
  }
  return total;
}
