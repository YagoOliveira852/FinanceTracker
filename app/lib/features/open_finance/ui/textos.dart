/// Frases da tela Open Finance e do card do Início.
library;

import '../../../core/formatacao/datas.dart';
import '../data/open_finance.dart';

/// `hoje, 07:02`, `ontem, 07:01` ou `3 nov, 07:00`, no horário do aparelho.
String quandoFoi(DateTime momento, DateTime agora) {
  final local = momento.toLocal();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final dia = DateTime(local.year, local.month, local.day);
  final hora =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  final diferenca = hoje.difference(dia).inDays;
  final rotulo = switch (diferenca) {
    0 => 'hoje',
    1 => 'ontem',
    -1 => 'amanhã',
    _ => formatarDiaMes(dia),
  };
  return '$rotulo, $hora';
}

/// `15 ago 2027`.
String formatarDiaMesAno(DateTime momento) {
  final local = momento.toLocal();
  return '${formatarDiaMes(local)} ${local.year}';
}

/// Dias inteiros até o consentimento vencer (0 = vence hoje).
int diasAte(DateTime momento, DateTime agora) {
  final local = momento.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime(agora.year, agora.month, agora.day)).inDays;
}

/// Título e texto do card do Início para o problema mais grave.
({String titulo, String texto}) textoDoProblema(
  ProblemaDoInicio problema,
  Conexao? conexao,
  DateTime agora,
) {
  final banco = problema.instituicao;
  final expira = conexao?.consentimentoExpiraEm;
  return switch (problema.problema) {
    ProblemaOpenFinance.vencido => (
      titulo: 'Consentimento vencido',
      texto:
          'O consentimento do $banco venceu'
          '${expira == null ? '' : ' em ${formatarDiaMes(expira.toLocal())}'}. '
          'Sem renovar, as contas dele não recebem dados.',
    ),
    ProblemaOpenFinance.erro => (
      titulo: 'Open Finance com erro',
      texto:
          'O $banco não respondeu às 07:00 nem às 13:00. Os dados de hoje '
          'ainda não chegaram.',
    ),
    ProblemaOpenFinance.semDados => (
      titulo: 'Sem dados novos',
      texto:
          'Nada novo do $banco há mais de 30 horas. O aporte e o alerta podem '
          'estar desatualizados.',
    ),
    ProblemaOpenFinance.vencendo => (
      titulo: expira == null
          ? 'Consentimento vencendo'
          : 'Consentimento vence em ${_dias(diasAte(expira, agora))}',
      texto:
          'Renove o $banco no Meu Pluggy'
          '${expira == null ? '' : ' até ${formatarDiaMes(expira.toLocal())}'} '
          'para não perder dados.',
    ),
  };
}

String _dias(int dias) => switch (dias) {
  <= 0 => 'hoje',
  1 => '1 dia',
  _ => '$dias dias',
};

/// Onde achar o ID do item no dashboard da Pluggy.
const ondeAcharOItem =
    'No dashboard da Pluggy: Demo da aplicação → item do conector MeuPluggy → '
    'copie o id.';
