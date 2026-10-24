/// Frases do Lançamento de compra parcelada.
library;

import 'package:decimal/decimal.dart';

import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/parcelas.dart';

/// "3x de R$ 333,33; a 1ª parcela fica com R$ 333,34." ou, com divisão
/// exata, "3x de R$ 100,00.".
String textoDaDivisao(Decimal total, int quantidade) {
  final parcelas = dividirEmParcelas(total, quantidade);
  final primeira = parcelas.first;
  final demais = parcelas.last;
  final inicio = '${quantidade}x de ${formatarDinheiro(demais)}';
  if (primeira == demais) return '$inicio.';
  return '$inicio; a 1ª parcela fica com ${formatarDinheiro(primeira)}.';
}

/// "A última parcela cai na fatura de janeiro de 2027.", a partir da
/// competência da fatura da compra (a da 1ª parcela).
String textoDaUltimaParcela(DateTime competenciaDaCompra, int quantidade) {
  final ultima = DateTime(
    competenciaDaCompra.year,
    competenciaDaCompra.month + quantidade - 1,
  );
  return 'A última parcela cai na fatura de ${nomeDoMes(ultima)} de '
      '${ultima.year}.';
}
