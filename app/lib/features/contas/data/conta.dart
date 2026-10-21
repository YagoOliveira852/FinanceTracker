import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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
  }) = _Conta;

  const Conta._();

  /// Conta que recebe lançamento manual nesta versão (cartão chega na S3).
  bool get aceitaLancamento => ativa && tipo != TipoConta.cartaoCredito;
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
