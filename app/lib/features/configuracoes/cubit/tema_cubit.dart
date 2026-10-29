import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/preferencia_tema.dart';

/// Tema escolhido em Mais → Aparência. Fica no topo do app porque o
/// `MaterialApp` lê dele o `themeMode`.
class TemaCubit extends Cubit<ThemeMode> {
  TemaCubit(this._preferencia) : super(ThemeMode.system);

  final PreferenciaTema _preferencia;

  /// Lê a escolha guardada antes da primeira tela, para o app não abrir num
  /// tema e piscar para o outro.
  Future<void> iniciar() async => emit(await _preferencia.ler());

  /// Aplica na hora e guarda para as próximas aberturas.
  Future<void> escolher(ThemeMode modo) async {
    emit(modo);
    await _preferencia.salvar(modo);
  }
}

/// Nome do tema como aparece em Mais.
String nomeDoTema(ThemeMode modo) => switch (modo) {
  ThemeMode.system => 'Do sistema',
  ThemeMode.light => 'Claro',
  ThemeMode.dark => 'Escuro',
};
