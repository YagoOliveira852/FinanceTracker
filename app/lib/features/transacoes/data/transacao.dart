import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transacao.freezed.dart';

enum TipoTransacao {
  despesa,
  receita,
  transferenciaSaida,
  transferenciaEntrada,
  pagamentoFatura,
  aporte,
  resgate,
  estorno,
  ajusteEntrada,
  ajusteSaida;

  /// O valor é sempre positivo; o tipo diz se o dinheiro entra ou sai.
  bool get entrada => switch (this) {
    receita ||
    transferenciaEntrada ||
    resgate ||
    estorno ||
    ajusteEntrada => true,
    _ => false,
  };
}

enum StatusTransacao { rascunho, confirmada, ignorada }

@freezed
abstract class Transacao with _$Transacao {
  const factory Transacao({
    required String id,
    required String contaId,
    required TipoTransacao tipo,
    required Decimal valor,
    required DateTime data,
    required String descricao,
    required StatusTransacao status,
  }) = _Transacao;
}

/// Lançamento manual: só despesa ou receita nesta versão.
@freezed
abstract class NovoLancamento with _$NovoLancamento {
  const factory NovoLancamento({
    required String contaId,
    required TipoTransacao tipo,
    required Decimal valor,
    required DateTime data,
    required String descricao,
  }) = _NovoLancamento;
}
