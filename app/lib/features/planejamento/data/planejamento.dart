import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'planejamento.freezed.dart';

/// Renda prevista: cai todo mês num dia previsto. Nunca é excluída, só
/// desativada; inativa, sai do aporte, do alerta e do lembrete.
@freezed
abstract class Renda with _$Renda {
  const factory Renda({
    required String id,
    required String descricao,

    /// O líquido que cai na conta.
    required Decimal valor,
    required int diaPrevisto,

    /// Onde o crédito aparece primeiro (corrente ou carteira).
    required String contaId,
    required bool ativa,
    required ProximaData proxima,
  }) = _Renda;
}

/// Próxima data esperada de uma renda, a partir de hoje (inclusive).
@freezed
abstract class ProximaData with _$ProximaData {
  const factory ProximaData({
    /// A data efetiva, já em dia útil.
    required DateTime data,

    /// O dia da renda no mês; 29 a 31 em mês mais curto vira o último dia.
    required DateTime dataPrevista,

    /// Feriados da data prevista até a efetiva (exclusive).
    @Default({}) Map<DateTime, String> feriados,
  }) = _ProximaData;
}

/// Dados dos formulários Nova renda e Editar renda.
@freezed
abstract class DadosRenda with _$DadosRenda {
  const factory DadosRenda({
    required String descricao,
    required Decimal valor,
    required int diaPrevisto,
    required String contaId,
    @Default(true) bool ativa,
  }) = _DadosRenda;
}

/// Configuração do cálculo do aporte e da reserva.
@freezed
abstract class Configuracao with _$Configuracao {
  const factory Configuracao({
    /// Fica na conta depois do aporte.
    required Decimal colchao,

    /// Meta da reserva, em meses de gasto (uma casa).
    required Decimal metaReservaMeses,

    /// Piso dos gastos previstos.
    required Decimal gastoSemanalEstimado,

    /// Valor fixo; nulo = automático (média dos 3 últimos meses fechados).
    Decimal? gastoMensalReferencia,
  }) = _Configuracao;
}

/// Gasto mensal automático: a média dos meses fechados do histórico.
@freezed
abstract class GastoMensal with _$GastoMensal {
  const factory GastoMensal({
    required Decimal valor,

    /// Meses da média (1º dia), do mais antigo ao mais recente; até 3.
    required List<DateTime> meses,
  }) = _GastoMensal;
}

/// A configuração salva e o que o cálculo tira do histórico de gastos.
@freezed
abstract class LeituraConfiguracao with _$LeituraConfiguracao {
  const factory LeituraConfiguracao({
    /// Nula até o primeiro salvamento: sem ela, o aporte não é calculado.
    Configuracao? configuracao,

    /// Calculado mesmo com valor fixo salvo; nulo sem nenhum mês fechado.
    GastoMensal? gastoMensalAutomatico,

    /// Gasto médio por semana nas últimas 8; nulo com menos de 4.
    Decimal? mediaSemanalReal,

    /// Quantos meses a reserva cobre hoje; nulo sem gasto mensal.
    Decimal? mesesDeReserva,
  }) = _LeituraConfiguracao;
}
