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

    /// Fatura da transação, quando a conta é cartão de crédito.
    String? faturaId,

    /// Número da parcela, quando é compra parcelada.
    Parcela? parcela,

    /// O outro lado e as duas contas, quando é transferência ligada.
    ParTransferencia? transferencia,
  }) = _Transacao;
}

/// Transferência entre contas próprias: o outro lado ([parId]) e as contas
/// de origem e destino, iguais nos dois lados.
@freezed
abstract class ParTransferencia with _$ParTransferencia {
  const factory ParTransferencia({
    required String parId,
    required String contaOrigemId,
    required String contaDestinoId,
  }) = _ParTransferencia;
}

/// "Parcela 3/10": a [numero] de [total] parcelas de uma compra.
@freezed
abstract class Parcela with _$Parcela {
  const factory Parcela({required int numero, required int total}) = _Parcela;
}

/// Lançamento manual de despesa ou receita (transferência e pagamento de
/// fatura têm modelos próprios).
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

/// Compra parcelada no cartão: a API gera uma despesa por parcela.
@freezed
abstract class NovaCompraParcelada with _$NovaCompraParcelada {
  const factory NovaCompraParcelada({
    required String contaId,
    required Decimal valorTotal,
    required int qtdParcelas,
    required DateTime dataCompra,
    required String descricao,
  }) = _NovaCompraParcelada;
}

/// Transferência entre contas próprias: a API grava a saída na origem e a
/// entrada no destino, ligadas. Sem [descricao], "Transferência".
@freezed
abstract class NovaTransferencia with _$NovaTransferencia {
  const factory NovaTransferencia({
    required String contaOrigemId,
    required String contaDestinoId,
    required Decimal valor,
    required DateTime data,
    String? descricao,
  }) = _NovaTransferencia;
}
