import 'package:financas/features/inicio/data/aporte_dispensado.dart';

/// Dispensa do aporte guardada só em memória, para os testes.
class AporteDispensadoFalso implements AporteDispensado {
  AporteDispensadoFalso([this.chave]);

  String? chave;

  @override
  Future<String?> ler() async => chave;

  @override
  Future<void> salvar(String chave) async => this.chave = chave;
}
