/// Frases da revisão.
library;

import '../../transacoes/data/transacao.dart';
import '../data/revisao.dart';

/// "12 para revisar".
String textoDoTotal(int total) => '$total para revisar';

/// "7 rascunhos com categoria sugerida".
String textoDoLote(int quantidade) => quantidade == 1
    ? '1 rascunho com categoria sugerida'
    : '$quantidade rascunhos com categoria sugerida';

/// O que confirmar com [categoria] faz com as regras, na folha do rascunho.
/// Nulo quando nada muda nem há regra para citar.
String? textoDoEfeito(
  Rascunho rascunho,
  PrevisaoDoTipo? previsao,
  EfeitoRegra? efeito,
  String categoria,
) {
  final sugestao = previsao?.sugestao;
  final padrao = rascunho.padrao;
  return switch (efeito) {
    null || EfeitoRegra.nenhuma => null,
    EfeitoRegra.criada => 'Próximas de “$padrao” vão sugerir $categoria.',
    EfeitoRegra.reforcada => 'Sugerida pela regra de “${sugestao!.padrao}”.',
    EfeitoRegra.corrigida =>
      'A regra de “${sugestao!.padrao}” muda de ${sugestao.categoria.nome} '
          'para $categoria e volta a contar do zero.',
    EfeitoRegra.especializada =>
      'Próximas de “$padrao” vão sugerir $categoria; a regra de '
          '“${sugestao!.padrao}” continua para as outras.',
    EfeitoRegra.manualMantida =>
      'A regra manual de “${sugestao!.padrao}” continua sugerindo '
          '${sugestao.categoria.nome}. Para mudá-la, use Categorias e regras.',
  };
}

/// Rótulo do tipo na folha do rascunho.
String rotuloDoTipo(TipoTransacao tipo) => switch (tipo) {
  TipoTransacao.despesa => 'Despesa',
  TipoTransacao.receita => 'Receita',
  TipoTransacao.estorno => 'Estorno',
  TipoTransacao.transferenciaSaida ||
  TipoTransacao.transferenciaEntrada => 'Transferência entre contas próprias',
  TipoTransacao.pagamentoFatura => 'Pagamento de fatura',
  TipoTransacao.aporte => 'Aporte',
  TipoTransacao.resgate => 'Resgate',
  TipoTransacao.ajusteEntrada || TipoTransacao.ajusteSaida => 'Ajuste',
};
