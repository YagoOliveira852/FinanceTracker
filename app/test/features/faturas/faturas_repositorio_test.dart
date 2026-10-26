import 'package:decimal/decimal.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/features/faturas/data/faturas_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';

void main() {
  late AdaptadorFalso adaptador;
  late FaturasRepositorioApi repositorio;

  void responder(RespostaFalsa resposta) {
    adaptador = AdaptadorFalso((_) => resposta);
    final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
    cliente.dio.httpClientAdapter = adaptador;
    repositorio = FaturasRepositorioApi(cliente);
  }

  test('paraCompra pede a fatura da data e converte as datas', () async {
    responder((
      status: 200,
      corpo: {
        'competencia': '2026-11-01',
        'data_fechamento': '2026-11-03',
        'data_vencimento': '2026-11-10',
      },
    ));

    final datas = await repositorio.paraCompra('c1', DateTime(2026, 10, 5));

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.path, '/cartoes/c1/faturas/para-compra');
    expect(requisicao.queryParameters['data'], '2026-10-05');
    expect(datas.competencia, DateTime(2026, 11));
    expect(datas.dataVencimento, DateTime(2026, 11, 10));
  });

  Map<String, Object?> resumoJson(String competencia, {String? informado}) => {
    'competencia': competencia,
    'data_fechamento': '2026-11-03',
    'data_vencimento': '2026-11-10',
    'status': 'aberta',
    'valor': '544.80',
    'valor_calculado': '544.80',
    'valor_pago': '0.00',
    'valor_informado': informado,
  };

  test('listar converte atual, próximas e anteriores', () async {
    responder((
      status: 200,
      corpo: {
        'atual': resumoJson('2026-11-01'),
        'proximas': [resumoJson('2026-12-01')],
        'anteriores': [resumoJson('2026-10-01', informado: '1032.15')],
      },
    ));

    final lista = await repositorio.listar('k1');

    expect(adaptador.requisicoes.single.path, '/cartoes/k1/faturas');
    expect(lista.atual.valor, Decimal.parse('544.80'));
    expect(lista.anteriores.single.valorInformado, Decimal.parse('1032.15'));
    expect(lista.emOrdem.map((f) => f.competencia), [
      DateTime(2026, 12),
      DateTime(2026, 11),
      DateTime(2026, 10),
    ]);
  });

  test('obter pede a competência AAAA-MM e converte o ajuste', () async {
    responder((
      status: 200,
      corpo: {
        ...resumoJson('2026-10-01', informado: '1032.15'),
        'fechamento_calculado': '2026-10-05',
        'vencimento_calculado': '2026-10-13',
        'ajuste_fechamento': {'data_prevista': '2026-10-03', 'feriados': []},
        'ajuste_vencimento': {
          'data_prevista': '2026-10-10',
          'feriados': [
            {'data': '2026-10-12', 'descricao': 'Nossa Senhora Aparecida'},
          ],
        },
        'transacoes': [
          {
            'id': 't1',
            'conta_id': 'k1',
            'tipo': 'despesa',
            'valor': '150.00',
            'data': '2026-10-02',
            'descricao': 'Posto Fictício',
            'descricao_original': 'Posto Fictício',
            'status': 'confirmada',
            'fonte': 'manual',
            'fatura_id': 'f1',
          },
        ],
        'pagamentos': [],
      },
    ));

    final detalhe = await repositorio.obter('k1', DateTime(2026, 10));

    expect(adaptador.requisicoes.single.path, '/cartoes/k1/faturas/2026-10');
    expect(detalhe.fechamentoCalculado, DateTime(2026, 10, 5));
    expect(detalhe.ajusteFechamento!.feriados, isEmpty);
    expect(detalhe.ajusteVencimento!.feriados, {
      DateTime(2026, 10, 12): 'Nossa Senhora Aparecida',
    });
    expect(detalhe.transacoes.single.valor, Decimal.parse('150.00'));
    expect(detalhe.transacoes.single.faturaId, 'f1');
  });
}
