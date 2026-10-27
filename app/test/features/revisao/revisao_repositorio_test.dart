import 'package:decimal/decimal.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/categorias/data/regra.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/revisao/data/revisao.dart';
import 'package:financas/features/revisao/data/revisao_repositorio.dart';
import 'package:financas/features/transacoes/data/transacao.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';

const _id = '6f1c2b3a-0000-4000-8000-000000000001';
const _conta = '6f1c2b3a-0000-4000-8000-0000000000c1';

Map<String, Object?> _transacaoJson({
  String id = _id,
  String tipo = 'despesa',
  String status = 'rascunho',
  Map<String, Object?>? categoria,
  String? faturaCompetencia,
}) => {
  'id': id,
  'conta': {'id': _conta, 'nome': 'Cartão Exemplo', 'tipo': 'cartao_credito'},
  'tipo': tipo,
  'valor': '150.00',
  'data': '2026-10-24',
  'descricao': 'Posto Fictício',
  'descricao_original': 'POSTO FICTICIO 0193 FORTALEZA BR',
  'fonte': 'ofx',
  'status': status,
  'categoria': categoria,
  'fatura_competencia': faturaCompetencia,
  'removida_na_origem_em': null,
};

Map<String, Object?> _rascunhoJson({Map<String, Object?>? sugestao}) => {
  ..._transacaoJson(faturaCompetencia: '2026-11-01'),
  'padrao': 'posto ficticio fortaleza br',
  'sugestao': sugestao,
  'efeito_confirmando': 'reforcada',
  'efeito_corrigindo': 'manual_mantida',
};

const _categoria = {
  'id': '6f1c2b3a-0000-4000-8000-0000000000a1',
  'nome': 'Transporte',
  'grupo': 'essencial',
};

void main() {
  late AdaptadorFalso adaptador;
  late RevisaoRepositorioApi repositorio;

  void responder(RespostaFalsa resposta) {
    adaptador = AdaptadorFalso((_) => resposta);
    final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
    cliente.dio.httpClientAdapter = adaptador;
    repositorio = RevisaoRepositorioApi(cliente);
  }

  test('carregar converte rascunhos, sugestão, efeitos e decisões', () async {
    responder((
      status: 200,
      corpo: {
        'total': 3,
        'qtd_sugeridos': 1,
        'pares': [
          {
            'saida': _transacaoJson(),
            'entrada': _transacaoJson(tipo: 'receita'),
            'dias': 1,
          },
        ],
        'pagamentos': <Object>[],
        'duplicatas': [
          {
            'rascunho': _transacaoJson(),
            'outra': _transacaoJson(
              status: 'confirmada',
              categoria: _categoria,
            ),
          },
        ],
        'sumidas': <Object>[],
        'rascunhos': [
          _rascunhoJson(
            sugestao: {
              'regra_id': '6f1c2b3a-0000-4000-8000-0000000000b1',
              'padrao': 'posto',
              'origem': 'manual',
              'categoria': _categoria,
            },
          ),
        ],
      },
    ));

    final revisao = await repositorio.carregar();

    expect(revisao.total, 3);
    expect(revisao.qtdSugeridos, 1);
    expect(revisao.qtdDecisoes, 2);
    expect(revisao.pares.single.dias, 1);
    expect(revisao.pares.single.entrada.tipo, TipoTransacao.receita);
    expect(revisao.duplicatas.single.outra.categoria?.nome, 'Transporte');
    final rascunho = revisao.rascunhos.single;
    expect(rascunho.item.valor, Decimal.parse('150.00'));
    expect(rascunho.item.contaTipo, TipoConta.cartaoCredito);
    expect(rascunho.item.fonte, FonteTransacao.ofx);
    expect(rascunho.item.faturaCompetencia, DateTime(2026, 11));
    expect(rascunho.sugestao?.origem, OrigemRegra.manual);
    expect(rascunho.sugestao?.categoria.nome, 'Transporte');
    expect(rascunho.efeitoConfirmando, EfeitoRegra.reforcada);
    expect(rascunho.efeitoCorrigindo, EfeitoRegra.manualMantida);
  });

  test('rascunho sem sugestão', () async {
    responder((
      status: 200,
      corpo: {
        'total': 1,
        'qtd_sugeridos': 0,
        'pares': <Object>[],
        'pagamentos': <Object>[],
        'duplicatas': <Object>[],
        'sumidas': <Object>[],
        'rascunhos': [_rascunhoJson()],
      },
    ));

    final revisao = await repositorio.carregar();

    expect(revisao.rascunhos.single.sugestao, isNull);
    expect(revisao.sugeridos, isEmpty);
  });

  test('confirmar manda descrição, categoria e tipo', () async {
    responder((
      status: 200,
      corpo: {'efeito': 'criada', 'regra_padrao': 'posto ficticio'},
    ));

    final resultado = await repositorio.confirmar(
      _id,
      descricao: 'Posto Fictício',
      categoriaId: 'cat-transporte',
      tipo: TipoTransacao.estorno,
    );

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.path, '/revisao/transacoes/$_id/confirmar');
    expect(corpoDe(requisicao), {
      'descricao': 'Posto Fictício',
      'categoria_id': 'cat-transporte',
      'tipo': 'estorno',
    });
    expect(resultado.efeito, EfeitoRegra.criada);
    expect(resultado.regraPadrao, 'posto ficticio');
  });

  test('confirmar sem tipo não manda o campo', () async {
    responder((
      status: 200,
      corpo: {'efeito': 'nenhuma', 'regra_padrao': null},
    ));

    await repositorio.confirmar(_id, descricao: 'Pix', categoriaId: 'c');

    expect(corpoDe(adaptador.requisicoes.single).containsKey('tipo'), isFalse);
  });

  test('lote manda os ids e devolve quantos', () async {
    responder((status: 200, corpo: {'confirmados': 2}));

    final quantos = await repositorio.confirmarLote(['a', 'b']);

    expect(corpoDe(adaptador.requisicoes.single), {
      'ids': ['a', 'b'],
    });
    expect(quantos, 2);
  });

  test('transação já revisada vira ErroApi 409', () async {
    responder((
      status: 409,
      corpo: {'detail': 'Esta transação já foi revisada.'},
    ));

    expect(
      () => repositorio.ignorar(_id),
      throwsA(
        isA<ErroApi>()
            .having((e) => e.status, 'status', 409)
            .having(
              (e) => e.mensagem,
              'mensagem',
              'Esta transação já foi revisada.',
            ),
      ),
    );
  });
}
