import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/tema.dart';
import '../cubit/tema_cubit.dart';

/// Folha de Mais → Aparência: escolher o tema aplica na hora e fecha.
Future<void> abrirAparencia(BuildContext context) {
  final tema = context.read<TemaCubit>();
  return showModalBottomSheet<void>(
    context: context,
    // No navegador raiz, a folha cobre a barra de abas, como no design.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(value: tema, child: const _Aparencia()),
  );
}

class _Aparencia extends StatelessWidget {
  const _Aparencia();

  @override
  Widget build(BuildContext context) {
    final atual = context.watch<TemaCubit>().state;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: Espaco.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.x6,
                0,
                Espaco.x6,
                Espaco.x2,
              ),
              child: Text('Aparência', style: context.textos.titleLarge),
            ),
            RadioGroup<ThemeMode>(
              groupValue: atual,
              onChanged: (modo) {
                if (modo == null) return;
                context.read<TemaCubit>().escolher(modo);
                Navigator.of(context).pop();
              },
              child: const Column(
                children: [
                  _Opcao(
                    ThemeMode.system,
                    'Segue o modo claro ou escuro do Android',
                  ),
                  _Opcao(ThemeMode.light, null),
                  _Opcao(ThemeMode.dark, null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao(this.modo, this.detalhe);

  final ThemeMode modo;
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      value: modo,
      contentPadding: const EdgeInsets.symmetric(horizontal: Espaco.x4),
      title: Text(nomeDoTema(modo)),
      subtitle: detalhe == null ? null : Text(detalhe!),
    );
  }
}
