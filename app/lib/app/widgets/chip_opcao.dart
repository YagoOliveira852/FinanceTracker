import 'package:flutter/material.dart';

import '../tema.dart';

/// Chip de escolha única (tipo de conta, tipo de transação, filtro).
/// Selecionado: fundo tonal com ✓. [aoTocar] nulo: desabilitado ("em breve").
class ChipOpcao extends StatelessWidget {
  const ChipOpcao({
    super.key,
    required this.rotulo,
    required this.selecionado,
    required this.aoTocar,
  });

  final String rotulo;
  final bool selecionado;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return FilterChip(
      label: Text(rotulo),
      selected: selecionado,
      onSelected: aoTocar == null ? null : (_) => aoTocar!(),
      showCheckmark: true,
      checkmarkColor: esquema.onSecondaryContainer,
      selectedColor: esquema.secondaryContainer,
      backgroundColor: Colors.transparent,
      labelStyle: context.textos.labelLarge?.copyWith(
        color: selecionado
            ? esquema.onSecondaryContainer
            : esquema.onSurfaceVariant,
      ),
      side: selecionado ? BorderSide.none : BorderSide(color: esquema.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.sm),
      ),
    );
  }
}

/// Selo "Em breve" para itens que ainda não têm tela.
class SeloEmBreve extends StatelessWidget {
  const SeloEmBreve({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Em breve',
        style: context.textos.labelMedium?.copyWith(
          color: esquema.onSurfaceVariant,
        ),
      ),
    );
  }
}
