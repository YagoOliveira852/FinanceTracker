import 'package:flutter/material.dart';

import '../../../app/widgets/estados.dart';

/// Aba Revisão, ainda sem conteúdo (card S4).
class RevisaoTela extends StatelessWidget {
  const RevisaoTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revisão')),
      body: const EstadoVazio(
        icone: Icons.fact_check_rounded,
        titulo: 'Revisão chega em breve',
        texto:
            'Transações importadas de extratos e do Open Finance vão aparecer '
            'aqui como rascunho, para você confirmar a categoria.',
      ),
    );
  }
}
