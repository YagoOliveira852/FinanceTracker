import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../transacoes/data/transacao.dart';

/// Um pagamento no resumo da fatura: "Paga em qua, 9 set" (ou "Pagamento
/// em …", "Pagamento adiantado em …"), a conta que pagou e o valor.
class QuadroPagamento extends StatelessWidget {
  const QuadroPagamento(
    this.pagamento, {
    super.key,
    required this.rotulo,
    required this.nomeDaConta,
  });

  final Transacao pagamento;

  /// "Paga em", "Pagamento em" ou "Pagamento adiantado em".
  final String rotulo;
  final String nomeDaConta;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    return Container(
      padding: const EdgeInsets.all(Espaco.x3),
      decoration: BoxDecoration(
        color: esquema.surfaceContainer,
        borderRadius: BorderRadius.circular(Raio.md),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: esquema.surfaceContainerHighest,
            child: Icon(
              Icons.account_balance_rounded,
              size: 20,
              color: esquema.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Espaco.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rotulo ${formatarDiaCurto(pagamento.data)}',
                  style: textos.titleSmall,
                ),
                Text(
                  nomeDaConta,
                  style: textos.bodySmall?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            formatarDinheiro(pagamento.valor),
            style: textos.titleSmall?.copyWith(
              fontFeatures: algarismosTabulares,
            ),
          ),
        ],
      ),
    );
  }
}
