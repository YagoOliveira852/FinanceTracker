import 'package:freezed_annotation/freezed_annotation.dart';

part 'regra.freezed.dart';

/// Manual (criada ou editada em Categorias e regras) ou aprendida na revisão.
enum OrigemRegra { manual, aprendida }

/// Regra de classificação: sugere a categoria dos rascunhos cuja descrição
/// contém o [padrao].
@freezed
abstract class Regra with _$Regra {
  const factory Regra({
    required String id,

    /// Já normalizado pela API (minúsculas, sem acentos nem números).
    required String padrao,
    required String categoriaId,
    required String categoriaNome,

    /// A conta a que a regra se restringe; nula = todas.
    String? contaId,
    String? contaNome,
    required OrigemRegra origem,

    /// Sugestões confirmadas como vieram.
    required int vezesAplicada,
    required DateTime criadoEm,
  }) = _Regra;
}

/// A regra e os rascunhos sem categoria que ela sugere agora.
@freezed
abstract class RegraDetalhe with _$RegraDetalhe {
  const factory RegraDetalhe({
    required Regra regra,
    required int rascunhos,

    /// O rascunho mais recente que ela sugere ("Padaria Pão Quente, 25 out").
    ExemploRascunho? exemplo,
  }) = _RegraDetalhe;
}

@freezed
abstract class ExemploRascunho with _$ExemploRascunho {
  const factory ExemploRascunho({
    required String descricao,
    required DateTime data,
  }) = _ExemploRascunho;
}

/// Dados do formulário de regra (nova ou editada; salvar torna manual).
@freezed
abstract class DadosRegra with _$DadosRegra {
  const factory DadosRegra({
    required String padrao,
    required String categoriaId,
    String? contaId,
  }) = _DadosRegra;
}
