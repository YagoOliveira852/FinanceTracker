/// Frases de Categorias e regras.
library;

/// "1 regra", "4 regras" ou "—" (nenhuma), na linha da categoria.
String textoDasRegras(int quantidade) => switch (quantidade) {
  0 => '—',
  1 => '1 regra',
  _ => '$quantidade regras',
};

/// "3 regras e 42 transações usam esta categoria." no Editar categoria.
String textoDoUso({required int regras, required int transacoes}) {
  String contagem(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';
  final partes = [
    if (regras > 0) contagem(regras, 'regra', 'regras'),
    if (transacoes > 0) contagem(transacoes, 'transação', 'transações'),
  ];
  return switch (partes) {
    [] => 'Nenhuma regra nem transação usa esta categoria.',
    [final unica] =>
      '$unica ${regras + transacoes == 1 ? 'usa' : 'usam'} esta categoria.',
    [final a, final b] => '$a e $b usam esta categoria.',
    _ => throw StateError('Mais de duas partes.'),
  };
}
