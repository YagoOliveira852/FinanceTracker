import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../faturas/data/fatura.dart';

part 'conta.freezed.dart';

enum TipoConta { corrente, cartaoCredito, carteira }

@freezed
abstract class Conta with _$Conta {
  const factory Conta({
    required String id,
    required String nome,
    required TipoConta tipo,

    /// Nome da instituição; a carteira não tem.
    String? instituicao,
    required Decimal saldoInicial,
    required DateTime dataSaldoInicial,
    required Decimal saldoAtual,
    required bool ativa,

    /// Dados do cartão; nulo se a conta não é cartão de crédito.
    Cartao? cartao,
  }) = _Conta;

  const Conta._();

  /// Lançamento manual de despesa: qualquer conta ativa (no cartão, compra).
  bool get recebeDespesa => ativa;

  /// Receita não entra em cartão de crédito.
  bool get recebeReceita => ativa && tipo != TipoConta.cartaoCredito;
}

@freezed
abstract class Cartao with _$Cartao {
  const factory Cartao({
    /// Conta corrente que paga a fatura.
    required String contaPagamentoId,
    required int diaFechamento,
    required int diaVencimento,
    Decimal? limite,

    /// A fatura de uma compra feita hoje.
    required ResumoFatura faturaAtual,
  }) = _Cartao;
}

@freezed
abstract class ResumoContas with _$ResumoContas {
  const factory ResumoContas({
    /// Correntes e carteiras ativas; cartão não entra.
    required Decimal totalDisponivel,
    required List<Conta> contas,
  }) = _ResumoContas;
}

/// Dados do formulário Nova conta.
@freezed
abstract class NovaConta with _$NovaConta {
  const factory NovaConta({
    required String nome,
    required TipoConta tipo,
    String? instituicao,
    required Decimal saldoInicial,
    required DateTime dataSaldoInicial,
  }) = _NovaConta;
}

/// Dados do formulário Nova conta para cartão de crédito (sem saldo inicial).
@freezed
abstract class NovoCartao with _$NovoCartao {
  const factory NovoCartao({
    required String nome,
    required String instituicao,
    required String contaPagamentoId,
    required int diaFechamento,
    required int diaVencimento,
    Decimal? limite,
  }) = _NovoCartao;
}
