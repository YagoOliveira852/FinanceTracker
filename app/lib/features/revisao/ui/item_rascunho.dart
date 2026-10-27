import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../transacoes/data/transacao.dart';
import '../data/revisao.dart';

/// Rascunho comum na lista: o círculo ✓ confirma com a sugestão; o resto da
/// linha abre a folha. Sem sugestão, o círculo é só um "?".
class ItemRascunho extends StatelessWidget {
  const ItemRascunho({
    super.key,
    required this.rascunho,
    required this.aoConfirmar,
    required this.aoAbrir,
  });

  final Rascunho rascunho;

  /// Nulo enquanto outra ação está em andamento.
  final VoidCallback? aoConfirmar;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final cores = context.cores;
    final textos = context.textos;
    final item = rascunho.item;
    final sugestao = rascunho.sugestao;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 80),
      child: Row(
        children: [
          const SizedBox(width: Espaco.x2),
          if (sugestao != null)
            IconButton(
              tooltip:
                  'Confirmar ${item.descricao} como '
                  '${sugestao.categoria.nome}',
              onPressed: aoConfirmar,
              style: IconButton.styleFrom(
                backgroundColor: cores.rascunhoContainer,
                foregroundColor: cores.rascunho,
                side: BorderSide(color: cores.rascunho),
              ),
              icon: const Icon(Icons.check_rounded),
            )
          else
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: esquema.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_outline_rounded,
                color: esquema.onSurfaceVariant,
              ),
            ),
          Expanded(
            child: InkWell(
              onTap: aoAbrir,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.x2,
                  Espaco.x3,
                  Espaco.x4,
                  Espaco.x3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.descricao,
                            style: textos.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (sugestao != null)
                            SeloSugestao(sugestao.categoria.nome)
                          else
                            const _SeloSemCategoria(),
                          const SizedBox(height: 2),
                          LinhaDeOrigem(item),
                        ],
                      ),
                    ),
                    const SizedBox(width: Espaco.x4),
                    ValorNaRevisao(item),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "✨ Alimentação": a categoria sugerida pelas regras.
class SeloSugestao extends StatelessWidget {
  const SeloSugestao(this.categoria, {super.key});

  final String categoria;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cores.rascunhoContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: cores.rascunho),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              categoria,
              style: context.textos.labelMedium?.copyWith(
                color: cores.rascunho,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeloSemCategoria extends StatelessWidget {
  const _SeloSemCategoria();

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: esquema.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Sem categoria',
        style: context.textos.labelMedium?.copyWith(
          color: esquema.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// "Open Finance · Conta principal", com o ícone da fonte.
class LinhaDeOrigem extends StatelessWidget {
  const LinhaDeOrigem(this.item, {super.key});

  final ItemRevisao item;

  @override
  Widget build(BuildContext context) {
    final cor = context.esquema.onSurfaceVariant;
    return Row(
      children: [
        Icon(iconeDaFonte(item.fonte), size: 14, color: cor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${item.fonte.rotulo} · ${item.contaNome}',
            style: context.textos.bodySmall?.copyWith(color: cor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// O valor com sinal; transferência e pagamento de fatura ficam sem sinal e
/// neutros (não são gasto nem renda).
class ValorNaRevisao extends StatelessWidget {
  const ValorNaRevisao(this.item, {super.key, this.estilo});

  final ItemRevisao item;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final semSinal = switch (item.tipo) {
      TipoTransacao.transferenciaSaida ||
      TipoTransacao.transferenciaEntrada ||
      TipoTransacao.pagamentoFatura => true,
      _ => false,
    };
    final cor = switch (item.tipo) {
      _ when semSinal => null,
      TipoTransacao.despesa => cores.despesa,
      TipoTransacao.receita => cores.receita,
      _ => null,
    };
    return Text(
      semSinal
          ? formatarDinheiro(item.valor)
          : formatarDinheiroComSinal(item.valor, entrada: item.tipo.entrada),
      style: (estilo ?? context.textos.titleMedium)?.copyWith(
        color: cor,
        fontFeatures: algarismosTabulares,
      ),
    );
  }
}

IconData iconeDaFonte(FonteTransacao fonte) => switch (fonte) {
  FonteTransacao.pluggy => Icons.sync_rounded,
  FonteTransacao.ofx ||
  FonteTransacao.csvMercadopago => Icons.upload_file_rounded,
  FonteTransacao.manual => Icons.edit_rounded,
};
