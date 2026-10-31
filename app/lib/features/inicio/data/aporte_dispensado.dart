import 'package:shared_preferences/shared_preferences.dart';

import '../../planejamento/data/resumo.dart';

/// O último salário cuja sugestão de aporte foi dispensada ("Agora não").
///
/// Fica no aparelho: o app tem um usuário só, num aparelho só, e a dispensa
/// vale até o salário seguinte (spec do cálculo, decisões da tela inicial).
abstract interface class AporteDispensado {
  /// A chave do salário dispensado ([chaveDoAporte]); nula se nenhum.
  Future<String?> ler();
  Future<void> salvar(String chave);
}

/// No shared_preferences, como o tema.
class AporteDispensadoLocal implements AporteDispensado {
  AporteDispensadoLocal([SharedPreferencesAsync? preferencias])
    : _preferencias = preferencias ?? SharedPreferencesAsync();

  static const _chave = 'aporte_dispensado';

  final SharedPreferencesAsync _preferencias;

  @override
  Future<String?> ler() => _preferencias.getString(_chave);

  @override
  Future<void> salvar(String chave) => _preferencias.setString(_chave, chave);
}

/// `renda:2026-11-10`: a renda e a data esperada identificam o salário, e o
/// do mês seguinte tem outra chave. Nula sem salário recebido.
String? chaveDoAporte(Resumo resumo) =>
    switch (resumo.previsao?.salarioRecebido) {
      final salario? => '${salario.rendaId}:${_iso(salario.dataEsperada)}',
      null => null,
    };

String _iso(DateTime data) =>
    '${data.year}-${_dois(data.month)}-${_dois(data.day)}';

String _dois(int n) => n.toString().padLeft(2, '0');
