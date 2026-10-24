import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../transacoes/data/transacao.dart';

part 'fatura.freezed.dart';

/// Aberta antes do fechamento; fechada a partir dele. "Paga" chega com o
/// pagamento de fatura.
enum StatusFatura { aberta, fechada }

/// Competência na URL da API: `2026-11`.
String competenciaParaApi(DateTime competencia) =>
    '${competencia.year}-${competencia.month.toString().padLeft(2, '0')}';

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

  const ResumoFatura._();

  /// Informado menos calculado: positivo = faltam lançamentos; negativo =
  /// lançado a mais. Nula sem valor informado ou quando os dois batem.
  Decimal? get diferenca {
    final informado = valorInformado;
    if (informado == null || informado == valorCalculado) return null;
    return informado - valorCalculado;
  }
}

/// Por que a data efetiva não é a prevista (o dia do cartão no mês).
@freezed
abstract class AjusteData with _$AjusteData {
  const factory AjusteData({
    required DateTime dataPrevista,

    /// Feriados pulados até a data efetiva; vazio se só o fim de semana pesou.
    required Map<DateTime, String> feriados,
  }) = _AjusteData;
}

@freezed
abstract class DetalheFatura with _$DetalheFatura {
  const factory DetalheFatura({
    required ResumoFatura resumo,

    /// Datas pela regra do cartão, ignorando edições.
    required DateTime fechamentoCalculado,
    required DateTime vencimentoCalculado,
    AjusteData? ajusteFechamento,
    AjusteData? ajusteVencimento,

    /// Sem as ignoradas, das mais recentes para as mais antigas.
    required List<Transacao> transacoes,
  }) = _DetalheFatura;
}

@freezed
abstract class ListaFaturas with _$ListaFaturas {
  const factory ListaFaturas({
    /// A fatura de uma compra feita hoje.
    required ResumoFatura atual,

    /// Gravadas depois da atual, da mais próxima para a mais distante.
    required List<ResumoFatura> proximas,

    /// Gravadas antes da atual, da mais recente para a mais antiga.
    required List<ResumoFatura> anteriores,
  }) = _ListaFaturas;

  const ListaFaturas._();

  /// Da mais distante no futuro à mais antiga, como aparecem na tela; as
  /// setas do detalhe seguem esta ordem.
  List<ResumoFatura> get emOrdem => [
    ...proximas.reversed,
    atual,
    ...anteriores,
  ];
}
