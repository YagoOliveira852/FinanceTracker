import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fatura.freezed.dart';

/// Aberta antes do fechamento; fechada a partir dele. "Paga" chega com o
/// pagamento de fatura.
enum StatusFatura { aberta, fechada }

/// Competência (primeiro dia do mês do vencimento) e datas efetivas, já
/// ajustadas para dia útil.
@freezed
abstract class DatasFatura with _$DatasFatura {
  const factory DatasFatura({
    required DateTime competencia,
    required DateTime dataFechamento,
    required DateTime dataVencimento,
  }) = _DatasFatura;
}

@freezed
abstract class ResumoFatura with _$ResumoFatura {
  const factory ResumoFatura({
    required DateTime competencia,
    required DateTime dataFechamento,
    required DateTime dataVencimento,
    required StatusFatura status,

    /// O maior entre o informado pelo banco e o calculado.
    required Decimal valor,

    /// Compras menos estornos lançados na fatura.
    required Decimal valorCalculado,

    /// O total que o banco mostra; nulo enquanto não informado.
    Decimal? valorInformado,
  }) = _ResumoFatura;
}
