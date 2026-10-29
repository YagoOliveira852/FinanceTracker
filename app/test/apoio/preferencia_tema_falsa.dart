import 'package:financas/features/configuracoes/data/preferencia_tema.dart';
import 'package:flutter/material.dart';

/// Tema guardado só em memória, para os testes.
class PreferenciaTemaFalsa implements PreferenciaTema {
  PreferenciaTemaFalsa([this.modo = ThemeMode.system]);

  ThemeMode modo;

  @override
  Future<ThemeMode> ler() async => modo;

  @override
  Future<void> salvar(ThemeMode modo) async => this.modo = modo;
}
