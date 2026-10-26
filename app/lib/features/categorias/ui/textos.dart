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

/// "Usada 3 vezes", "Usada 1 vez" ou "Ainda não usada", na linha da regra
/// aprendida.
String textoDoUsoDaRegra(int vezes) => switch (vezes) {
  0 => 'Ainda não usada',
  1 => 'Usada 1 vez',
  _ => 'Usada $vezes vezes',
};

/// "Casa com 1 rascunho agora: Padaria Pão Quente, 25 out." no Editar regra.
String textoDosRascunhos(int quantidade, {String? exemplo}) =>
    switch (quantidade) {
      0 => 'Não casa com nenhum rascunho agora.',
      1 => 'Casa com 1 rascunho agora: $exemplo.',
      _ => 'Casa com $quantidade rascunhos agora; o mais recente: $exemplo.',
    };

/// Aviso depois de salvar: "Regra salva; sugere 2 rascunhos agora."
String textoRegraSalva(int rascunhos) => switch (rascunhos) {
  0 => 'Regra salva; não casa com nenhum rascunho agora.',
  1 => 'Regra salva; sugere 1 rascunho agora.',
  _ => 'Regra salva; sugere $rascunhos rascunhos agora.',
};
