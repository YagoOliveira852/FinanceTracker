import 'package:api_client/api_client.dart' as api;

import '../../../core/api/erro_api.dart';
import 'categoria.dart';

/// Categorias. Erros da API chegam como [ErroApi].
abstract interface class CategoriasRepositorio {
  /// Todas, ativas ou não, por grupo e nome.
  Future<List<Categoria>> listar();
  Future<Categoria> criar(DadosCategoria dados);

  /// Renomeia, troca o grupo ou desativa/reativa ([DadosCategoria.ativa]).
  Future<Categoria> editar(String id, DadosCategoria dados);
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
