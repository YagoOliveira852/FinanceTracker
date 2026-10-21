import 'package:financas/app/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tema claro usa os tokens do design system', () {
    final tema = temaClaro();
    expect(tema.colorScheme.brightness, Brightness.light);
    expect(tema.colorScheme.primary, const Color(0xFF1F5F66));
    expect(tema.colorScheme.surface, const Color(0xFFF6F5F1));
    expect(tema.extension<CoresFinancas>(), CoresFinancas.claro);
    expect(tema.textTheme.bodyLarge!.fontFamily, 'Manrope');
  });

  test('tema escuro usa os tokens do design system', () {
    final tema = temaEscuro();
    expect(tema.colorScheme.brightness, Brightness.dark);
    expect(tema.colorScheme.primary, const Color(0xFF86D0D6));
    expect(tema.colorScheme.surface, const Color(0xFF111514));
    expect(tema.extension<CoresFinancas>(), CoresFinancas.escuro);
  });
}
