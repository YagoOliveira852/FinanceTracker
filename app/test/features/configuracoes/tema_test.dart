import 'package:bloc_test/bloc_test.dart';
import 'package:financas/features/configuracoes/cubit/tema_cubit.dart';
import 'package:financas/features/configuracoes/data/preferencia_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/preferencia_tema_falsa.dart';

void main() {
  group('TemaCubit', () {
    blocTest<TemaCubit, ThemeMode>(
      'abre no tema guardado',
      build: () => TemaCubit(PreferenciaTemaFalsa(ThemeMode.dark)),
      act: (cubit) => cubit.iniciar(),
      expect: () => [ThemeMode.dark],
    );

    late PreferenciaTemaFalsa preferencia;
    blocTest<TemaCubit, ThemeMode>(
      'escolher aplica e guarda para a próxima abertura',
      build: () {
        preferencia = PreferenciaTemaFalsa();
        return TemaCubit(preferencia);
      },
      act: (cubit) => cubit.escolher(ThemeMode.light),
      expect: () => [ThemeMode.light],
      verify: (_) => expect(preferencia.modo, ThemeMode.light),
    );
  });

  group('valor gravado do tema', () {
    test('ida e volta para os três temas', () {
      for (final modo in ThemeMode.values) {
        expect(temaDoTexto(textoDoTema(modo)), modo);
      }
    });

    test('sem valor ou valor desconhecido segue o sistema', () {
      expect(temaDoTexto(null), ThemeMode.system);
      expect(temaDoTexto('azul'), ThemeMode.system);
    });
  });
}
