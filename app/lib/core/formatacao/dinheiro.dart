/// Dinheiro na interface: `R$ 1.234,56`. Tudo com `Decimal`; `double` nunca
/// aparece, nem para formatar nem para ler o que o usuário digita.
library;

import 'package:decimal/decimal.dart';

/// Sinal de menos tipográfico (U+2212), como no design: `− R$ 120,40`.
const _menos = '−';

/// NUMERIC(14,2) no Postgres: até 12 dígitos antes da vírgula.
final _limite = Decimal.parse('1000000000000');

/// `1.234,56` ou `1234,56`; vírgula decimal, ponto só como separador de milhar.
final _formato = RegExp(r'^(\d{1,3}(\.\d{3})+|\d+)(,\d+)?$');

/// `R$ 1.234,56`; negativo vira `− R$ 120,40`.
String formatarDinheiro(Decimal valor) {
  final texto = 'R\$ ${_numero(valor.abs())}';
  return valor < Decimal.zero ? '$_menos $texto' : texto;
}

/// Valor de transação, sempre positivo, com o sentido no sinal:
/// `+ R$ 850,00` (entrada) ou `− R$ 187,40` (saída).
String formatarDinheiroComSinal(Decimal valor, {required bool entrada}) {
  return '${entrada ? '+' : _menos} R\$ ${_numero(valor.abs())}';
}

/// Formato do contrato da API: string com ponto e duas casas (`"1234.50"`).
String dinheiroParaApi(Decimal valor) => valor.toStringAsFixed(2);

/// Lê o que o usuário digitou (`1.234,56`, `-120,40`). Devolve `null` se o
/// texto não é um valor; não limita as casas decimais (ver [validarDinheiro]).
Decimal? lerDinheiro(String texto) {
  var limpo = texto.trim().replaceAll(_menos, '-');
  final negativo = limpo.startsWith('-');
  if (negativo) limpo = limpo.substring(1).trim();
  if (!_formato.hasMatch(limpo)) return null;

  final valor = Decimal.parse(limpo.replaceAll('.', '').replaceAll(',', '.'));
  return negativo ? -valor : valor;
}

/// Mensagem de erro para o campo de valor, ou `null` se o texto é válido.
///
/// [exigePositivo]: valor de transação (o sentido vem do tipo).
/// [aceitaNegativo]: saldo inicial, que pode ser negativo.
String? validarDinheiro(
  String texto, {
  bool aceitaNegativo = false,
  bool exigePositivo = false,
}) {
  if (texto.trim().isEmpty) {
    return exigePositivo
        ? 'Informe um valor maior que zero.'
        : 'Informe um valor, por exemplo: 1.234,56.';
  }
  final valor = lerDinheiro(texto);
  if (valor == null) return 'Valor inválido. Use o formato 1.234,56.';
  if (valor.scale > 2) {
    return 'Use no máximo 2 casas decimais, por exemplo: 1.234,56.';
  }
  if (exigePositivo && valor <= Decimal.zero) {
    return 'Informe um valor maior que zero.';
  }
  if (!aceitaNegativo && valor < Decimal.zero) {
    return 'O valor não pode ser negativo.';
  }
  if (valor.abs() >= _limite) return 'Valor alto demais.';
  return null;
}

/// `1234.5` → `1.234,50` (sem sinal).
String _numero(Decimal positivo) {
  final [inteiro, centavos] = positivo.toStringAsFixed(2).split('.');
  final grupos = <String>[];
  for (var fim = inteiro.length; fim > 0; fim -= 3) {
    grupos.insert(0, inteiro.substring(fim - 3 < 0 ? 0 : fim - 3, fim));
  }
  return '${grupos.join('.')},$centavos';
}
