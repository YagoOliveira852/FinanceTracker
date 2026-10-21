import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/tema.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/cubit/contas_cubit.dart';

/// Início desta versão: saldo disponível e o aviso de que aporte e alerta de
/// ritmo chegam depois (card S6). O design completo está no canvas.
class InicioTela extends StatelessWidget {
  const InicioTela({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    final esquema = context.esquema;
    final estado = context.watch<ContasCubit>().state;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatarDataLonga(DateTime.now()), style: textos.bodySmall),
            const Text('Início'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: context.read<ContasCubit>().carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.x4,
            Espaco.x2,
            Espaco.x4,
            Espaco.x4,
          ),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Espaco.x5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo disponível', style: textos.bodySmall),
                    const SizedBox(height: Espaco.x1),
                    switch (estado) {
                      ContasCarregando() => const Padding(
                        padding: EdgeInsets.symmetric(vertical: Espaco.x2),
                        child: LinearProgressIndicator(),
                      ),
                      ContasErro(:final mensagem) => Text(
                        mensagem,
                        style: textos.bodyMedium?.copyWith(
                          color: esquema.error,
                        ),
                      ),
                      ContasCarregado(:final resumo) => Text(
                        formatarDinheiro(resumo.totalDisponivel),
                        style: textos.headlineMedium?.copyWith(
                          fontFeatures: algarismosTabulares,
                        ),
                      ),
                    },
                    const SizedBox(height: Espaco.x1),
                    Text(
                      'Contas correntes e carteira.',
                      style: textos.bodyMedium?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Espaco.x4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Espaco.x5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: esquema.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_repeat_rounded,
                        color: esquema.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: Espaco.x3),
                    Text(
                      'Aporte e alerta chegam em breve',
                      style: textos.titleLarge,
                    ),
                    const SizedBox(height: Espaco.x2),
                    Text(
                      'Com o salário cadastrado, o app vai calcular quanto dá '
                      'para aportar e avisar se o ritmo de gastos ameaça a '
                      'reserva.',
                      style: textos.bodyMedium?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
