import 'package:api_client/api_client.dart' as api;

import '../../../core/api/erro_api.dart';
import '../../contas/data/conta.dart';
import 'open_finance.dart';

/// Conexões da Pluggy. Erros da API chegam como [ErroApi].
abstract interface class OpenFinanceRepositorio {
  Future<ListaConexoes> listar();

  /// Valida o item e lista as contas, sem gravar. Com [conexaoId], é a
  /// prévia da renovação daquela conexão.
  Future<PreviaConexao> previa(String itemId, {String? conexaoId});
  Future<Conexao> criar(String itemId, List<Vinculo> vinculos);
  Future<Conexao> renovar(
    String conexaoId,
    String itemId,
    List<Vinculo> vinculos,
  );

  /// Desativa (o sync para) ou reativa (confere o item).
  Future<Conexao> alterarAtiva(String conexaoId, {required bool ativa});

  /// "Buscar agora": o nosso sync, no máximo 1×/hora.
  Future<ResultadoBusca> buscarAgora(String conexaoId);
}

class OpenFinanceRepositorioApi implements OpenFinanceRepositorio {
  OpenFinanceRepositorioApi(this._cliente);

  final api.ApiClient _cliente;

  api.PluggyApi get _api => _cliente.getPluggyApi();

  @override
  Future<ListaConexoes> listar() => _chamar(() async {
    final lista = (await _api.listar()).data!;
    final problema = lista.problema;
    return ListaConexoes(
      conexoes: lista.conexoes.map(_conexao).toList(),
      problema: problema == null
          ? null
          : ProblemaDoInicio(
              problema: _problema(problema.problema),
              conexaoId: problema.conexaoId,
              instituicao: problema.instituicao,
            ),
    );
  });

  @override
  Future<PreviaConexao> previa(String itemId, {String? conexaoId}) =>
      _chamar(() async {
        final entrada = api.ItemEntrada((b) => b..itemId = itemId);
        final resposta = conexaoId == null
            ? await _api.previa(itemEntrada: entrada)
            : await _api.previaRenovacao(
                conexaoId: conexaoId,
                itemEntrada: entrada,
              );
        final previa = resposta.data!;
        return PreviaConexao(
          itemId: previa.itemId,
          instituicao: previa.instituicao,
          consentimentoExpiraEm: previa.consentimentoExpiraEm,
          contas: [
            for (final c in previa.contas)
              ContaDaPrevia(
                pluggyAccountId: c.pluggyAccountId,
                tipo: TipoConta.values.byName(c.tipo.name),
                nome: c.nome,
                numeroFinal: c.numeroFinal,
                sugestao: c.sugestao == null ? null : _contaDoApp(c.sugestao!),
                podeCriar: c.podeCriar,
              ),
          ],
        );
      });

  @override
  Future<Conexao> criar(String itemId, List<Vinculo> vinculos) =>
      _chamar(() async {
        final resposta = await _api.criar(
          conexaoEntrada: _entrada(itemId, vinculos),
        );
        return _conexao(resposta.data!);
      });

  @override
  Future<Conexao> renovar(
    String conexaoId,
    String itemId,
    List<Vinculo> vinculos,
  ) => _chamar(() async {
    final resposta = await _api.renovar(
      conexaoId: conexaoId,
      conexaoEntrada: _entrada(itemId, vinculos),
    );
    return _conexao(resposta.data!);
  });

  @override
  Future<Conexao> alterarAtiva(String conexaoId, {required bool ativa}) =>
      _chamar(() async {
        final resposta = await _api.editar(
          conexaoId: conexaoId,
          conexaoEdicao: api.ConexaoEdicao((b) => b..ativa = ativa),
        );
        return _conexao(resposta.data!);
      });

  @override
  Future<ResultadoBusca> buscarAgora(String conexaoId) => _chamar(() async {
    final resultado = (await _api.buscarAgora(conexaoId: conexaoId)).data!;
    return ResultadoBusca(
      ok: resultado.ok,
      erro: resultado.erro,
      novas: resultado.novas,
      atualizadas: resultado.atualizadas,
    );
  });

  static Future<T> _chamar<T>(Future<T> Function() chamada) async {
    try {
      return await chamada();
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  static api.ConexaoEntrada _entrada(String itemId, List<Vinculo> vinculos) =>
      api.ConexaoEntrada(
        (b) => b
          ..itemId = itemId
          ..vinculos.replace([
            for (final v in vinculos)
              api.VinculoEntrada(
                (vb) => vb
                  ..pluggyAccountId = v.pluggyAccountId
                  ..contaId = v.contaId,
              ),
          ]),
      );

  static Conexao _conexao(api.ConexaoSaida c) => Conexao(
    id: c.id,
    itemId: c.itemId,
    instituicao: c.instituicao,
    ativa: c.ativa,
    consentimentoExpiraEm: c.consentimentoExpiraEm,
    ultimoSyncEm: c.ultimoSyncEm,
    ultimaTentativaEm: c.ultimaTentativaEm,
    ultimoErro: c.ultimoErro,
    proximoSync: c.proximoSync,
    buscarAPartirDe: c.buscarAPartirDe,
    problema: c.problema == null ? null : _problema(c.problema!),
    contas: c.contas.map(_contaDoApp).toList(),
  );

  static ContaDoApp _contaDoApp(api.ContaDoAppSaida c) => ContaDoApp(
    id: c.id,
    nome: c.nome,
    tipo: TipoConta.values.byName(c.tipo.name),
  );

  static ProblemaOpenFinance _problema(api.Problema p) =>
      ProblemaOpenFinance.values.byName(p.name);
}
