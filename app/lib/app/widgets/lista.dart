import 'package:flutter/material.dart';

import '../tema.dart';

/// Grupo de itens com borda arredondada e divisórias, como no design.
class GrupoLista extends StatelessWidget {
  const GrupoLista({super.key, required this.itens});

  final List<Widget> itens;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLow,
        border: Border.all(color: esquema.outlineVariant),
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Raio.lg - 1),
        child: Column(
          children: [
            for (final (i, item) in itens.indexed) ...[
              if (i > 0) const Divider(),
              item,
            ],
          ],
        ),
      ),
    );
  }
}

/// Título de seção acima de um [GrupoLista].
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.pequeno = false});

  final String texto;

  /// Rótulo pequeno (caption), como em Mais e nos dias de Transações.
  final bool pequeno;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaco.x1,
        Espaco.x2,
        Espaco.x1,
        Espaco.x2,
      ),
      child: Text(
        texto,
        style: pequeno
            ? textos.bodySmall?.copyWith(fontWeight: FontWeight.w600)
            : textos.titleMedium,
      ),
    );
  }
}

/// Item de lista de duas linhas (72 px) com ícone num círculo à esquerda.
class ItemLista extends StatelessWidget {
  const ItemLista({
    super.key,
    required this.icone,
    required this.titulo,
    this.subtitulo,
    this.direita,
    this.corIcone,
    this.fundoIcone,
    this.aoTocar,
    this.habilitado = true,
  });

  final IconData icone;
  final String titulo;
  final Widget? subtitulo;
  final Widget? direita;
  final Color? corIcone;
  final Color? fundoIcone;
  final VoidCallback? aoTocar;

  /// Desabilitado: item "em breve", visível e sem ação.
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    final conteudo = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.x4,
        vertical: Espaco.x3,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fundoIcone ?? esquema.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: corIcone ?? esquema.onSecondaryContainer),
          ),
          const SizedBox(width: Espaco.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: textos.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitulo != null)
                  DefaultTextStyle.merge(
                    style: textos.bodySmall,
                    child: subtitulo!,
                  ),
              ],
            ),
          ),
          if (direita != null) ...[const SizedBox(width: Espaco.x4), direita!],
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Opacity(
        opacity: habilitado ? 1 : 0.6,
        child: aoTocar == null || !habilitado
            ? conteudo
            : InkWell(onTap: aoTocar, child: conteudo),
      ),
    );
  }
}
