import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/categorias/cubit/categorias_cubit.dart';
import 'package:financas/features/categorias/data/categoria.dart';
import 'package:financas/features/categorias/data/categorias_repositorio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Categoria categoriaExemplo({
  String id = 'cat-mercado',
  String nome = 'Mercado',
  GrupoCategoria grupo = GrupoCategoria.essencial,
  bool ativa = true,
  int qtdRegras = 0,
  int qtdTransacoes = 0,
}) => Categoria(
  id: id,
  nome: nome,
  grupo: grupo,
  ativa: ativa,
  qtdRegras: qtdRegras,
  qtdTransacoes: qtdTransacoes,
);

/// Uma de cada grupo, mais uma variável desativada.
List<Categoria> categoriasExemplo() => [
  categoriaExemplo(qtdRegras: 4, qtdTransacoes: 12),
  categoriaExemplo(
    id: 'cat-alimentacao',
    nome: 'Alimentação',
    grupo: GrupoCategoria.variavel,
    qtdRegras: 1,
  ),
  categoriaExemplo(
    id: 'cat-educacao',
    nome: 'Educação',
    grupo: GrupoCategoria.variavel,
    ativa: false,
  ),
  categoriaExemplo(
    id: 'cat-salario',
    nome: 'Salário',
    grupo: GrupoCategoria.renda,
  ),
  categoriaExemplo(
    id: 'cat-investimento',
    nome: 'Investimento',
    grupo: GrupoCategoria.investimento,
  ),
];

/// Repositório de categorias em memória. [erro] faz a próxima chamada falhar.
class CategoriasRepositorioFalso implements CategoriasRepositorio {
  CategoriasRepositorioFalso({List<Categoria>? categorias})
    : categorias = categorias ?? categoriasExemplo();

  final List<Categoria> categorias;
  final criadas = <DadosCategoria>[];
  final editadas = <({String id, DadosCategoria dados})>[];
  ErroApi? erro;

  @override
  Future<List<Categoria>> listar() async {
    if (erro case final e?) throw e;
    return List.of(categorias);
  }

  @override
  Future<Categoria> criar(DadosCategoria dados) async {
    if (erro case final e?) throw e;
    criadas.add(dados);
    final categoria = categoriaExemplo(
      id: 'nova-${criadas.length}',
      nome: dados.nome,
      grupo: dados.grupo,
    );
    categorias.add(categoria);
    return categoria;
  }

  @override
  Future<Categoria> editar(String id, DadosCategoria dados) async {
    if (erro case final e?) throw e;
    editadas.add((id: id, dados: dados));
    final indice = categorias.indexWhere((c) => c.id == id);
    final categoria = categorias[indice].copyWith(
      nome: dados.nome,
      grupo: dados.grupo,
      ativa: dados.ativa,
    );
    categorias[indice] = categoria;
    return categoria;
  }
}

/// Envolve [filho] com o [CategoriasCubit] que o app põe no topo, já
/// carregando (o Lançamento lê as opções dele).
Widget comCategorias(Widget filho, {CategoriasRepositorio? repositorio}) =>
    BlocProvider(
      create: (_) =>
          CategoriasCubit(repositorio ?? CategoriasRepositorioFalso())
            ..carregar(),
      child: filho,
    );
