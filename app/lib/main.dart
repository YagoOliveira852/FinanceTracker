import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/injecao.dart';
import 'core/api/cliente_api.dart';

Future<void> main() async {
  if (urlApi.isEmpty) {
    throw StateError(
      'API_URL não definida. Rode com '
      '--dart-define=API_URL=http://10.0.2.2:8000 (emulador).',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();

  final dependencias = Dependencias.api();
  // Lê os tokens e o tema guardados antes da primeira tela: assim o app abre
  // direto no Início ou no login, já no tema escolhido, sem piscar.
  await Future.wait([
    dependencias.sessao.iniciar(),
    dependencias.tema.iniciar(),
  ]);

  runApp(FinancasApp(dependencias));
}
