import '../../../core/formatacao/datas.dart';
import 'fatura.dart';

/// Regras do formulário de pagamento de fatura, sem widget nem API.

/// Faturas que o formulário oferece: as anteriores ainda fechadas (a pagar),
/// da mais antiga para a mais recente, e a atual. [incluir] acrescenta uma
/// competência da lista que não entraria (aberto pela tela de uma fatura).
List<ResumoFatura> faturasParaPagar(ListaFaturas lista, {DateTime? incluir}) {
  final opcoes = [
    ...lista.anteriores.where((f) => f.status == StatusFatura.fechada),
    lista.atual,
  ];
  if (incluir != null && !opcoes.any((f) => f.competencia == incluir)) {
    opcoes.addAll(lista.emOrdem.where((f) => f.competencia == incluir));
  }
  return opcoes..sort((a, b) => a.competencia.compareTo(b.competencia));
}

/// A fatura que o formulário escolhe sozinho: a de [incluir], senão a fechada
/// mais antiga a pagar, senão a atual (a última das [opcoes]).
ResumoFatura faturaPadrao(List<ResumoFatura> opcoes, {DateTime? incluir}) =>
    opcoes.where((f) => f.competencia == incluir).firstOrNull ??
    opcoes.where((f) => f.status == StatusFatura.fechada).firstOrNull ??
    opcoes.last;

/// O dinheiro sai no dia do pagamento: registrando depois do débito
/// automático, a data é o vencimento; pagando antes, hoje.
DateTime dataPadraoDoPagamento(ResumoFatura fatura, DateTime hoje) {
  final dia = somenteData(hoje);
  return fatura.dataVencimento.isBefore(dia) ? fatura.dataVencimento : dia;
}
