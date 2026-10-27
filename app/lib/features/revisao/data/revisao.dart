import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../categorias/data/regra.dart';
import '../../contas/data/conta.dart';
import '../../faturas/data/fatura.dart';
import '../../transacoes/data/transacao.dart';

part 'revisao.freezed.dart';

/// De onde a transação veio.
enum FonteTransacao {
  manual('Lançamento'),
  ofx('Extrato OFX'),
  csvMercadopago('Extrato CSV'),
  pluggy('Open Finance');

  const FonteTransacao(this.rotulo);

  final String rotulo;
}

/// O que confirmar a categoria faz com as regras (o mesmo enum da API).
enum EfeitoRegra {
  /// Nenhuma regra sugeria: nasce uma aprendida.
  criada,

  /// A sugestão foi confirmada como veio.
  reforcada,

  /// Aprendida com o mesmo padrão: troca a categoria e zera a contagem.
  corrigida,

  /// Aprendida mais curta: nasce uma mais longa, que passa a vencer.
  especializada,

  /// A regra manual não muda na revisão.
  manualMantida,

  /// A descrição só tinha termos genéricos: nada a aprender.
  nenhuma,
}

/// Uma transação como a revisão mostra: com a conta e de onde veio.
@freezed
abstract class ItemRevisao with _$ItemRevisao {
  const factory ItemRevisao({
    required String id,
    required String contaId,
    required String contaNome,
    required TipoConta contaTipo,
    required TipoTransacao tipo,
    required Decimal valor,
    required DateTime data,
    required String descricao,

    /// Como veio do banco, nunca editada.
    required String descricaoOriginal,
    required FonteTransacao fonte,
    required StatusTransacao status,

    /// Só a confirmada tem (na duplicata e no "sumiu da origem").
    CategoriaDaTransacao? categoria,

    /// Fatura em que a compra entra (cartão), primeiro dia do mês.
    DateTime? faturaCompetencia,

    /// A confirmada que sumiu do Open Finance.
    DateTime? removidaNaOrigemEm,
  }) = _ItemRevisao;
}

/// A regra que sugere a categoria de um rascunho, calculada agora.
@freezed
abstract class Sugestao with _$Sugestao {
  const factory Sugestao({
    required String regraId,
    required String padrao,
    required OrigemRegra origem,
    required CategoriaDaTransacao categoria,
  }) = _Sugestao;
}

/// Rascunho comum: a transação, o padrão normalizado da descrição e o que
/// acontece com as regras ao confirmar.
@freezed
abstract class Rascunho with _$Rascunho {
  const factory Rascunho({
    required ItemRevisao item,

    /// A descrição original normalizada; vazia se só tinha termos genéricos.
    required String padrao,
    Sugestao? sugestao,

    /// Efeito se confirmar a sugestão (ou, sem sugestão, qualquer categoria).
    required EfeitoRegra efeitoConfirmando,

    /// Efeito se escolher outra categoria.
    required EfeitoRegra efeitoCorrigindo,
  }) = _Rascunho;

  const Rascunho._();

  /// O efeito de confirmar com a categoria [categoriaId].
  EfeitoRegra efeitoPara(String categoriaId) =>
      sugestao == null || sugestao!.categoria.id == categoriaId
      ? efeitoConfirmando
      : efeitoCorrigindo;
}

/// Saída e entrada que parecem uma transferência entre contas próprias.
@freezed
abstract class ParSugerido with _$ParSugerido {
  const factory ParSugerido({
    required ItemRevisao saida,
    required ItemRevisao entrada,

    /// Diferença de dias entre as duas (até 2).
    required int dias,
  }) = _ParSugerido;
}

/// O rascunho que chegou por último e a transação igual que já estava.
@freezed
abstract class Duplicata with _$Duplicata {
  const factory Duplicata({
    required ItemRevisao rascunho,
    required ItemRevisao outra,
  }) = _Duplicata;
}

/// Tudo o que espera o usuário na aba Revisão.
@freezed
abstract class Revisao with _$Revisao {
  const factory Revisao({
    /// Linhas para revisar (um par conta 1): o contador da aba.
    required int total,

    /// Rascunhos comuns com categoria sugerida: o "Confirmar N".
    required int qtdSugeridos,
    @Default([]) List<ParSugerido> pares,

    /// Pagamentos de fatura vindos das fontes, à espera da fatura.
    @Default([]) List<ItemRevisao> pagamentos,
    @Default([]) List<Duplicata> duplicatas,

    /// Confirmadas que sumiram do Open Finance.
    @Default([]) List<ItemRevisao> sumidas,

    /// Os comuns, da data mais recente para a mais antiga.
    @Default([]) List<Rascunho> rascunhos,
  }) = _Revisao;

  const Revisao._();

  /// Quantas decisões ("Precisam de você").
  int get qtdDecisoes =>
      pares.length + pagamentos.length + duplicatas.length + sumidas.length;

  /// Os rascunhos comuns que o lote confirma.
  List<Rascunho> get sugeridos => [
    for (final r in rascunhos)
      if (r.sugestao != null) r,
  ];
}

/// Resposta de "Confirmar": o que aconteceu com as regras.
@freezed
abstract class ResultadoConfirmacao with _$ResultadoConfirmacao {
  const factory ResultadoConfirmacao({
    required EfeitoRegra efeito,
    String? regraPadrao,
  }) = _ResultadoConfirmacao;
}

/// Qual fica numa possível duplicata.
enum ManterDuplicata {
  /// O que chegou por último; a outra fica ignorada.
  rascunho,

  /// A que já estava; o rascunho fica ignorado.
  outra,

  /// Não é duplicata.
  asDuas,
}

/// Uma fatura que o pagamento vindo das fontes pode ter pago.
@freezed
abstract class FaturaCandidata with _$FaturaCandidata {
  const factory FaturaCandidata({
    required String cartaoId,
    required String cartaoNome,

    /// Primeiro dia do mês do vencimento.
    required DateTime competencia,

    /// Como está hoje, sem este pagamento.
    required StatusFatura status,
    required DateTime dataVencimento,
    required Decimal valor,

    /// Já pago, sem este pagamento.
    required Decimal valorPago,

    /// Com este pagamento, a fatura fica paga.
    required bool ficaPaga,

    /// A pré-selecionada (no máximo uma).
    required bool sugerida,
  }) = _FaturaCandidata;
}
