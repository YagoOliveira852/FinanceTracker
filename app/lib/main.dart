import 'package:flutter/material.dart';

void main() {
  runApp(const FinancasApp());
}

/// Esqueleto do app: rotas, tema e telas chegam com a feature de login.
class FinancasApp extends StatelessWidget {
  const FinancasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Finanças',
      home: Scaffold(body: Center(child: Text('Finanças'))),
    );
  }
}
