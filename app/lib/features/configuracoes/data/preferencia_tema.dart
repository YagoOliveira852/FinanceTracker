import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onde fica a escolha de tema (do sistema, claro ou escuro) entre aberturas
/// do app.
abstract interface class PreferenciaTema {
  Future<ThemeMode> ler();
  Future<void> salvar(ThemeMode modo);
}

/// Preferência no shared_preferences: o `localStorage` do app, para valores
/// simples que não são segredo (os tokens ficam no flutter_secure_storage).
class PreferenciaTemaLocal implements PreferenciaTema {
  PreferenciaTemaLocal([SharedPreferencesAsync? preferencias])
    : _preferencias = preferencias ?? SharedPreferencesAsync();

  static const _chave = 'tema';

  final SharedPreferencesAsync _preferencias;

  @override
  Future<ThemeMode> ler() async =>
      temaDoTexto(await _preferencias.getString(_chave));

  @override
  Future<void> salvar(ThemeMode modo) =>
      _preferencias.setString(_chave, textoDoTema(modo));
}

/// Valor gravado → tema. Sem valor (primeira abertura) ou desconhecido, segue
/// o sistema.
ThemeMode temaDoTexto(String? texto) => switch (texto) {
  'claro' => ThemeMode.light,
  'escuro' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// Tema → valor gravado. Texto em português em vez do `name` do enum, para o
/// valor guardado não depender do nome de um tipo do Flutter.
String textoDoTema(ThemeMode modo) => switch (modo) {
  ThemeMode.light => 'claro',
  ThemeMode.dark => 'escuro',
  ThemeMode.system => 'sistema',
};
