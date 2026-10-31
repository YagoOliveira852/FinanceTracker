import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'resumo.freezed.dart';

/// Nível do alerta de ritmo: a sobra até o próximo salário contra o colchão.
enum NivelRitmo {
  /// A sobra cobre o colchão.
  verde,

  /// Vai consumir o colchão.
  amarelo,

  /// Exigiria resgatar a reserva.
  vermelho,
}

/// O que o Início mostra (`GET /planejamento/resumo`).
@freezed
abstract class Resumo with _$Resumo {
  const factory Resumo({
    /// Correntes e carteiras ativas, com rascunhos e sem possíveis duplicatas.
    required Decimal saldoDisponivel,

    /// Rascunhos que o cálculo considera.
    required int rascunhos,

    /// Nula sem renda prevista ativa ou sem configuração salva.
    Previsao? previsao,

    /// Nulo sem valor fixo nem mês fechado no histórico.
    GastoMensalReferencia? gastoMensal,

    /// Nula sem configuração salva.
    Decimal? metaReservaMeses,
  }) = _Resumo;
}

/// Projeção até o próximo salário: a sobra e o alerta são a mesma conta.
@freezed
abstract class Previsao with _$Previsao {
  const factory Previsao({
    /// A data efetiva; pode ser hoje ou já ter passado (salário atrasado).
    required DateTime proximoSalario,

    /// Hoje entra, o dia do salário não.
    required int diasAteSalario,

    /// Em ordem de vencimento.
    @Default([]) List<FaturaReservada> faturas,
    required Decimal gastosPrevistos,

    /// A média real das últimas semanas passou do gasto semanal estimado.
    required bool gastosPelaMedia,

    /// Pode ser negativa.
    required Decimal sobra,
    required NivelRitmo nivel,
    required Decimal colchao,

    /// Salário detectado cuja janela ainda está aberta.
    SalarioRecebido? salarioRecebido,

    /// Sobra − colchão, nunca negativo; só existe com o salário recebido.
    Decimal? aporte,
  }) = _Previsao;
}

/// O que falta pagar de uma fatura que vence até o próximo salário.
@freezed
abstract class FaturaReservada with _$FaturaReservada {
  const factory FaturaReservada({
    required String cartaoId,

    /// Nome do cartão.
    required String cartao,
    required DateTime competencia,
    required DateTime vencimento,
    required Decimal valor,
  }) = _FaturaReservada;
}

/// Receita reconhecida como o salário de uma renda: dispara o aporte.
@freezed
abstract class SalarioRecebido with _$SalarioRecebido {
  const factory SalarioRecebido({
    required String rendaId,

    /// Descrição da renda.
    required String descricao,
    required String contaId,

    /// Nome da conta onde caiu.
    required String conta,

    /// Data efetiva da renda neste ciclo; com a renda, identifica o salário.
    required DateTime dataEsperada,

    /// Data do crédito.
    required DateTime data,
    required Decimal valor,
  }) = _SalarioRecebido;
}

/// Gasto mensal que divide a reserva: a média dos meses fechados ou o fixo.
@freezed
abstract class GastoMensalReferencia with _$GastoMensalReferencia {
  const factory GastoMensalReferencia({
    required Decimal valor,
    required bool automatico,
  }) = _GastoMensalReferencia;
}
