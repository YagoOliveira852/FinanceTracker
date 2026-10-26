import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/categorias/data/categoria.dart';
import 'package:financas/features/categorias/data/categorias_repositorio.dart';
import 'package:financas/features/categorias/data/regra.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';

Map<String, Object?> _categoriaJson({
  String grupo = 'variavel',
  bool ativa = true,
}) => {
  'id': '6f1c2b3a-0000-4000-8000-000000000010',
  'nome': 'Alimentação',
  'grupo': grupo,
  'ativa': ativa,
  'qtd_regras': 3,
  'qtd_transacoes': 42,
};

void main() {
  late AdaptadorFalso adaptador;
  late CategoriasRepositorioApi repositorio;

  void responder(RespostaFalsa resposta) {
    adaptador = AdaptadorFalso((_) => resposta);
    final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
    cliente.dio.httpClientAdapter = adaptador;
    repositorio = CategoriasRepositorioApi(cliente);
  }

  test('listar converte grupo e contagens', () async {
    responder((
      status: 200,
      corpo: [
        _categoriaJson(),
        _categoriaJson(grupo: 'renda', ativa: false),
      ],
    ));

    final categorias = await repositorio.listar();

    expect(categorias.first.grupo, GrupoCategoria.variavel);
    expect(categorias.first.qtdRegras, 3);
    expect(categorias.first.qtdTransacoes, 42);
    expect(categorias.last.grupo, GrupoCategoria.renda);
    expect(categorias.last.ativa, isFalse);
  });

  test('criar manda nome e grupo', () async {
    responder((status: 201, corpo: _categoriaJson()));

    await repositorio.criar(
      const DadosCategoria(nome: 'Pets', grupo: GrupoCategoria.variavel),
    );

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.method, 'POST');
    expect(corpoDe(requisicao), {'nome': 'Pets', 'grupo': 'variavel'});
  });

  test('editar manda nome, grupo e ativa no PUT da categoria', () async {
    responder((status: 200, corpo: _categoriaJson(ativa: false)));

    final categoria = await repositorio.editar(
      'cat-1',
      const DadosCategoria(
        nome: 'Alimentação',
        grupo: GrupoCategoria.essencial,
        ativa: false,
      ),
    );

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.method, 'PUT');
    expect(requisicao.path, '/categorias/cat-1');
    expect(corpoDe(requisicao), {
      'nome': 'Alimentação',
      'grupo': 'essencial',
      'ativa': false,
    });
    expect(categoria.ativa, isFalse);
  });

  test('erro de campo da API vira ErroApi com o nome do campo', () async {
    responder((
      status: 422,
      corpo: {
        'detail': 'Dados inválidos.',
        'campos': [
          {
            'campo': 'body.nome',
            'mensagem': 'Já existe uma categoria com esse nome.',
          },
        ],
      },
    ));

    await expectLater(
      repositorio.criar(
        const DadosCategoria(nome: 'mercado', grupo: GrupoCategoria.essencial),
      ),
      throwsA(
        isA<ErroApi>().having((e) => e.campos, 'campos', {
          'nome': 'Já existe uma categoria com esse nome.',
        }),
      ),
    );
  });

  Map<String, Object?> regraJson({Map<String, Object?>? conta}) => {
    'id': '6f1c2b3a-0000-4000-8000-000000000020',
    'padrao': 'posto',
    'categoria': {
      'id': '6f1c2b3a-0000-4000-8000-000000000011',
      'nome': 'Transporte',
      'grupo': 'essencial',
    },
    'conta': conta,
    'origem': 'manual',
    'vezes_aplicada': 2,
    'criado_em': '2026-10-12T12:00:00Z',
  };

  test('listar regras converte categoria, conta e origem', () async {
    responder((
      status: 200,
      corpo: [
        regraJson(
          conta: {
            'id': '6f1c2b3a-0000-4000-8000-000000000030',
            'nome': 'Cartão Exemplo',
          },
        ),
        {...regraJson(), 'origem': 'aprendida'},
      ],
    ));

    final regras = await repositorio.listarRegras();

    expect(regras.first.categoriaNome, 'Transporte');
    expect(regras.first.contaNome, 'Cartão Exemplo');
    expect(regras.first.origem, OrigemRegra.manual);
    expect(regras.first.vezesAplicada, 2);
    expect(regras.last.contaId, isNull);
    expect(regras.last.origem, OrigemRegra.aprendida);
  });

  test('editar regra manda os campos e lê os rascunhos casados', () async {
    responder((
      status: 200,
      corpo: {
        ...regraJson(),
        'rascunhos': {
          'quantidade': 2,
          'exemplo': {'descricao': 'Posto Fictício', 'data': '2026-10-24'},
        },
      },
    ));

    final detalhe = await repositorio.editarRegra(
      'r-1',
      const DadosRegra(padrao: 'posto', categoriaId: 'cat-1'),
    );

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.method, 'PUT');
    expect(requisicao.path, '/regras/r-1');
    // Sem conta, o campo não vai; na API, ausente é nulo (todas as contas).
    expect(corpoDe(requisicao), {'padrao': 'posto', 'categoria_id': 'cat-1'});
    expect(detalhe.rascunhos, 2);
    expect(
      detalhe.exemplo,
      ExemploRascunho(
        descricao: 'Posto Fictício',
        data: DateTime(2026, 10, 24),
      ),
    );
  });

  test('excluir regra usa o DELETE', () async {
    responder((status: 204, corpo: null));

    await repositorio.excluirRegra('r-1');

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.method, 'DELETE');
    expect(requisicao.path, '/regras/r-1');
  });
}
