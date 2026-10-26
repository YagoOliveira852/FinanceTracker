import 'package:freezed_annotation/freezed_annotation.dart';

import '../../transacoes/data/transacao.dart';

part 'categoria.freezed.dart';

/// Essencial e variável são gasto; renda e investimento não entram no gasto
/// do mês.
enum GrupoCategoria {
  essencial('Essencial'),
  variavel('Variável'),
  renda('Renda'),
  investimento('Investimento');

  const GrupoCategoria(this.rotulo);

  final String rotulo;

  /// Grupos que combinam com o tipo da transação (o mesmo critério da API):
  /// despesa e estorno ↔ essencial e variável; receita ↔ renda; aporte e
  /// resgate ↔ investimento. Transferência, pagamento e ajuste: nenhum.
  static Set<GrupoCategoria> doTipo(TipoTransacao tipo) => switch (tipo) {
    TipoTransacao.despesa ||
    TipoTransacao.estorno => const {essencial, variavel},
    TipoTransacao.receita => const {renda},
    TipoTransacao.aporte || TipoTransacao.resgate => const {investimento},
    _ => const {},
  };
}

@freezed
abstract class Categoria with _$Categoria {
  const factory Categoria({
    required String id,
    required String nome,
    required GrupoCategoria grupo,

    /// Desativada sai das opções e as regras dela não sugerem; as
    /// transações antigas continuam com ela.
    required bool ativa,
    required int qtdRegras,
    required int qtdTransacoes,
  }) = _Categoria;

  const Categoria._();

  /// Pode ser escolhida para uma transação do [tipo]: ativa e do grupo certo.
  bool opcaoPara(TipoTransacao tipo) =>
      ativa && GrupoCategoria.doTipo(tipo).contains(grupo);
}

/// Dados do formulário de categoria (nova ou editada).
@freezed
abstract class DadosCategoria with _$DadosCategoria {
  const factory DadosCategoria({
    required String nome,
    required GrupoCategoria grupo,
    @Default(true) bool ativa,
  }) = _DadosCategoria;
}
