import 'package:flutter/material.dart';

import '../tema.dart';

/// Tela ou área sem conteúdo: ícone num círculo, título, explicação e ação.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.texto,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Espaco.x8,
          Espaco.x8,
          Espaco.x8,
          Espaco.x12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: esquema.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 36, color: esquema.onSecondaryContainer),
            ),
            const SizedBox(height: Espaco.x4),
            Text(titulo, style: textos.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: Espaco.x4),
            Text(
              texto,
              style: textos.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (acao != null) ...[const SizedBox(height: Espaco.x6), acao!],
          ],
        ),
      ),
    );
  }
}

/// Falha ao carregar: mensagem e "Tentar de novo".
class ErroComTentar extends StatelessWidget {
  const ErroComTentar({
    super.key,
    required this.mensagem,
    required this.aoTentar,
  });

  final String mensagem;
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    return EstadoVazio(
      icone: Icons.cloud_off_rounded,
      titulo: 'Não deu para carregar',
      texto: mensagem,
      acao: FilledButton.tonal(
        onPressed: aoTentar,
        child: const Text('Tentar de novo'),
      ),
    );
  }
}

/// Indicador de carregamento centralizado.
class Carregando extends StatelessWidget {
  const Carregando({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
