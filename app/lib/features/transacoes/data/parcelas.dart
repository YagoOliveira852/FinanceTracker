/// Divisão de uma compra parcelada, a mesma regra do backend
/// (`transacoes/parcelas.py`): cada parcela é o total dividido por N,
/// truncado no centavo, e o que sobra vai inteiro para a 1ª. Serve só para o
/// texto do Lançamento; quem grava os valores é a API.
library;

import 'package:decimal/decimal.dart';

final _cem = Decimal.fromInt(100);

/// Valores das parcelas, da 1ª à última; a soma é sempre o [total].
///
/// [ArgumentError] se o total não dá um centavo para cada parcela.
List<Decimal> dividirEmParcelas(Decimal total, int quantidade) {
  final centavos = (total * _cem).toBigInt();
  final base = centavos ~/ BigInt.from(quantidade);
  if (base < BigInt.one) {
    throw ArgumentError.value(
      total,
      'total',
      'não dá um centavo para cada uma de $quantidade parcelas',
    );
  }
  final resto = centavos - base * BigInt.from(quantidade);
  Decimal reais(BigInt centavos) =>
      (Decimal.fromBigInt(centavos) / _cem).toDecimal();
  return [reais(base + resto), ...List.filled(quantidade - 1, reais(base))];
}
