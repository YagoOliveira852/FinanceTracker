import 'package:api_client/api_client.dart' as api;

import '../../../core/api/erro_api.dart';
import 'categoria.dart';
import 'regra.dart';

/// Categorias e regras de classificação. Erros da API chegam como [ErroApi].
abstract interface class CategoriasRepositorio {
  /// Todas, ativas ou não, por grupo e nome.
  Future<List<Categoria>> listar();
  Future<Categoria> criar(DadosCategoria dados);

  /// Renomeia, troca o grupo ou desativa/reativa ([DadosCategoria.ativa]).
  Future<Categoria> editar(String id, DadosCategoria dados);

  /// Manuais primeiro, depois as aprendidas mais usadas.
  Future<List<Regra>> listarRegras();

  /// A regra e quantos rascunhos ela sugere agora.
  Future<RegraDetalhe> obterRegra(String id);
  Future<RegraDetalhe> criarRegra(DadosRegra dados);

  /// Salvar torna a regra manual.
  Future<RegraDetalhe> editarRegra(String id, DadosRegra dados);
  Future<void> excluirRegra(String id);
}

/// Usa o cliente gerado e converte os modelos `built_value` nos do app.
class CategoriasRepositorioApi implements CategoriasRepositorio {
  CategoriasRepositorioApi(this._cliente);

  final api.ApiClient _cliente;

  @override
  Future<List<Categoria>> listar() async {
    try {
      final resposta = await _cliente.getCategoriasApi().listar();
      return resposta.data!.map(_categoria).toList();
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<Categoria> criar(DadosCategoria dados) async {
    final entrada = api.CategoriaEntrada(
      (b) => b
        ..nome = dados.nome
        ..grupo = _grupoParaApi(dados.grupo),
    );
    try {
      final resposta = await _cliente.getCategoriasApi().criar(
        categoriaEntrada: entrada,
      );
      return _categoria(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<Categoria> editar(String id, DadosCategoria dados) async {
    final edicao = api.CategoriaEdicao(
      (b) => b
        ..nome = dados.nome
        ..grupo = _grupoParaApi(dados.grupo)
        ..ativa = dados.ativa,
    );
    try {
      final resposta = await _cliente.getCategoriasApi().editar(
        categoriaId: id,
        categoriaEdicao: edicao,
      );
      return _categoria(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<List<Regra>> listarRegras() async {
    try {
      final resposta = await _cliente.getRegrasApi().listar();
      return resposta.data!.map(_regra).toList();
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<RegraDetalhe> obterRegra(String id) async {
    try {
      final resposta = await _cliente.getRegrasApi().obter(regraId: id);
      return _detalhe(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<RegraDetalhe> criarRegra(DadosRegra dados) async {
    try {
      final resposta = await _cliente.getRegrasApi().criar(
        regraEntrada: _entrada(dados),
      );
      return _detalhe(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<RegraDetalhe> editarRegra(String id, DadosRegra dados) async {
    try {
      final resposta = await _cliente.getRegrasApi().editar(
        regraId: id,
        regraEntrada: _entrada(dados),
      );
      return _detalhe(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<void> excluirRegra(String id) async {
    try {
      await _cliente.getRegrasApi().excluir(regraId: id);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  static api.RegraEntrada _entrada(DadosRegra dados) => api.RegraEntrada(
    (b) => b
      ..padrao = dados.padrao
      ..categoriaId = dados.categoriaId
      ..contaId = dados.contaId,
  );

  static Regra _regra(api.RegraSaida r) => Regra(
    id: r.id,
    padrao: r.padrao,
    categoriaId: r.categoria.id,
    categoriaNome: r.categoria.nome,
    contaId: r.conta?.id,
    contaNome: r.conta?.nome,
    origem: OrigemRegra.values.byName(r.origem.name),
    vezesAplicada: r.vezesAplicada,
    criadoEm: r.criadoEm.toLocal(),
  );

  static RegraDetalhe _detalhe(api.RegraDetalheSaida r) => RegraDetalhe(
    regra: Regra(
      id: r.id,
      padrao: r.padrao,
      categoriaId: r.categoria.id,
      categoriaNome: r.categoria.nome,
      contaId: r.conta?.id,
      contaNome: r.conta?.nome,
      origem: OrigemRegra.values.byName(r.origem.name),
      vezesAplicada: r.vezesAplicada,
      criadoEm: r.criadoEm.toLocal(),
    ),
    rascunhos: r.rascunhos.quantidade,
    exemplo: switch (r.rascunhos.exemplo) {
      final e? => ExemploRascunho(
        descricao: e.descricao,
        data: e.data.toDateTime(),
      ),
      null => null,
    },
  );

  static Categoria _categoria(api.CategoriaSaida c) => Categoria(
    id: c.id,
    nome: c.nome,
    grupo: grupoDaApi(c.grupo),
    ativa: c.ativa,
    qtdRegras: c.qtdRegras,
    qtdTransacoes: c.qtdTransacoes,
  );

  static api.GrupoCategoria _grupoParaApi(GrupoCategoria grupo) =>
      api.GrupoCategoria.valueOf(grupo.name);
}

/// Grupo do cliente gerado no enum do app; também usado pelas transações.
GrupoCategoria grupoDaApi(api.GrupoCategoria grupo) =>
    GrupoCategoria.values.byName(grupo.name);
