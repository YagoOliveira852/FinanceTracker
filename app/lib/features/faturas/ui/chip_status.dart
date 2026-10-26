import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../data/fatura.dart';

/// Status da fatura: "Aberta" (tonal), "Fechada" (atenção) ou "Paga"
/// (sucesso). [grande] é o chip do detalhe, com ícone e "Fechada · a pagar".
class ChipStatus extends StatelessWidget {
  const ChipStatus(this.status, {super.key, this.grande = false});

  final StatusFatura status;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final cores = context.cores;
    final (rotulo, icone, fundo, cor) = switch (status) {
      StatusFatura.aberta => (
        'Aberta',
        Icons.schedule_rounded,
        esquema.secondaryContainer,
        esquema.onSecondaryContainer,
      ),
      StatusFatura.fechada => (
        grande ? 'Fechada · a pagar' : 'Fechada',
        Icons.lock_rounded,
        cores.ritmoAtencaoContainer,
        cores.ritmoAtencao,
      ),
      StatusFatura.paga => (
        'Paga',
        Icons.check_circle_rounded,
        cores.ritmoOkContainer,
        cores.ritmoOk,
      ),
    };
    final estilo =
        (grande ? context.textos.labelLarge : context.textos.labelMedium)
            ?.copyWith(color: cor);
    return Container(
      height: grande ? 32 : 20,
      padding: EdgeInsets.symmetric(horizontal: grande ? Espaco.x2 : 6),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(grande ? Raio.sm : 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (grande) ...[
            Icon(icone, size: 18, color: cor),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              rotulo,
              style: estilo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
