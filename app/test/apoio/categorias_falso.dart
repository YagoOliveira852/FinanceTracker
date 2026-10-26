import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/categorias/cubit/categorias_cubit.dart';
import 'package:financas/features/categorias/data/categoria.dart';
import 'package:financas/features/categorias/data/categorias_repositorio.dart';
import 'package:financas/features/categorias/data/regra.dart';
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

Regra regraExemplo({
  String id = 'r1',
  String padrao = 'padaria pao quente',
  String categoriaId = 'cat-alimentacao',
  String categoriaNome = 'Alimentação',
  String? contaId,
  String? contaNome,
  OrigemRegra origem = OrigemRegra.aprendida,
  int vezesAplicada = 3,
}) => Regra(
  id: id,
  padrao: padrao,
  categoriaId: categoriaId,
  categoriaNome: categoriaNome,
  contaId: contaId,
  contaNome: contaNome,
  origem: origem,
  vezesAplicada: vezesAplicada,
  criadoEm: DateTime(2026, 10, 12, 9),
);

/// Uma manual restrita a uma conta, uma manual geral e uma aprendida.
List<Regra> regrasExemplo() => [
  regraExemplo(
    id: 'r-posto',
    padrao: 'posto',
    categoriaId: 'cat-mercado',
    categoriaNome: 'Mercado',
    contaId: 'k1',
    contaNome: 'Cartão Exemplo',
    origem: OrigemRegra.manual,
    vezesAplicada: 0,
  ),
  regraExemplo(
    id: 'r-freela',
    padrao: 'freela',
    categoriaId: 'cat-salario',
    categoriaNome: 'Salário',
    origem: OrigemRegra.manual,
    vezesAplicada: 2,
  ),
  regraExemplo(),
];

/// Repositório de categorias em memória. [erro] faz a próxima chamada falhar.
class CategoriasRepositorioFalso implements CategoriasRepositorio {
  CategoriasRepositorioFalso({List<Categoria>? categorias, List<Regra>? regras})
    : categorias = categorias ?? categoriasExemplo(),
      regras = regras ?? regrasExemplo();

  final List<Categoria> categorias;
  final List<Regra> regras;
  final criadas = <DadosCategoria>[];
  final editadas = <({String id, DadosCategoria dados})>[];
  final regrasCriadas = <DadosRegra>[];
  final regrasEditadas = <({String id, DadosRegra dados})>[];
  final regrasExcluidas = <String>[];

  /// O que o detalhe de qualquer regra diz sobre os rascunhos.
  var rascunhos = 1;
  ExemploRascunho? exemplo = ExemploRascunho(
    descricao: 'Padaria Pão Quente',
    data: DateTime(2026, 10, 25),
  );
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

  @override
  Future<List<Regra>> listarRegras() async {
    if (erro case final e?) throw e;
    return List.of(regras);
  }

  @override
  Future<RegraDetalhe> obterRegra(String id) async {
    if (erro case final e?) throw e;
    return _detalhe(regras.firstWhere((r) => r.id == id));
  }

  @override
  Future<RegraDetalhe> criarRegra(DadosRegra dados) async {
    if (erro case final e?) throw e;
    regrasCriadas.add(dados);
    final regra = _comDados(
      regraExemplo(id: 'nova-${regrasCriadas.length}', vezesAplicada: 0),
      dados,
    ).copyWith(origem: OrigemRegra.manual);
    regras.add(regra);
    return _detalhe(regra);
  }

  @override
  Future<RegraDetalhe> editarRegra(String id, DadosRegra dados) async {
    if (erro case final e?) throw e;
    regrasEditadas.add((id: id, dados: dados));
    final indice = regras.indexWhere((r) => r.id == id);
    final regra = _comDados(
      regras[indice],
      dados,
    ).copyWith(origem: OrigemRegra.manual);
    regras[indice] = regra;
    return _detalhe(regra);
  }

  @override
  Future<void> excluirRegra(String id) async {
    if (erro case final e?) throw e;
    regrasExcluidas.add(id);
    regras.removeWhere((r) => r.id == id);
  }

  Regra _comDados(Regra regra, DadosRegra dados) => regra.copyWith(
    padrao: dados.padrao.trim().toLowerCase(),
    categoriaId: dados.categoriaId,
    categoriaNome: categorias.firstWhere((c) => c.id == dados.categoriaId).nome,
    contaId: dados.contaId,
    contaNome: dados.contaId == null ? null : 'Conta ${dados.contaId}',
  );

  RegraDetalhe _detalhe(Regra regra) =>
      RegraDetalhe(regra: regra, rascunhos: rascunhos, exemplo: exemplo);
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
