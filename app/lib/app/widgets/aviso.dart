import 'package:flutter/material.dart';

import '../tema.dart';

/// Caixa de aviso dentro de um formulário: ícone + texto, fundo tonal.
class Aviso extends StatelessWidget {
  const Aviso({
    super.key,
    required this.icone,
    required this.texto,
    required this.fundo,
    required this.cor,
    this.corIcone,
  });

  /// Erro: fundo e texto do tom de risco.
  factory Aviso.erro(BuildContext context, String mensagem) {
    final cores = context.cores;
    return Aviso(
      icone: Icons.error_rounded,
      texto: Text(
        mensagem,
        style: context.textos.bodyMedium?.copyWith(
          color: cores.ritmoRisco,
          fontWeight: FontWeight.w600,
        ),
      ),
      fundo: cores.ritmoRiscoContainer,
      cor: cores.ritmoRisco,
    );
  }

  final IconData icone;
  final Widget texto;
  final Color fundo;
  final Color cor;
  final Color? corIcone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.x4,
        vertical: Espaco.x3,
      ),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(Raio.md),
      ),
      child: Row(
        children: [
          Icon(icone, color: corIcone ?? cor),
          const SizedBox(width: Espaco.x3),
          Expanded(child: texto),
        ],
      ),
    );
  }
}
