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
}
