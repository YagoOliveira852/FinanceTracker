import 'package:freezed_annotation/freezed_annotation.dart';

import '../../contas/data/conta.dart';

part 'open_finance.freezed.dart';

/// Problema de uma conexão, do mais para o menos grave. O card do Início só
/// aparece quando há um.
enum ProblemaOpenFinance { vencido, erro, semDados, vencendo }

/// Conta do app que uma conexão alimenta (ou a sugerida na prévia).
@freezed
abstract class ContaDoApp with _$ContaDoApp {
  const factory ContaDoApp({
    required String id,
    required String nome,
    required TipoConta tipo,
  }) = _ContaDoApp;
}

/// Item MeuPluggy de um banco e o estado do sync.
@freezed
abstract class Conexao with _$Conexao {
  const factory Conexao({
    required String id,
    required String itemId,
    required String instituicao,
    required bool ativa,
    DateTime? consentimentoExpiraEm,

    /// Último sync bem-sucedido.
    DateTime? ultimoSyncEm,
    DateTime? ultimaTentativaEm,

    /// Em português, pronto para a tela.
    String? ultimoErro,

    /// Nulo se desativada.
    DateTime? proximoSync,

    /// Quando o "Buscar agora" volta a valer; nulo se já vale.
    DateTime? buscarAPartirDe,
    ProblemaOpenFinance? problema,
    @Default([]) List<ContaDoApp> contas,
  }) = _Conexao;
}

/// O problema mais grave entre as conexões ativas: o card do Início.
@freezed
abstract class ProblemaDoInicio with _$ProblemaDoInicio {
  const factory ProblemaDoInicio({
    required ProblemaOpenFinance problema,
    required String conexaoId,
    required String instituicao,
  }) = _ProblemaDoInicio;
}

@freezed
abstract class ListaConexoes with _$ListaConexoes {
  const factory ListaConexoes({
    @Default([]) List<Conexao> conexoes,
    ProblemaDoInicio? problema,
  }) = _ListaConexoes;
}

/// Conta da Pluggy na prévia, com a sugestão de vínculo.
@freezed
abstract class ContaDaPrevia with _$ContaDaPrevia {
  const factory ContaDaPrevia({
    required String pluggyAccountId,
    required TipoConta tipo,
    required String nome,
    String? numeroFinal,
    ContaDoApp? sugestao,

    /// Falso no cartão sem fechamento na Pluggy: só vincular.
    required bool podeCriar,
  }) = _ContaDaPrevia;
}

/// O item validado na Pluggy e as contas dele.
@freezed
abstract class PreviaConexao with _$PreviaConexao {
  const factory PreviaConexao({
    required String itemId,
    required String instituicao,
    DateTime? consentimentoExpiraEm,
    @Default([]) List<ContaDaPrevia> contas,
  }) = _PreviaConexao;
}

/// O que fazer com uma conta da Pluggy: criar nova ([contaId] nulo) ou
/// alimentar uma conta do app.
@freezed
abstract class Vinculo with _$Vinculo {
  const factory Vinculo({required String pluggyAccountId, String? contaId}) =
      _Vinculo;
}

@freezed
abstract class ResultadoBusca with _$ResultadoBusca {
  const factory ResultadoBusca({
    required bool ok,
    String? erro,
    required int novas,
    required int atualizadas,
  }) = _ResultadoBusca;
}
