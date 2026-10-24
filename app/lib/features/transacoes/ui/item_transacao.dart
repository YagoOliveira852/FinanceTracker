import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/lista.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/transacao.dart';

/// Transação numa lista: ícone e cor pelo tipo, selo de rascunho e valor com
/// sinal. Usada em Transações e no detalhe da fatura.
class ItemTransacao extends StatelessWidget {
  const ItemTransacao({
    super.key,
    required this.transacao,
    required this.subtitulo,
  });

  final Transacao transacao;

  /// Texto da segunda linha: a conta, em Transações; a data, na fatura. A
  /// parcela, se houver, vem depois: "15 out · Parcela 3/10".
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final tipo = transacao.tipo;
    final rascunho = transacao.status == StatusTransacao.rascunho;

    // Receita e despesa ganham cor; transferência e pagamento de fatura não
    // são gasto nem renda, então ficam neutros e sem sinal.
    final (corValor, corIcone, fundoIcone) = switch (tipo) {
      _ when rascunho => (
        tipo == TipoTransacao.despesa ? cores.despesa : null,
        cores.rascunho,
        cores.rascunhoContainer,
      ),
      TipoTransacao.receita => (
        cores.receita,
        cores.receita,
        cores.receitaContainer,
      ),
      TipoTransacao.despesa => (
        cores.despesa,
        cores.despesa,
        cores.despesaContainer,
      ),
      _ => (null, null, null),
    };
    final semSinal = switch (tipo) {
      TipoTransacao.transferenciaEntrada ||
      TipoTransacao.transferenciaSaida ||
      TipoTransacao.pagamentoFatura => true,
      _ => false,
    };

    return ItemLista(
      icone: rascunho ? Icons.edit_note_rounded : _icone(tipo),
      corIcone: corIcone,
      fundoIcone: fundoIcone,
      titulo: transacao.descricao,
      subtitulo: Row(
        children: [
          if (rascunho) ...[const _SeloRascunho(), const SizedBox(width: 8)],
          Flexible(
            child: Text(switch (transacao.parcela) {
              final p? => '$subtitulo · Parcela ${p.numero}/${p.total}',
              null => subtitulo,
            }, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      direita: Text(
        semSinal
            ? formatarDinheiro(transacao.valor)
            : formatarDinheiroComSinal(transacao.valor, entrada: tipo.entrada),
        style: context.textos.titleMedium?.copyWith(
          color: corValor,
          fontFeatures: algarismosTabulares,
        ),
      ),
    );
  }

  static IconData _icone(TipoTransacao tipo) => switch (tipo) {
    TipoTransacao.receita => Icons.payments_rounded,
    TipoTransacao.despesa => Icons.shopping_bag_rounded,
    TipoTransacao.transferenciaEntrada ||
    TipoTransacao.transferenciaSaida => Icons.sync_alt_rounded,
    TipoTransacao.pagamentoFatura => Icons.credit_card_rounded,
    TipoTransacao.aporte || TipoTransacao.resgate => Icons.savings_rounded,
    TipoTransacao.estorno => Icons.undo_rounded,
    TipoTransacao.ajusteEntrada ||
    TipoTransacao.ajusteSaida => Icons.tune_rounded,
  };
}

class _SeloRascunho extends StatelessWidget {
  const _SeloRascunho();

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: cores.rascunhoContainer,
        border: Border.all(color: cores.rascunho),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Rascunho',
        style: context.textos.labelMedium?.copyWith(color: cores.rascunho),
      ),
    );
  }
}
