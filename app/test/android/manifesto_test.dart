import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Os manifestos de debug e profile já pedem INTERNET (o Flutter precisa
  // dela para o hot reload), então o app funciona no `flutter run` e só
  // quebra no APK de release, que usa apenas o manifesto `main`.
  test('manifesto main pede a permissão INTERNET', () {
    final manifesto = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(
      manifesto,
      matches(
        RegExp(
          r'<uses-permission\s+android:name="android\.permission\.INTERNET"',
        ),
      ),
    );
  });

  // O Compartilhar de um OFX só abre o app se o filtro aceitar SEND com os
  // tipos que os apps usam para o arquivo.
  test('manifesto recebe OFX pelo Compartilhar', () {
    final manifesto = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final filtro = RegExp(
      r'<intent-filter>(?:(?!</intent-filter>).)*'
      r'android\.intent\.action\.SEND"(?:(?!</intent-filter>).)*</intent-filter>',
      dotAll: true,
    ).firstMatch(manifesto)?.group(0);

    expect(filtro, isNotNull);
    for (final tipo in [
      'application/x-ofx',
      'application/octet-stream',
      'text/plain',
    ]) {
      expect(filtro, contains('android:mimeType="$tipo"'));
    }
  });
}
