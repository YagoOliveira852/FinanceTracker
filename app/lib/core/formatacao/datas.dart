/// Datas na interface, em pt-BR. Tabelas próprias em vez de `DateFormat`:
/// o design usa formas curtas ("Sex", "out") que o locale pt_BR não gera
/// ("sex.", "out."), e assim nada depende de inicializar locale.
library;

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', //
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

const _diasDaSemana = [
  'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo', //
];

/// Só a data, sem horário: é o que o backend chama de `date`.
DateTime somenteData(DateTime momento) =>
    DateTime(momento.year, momento.month, momento.day);

/// `outubro`, para frases como "Nenhuma transação em outubro".
String nomeDoMes(DateTime data) => _meses[data.month - 1];

/// `Outubro de 2026`.
String formatarMesAno(DateTime data) =>
    '${_maiuscula(_meses[data.month - 1])} de ${data.year}';

/// Cabeçalho de um dia na lista de transações: `Hoje · 20 out`,
/// `Ontem · 19 out` ou `Sex · 16 out`.
String formatarCabecalhoDia(DateTime dia, DateTime hoje) {
  // Em UTC para a conta de dias não sofrer com horário de verão.
  DateTime utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  final diferenca = utc(hoje).difference(utc(dia)).inDays;
  final rotulo = switch (diferenca) {
    0 => 'Hoje',
    1 => 'Ontem',
    _ => _diasDaSemana[dia.weekday - 1].substring(0, 3),
  };
  return '$rotulo · ${dia.day} ${_meses[dia.month - 1].substring(0, 3)}';
}

/// `05/10/2026`.
String formatarData(DateTime data) {
  String doisDigitos(int n) => n.toString().padLeft(2, '0');
  return '${doisDigitos(data.day)}/${doisDigitos(data.month)}/${data.year}';
}

/// `Terça, 20 de outubro`.
String formatarDataLonga(DateTime data) =>
    '${_diasDaSemana[data.weekday - 1]}, ${data.day} de ${_meses[data.month - 1]}';

String _maiuscula(String texto) => texto[0].toUpperCase() + texto.substring(1);
