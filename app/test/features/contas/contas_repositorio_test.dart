import 'package:decimal/decimal.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/contas/data/contas_repositorio.dart';
import 'package:financas/features/faturas/data/fatura.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';

Map<String, Object?> _contaJson({
  String tipo = 'corrente',
  String saldo = '-120.40',
}) => {
  'id': '6f1c2b3a-0000-4000-8000-000000000001',
  'nome': 'Conta do dia a dia',
  'tipo': tipo,
  'instituicao': tipo == 'carteira'
      ? null
      : {
          'id': '6f1c2b3a-0000-4000-8000-000000000002',
          'nome': 'Banco Fictício',
        },
  'saldo_inicial': '100.00',
  'data_saldo_inicial': '2026-10-01',
  'saldo_atual': saldo,
  'ativa': true,
  'cartao': null,
};

Map<String, Object?> _faturaJson() => {
  'competencia': '2026-11-01',
  'data_fechamento': '2026-11-03',
  'data_vencimento': '2026-11-10',
  'status': 'aberta',
  'valor': '544.80',
  'valor_calculado': '544.80',
  'valor_informado': null,
};

Map<String, Object?> _cartaoJson() => {
  ..._contaJson(tipo: 'cartao_credito', saldo: '0.00'),
  'nome': 'Cartão Exemplo',
  'cartao': {
    'conta_pagamento_id': '6f1c2b3a-0000-4000-8000-000000000003',
    'dia_fechamento': 3,
    'dia_vencimento': 10,
    'limite': '3000.00',
    'fatura_atual': _faturaJson(),
  },
};

void main() {
  late AdaptadorFalso adaptador;
  late ContasRepositorioApi repositorio;

  void responder(RespostaFalsa resposta) {
    adaptador = AdaptadorFalso((_) => resposta);
    final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
    cliente.dio.httpClientAdapter = adaptador;
    repositorio = ContasRepositorioApi(cliente);
  }

  test(
    'listar converte dinheiro String em Decimal e Date em DateTime',
    () async {
      responder((
        status: 200,
        corpo: {
          'total_disponivel': '1234.56',
          'contas': [_contaJson()],
        },
      ));

      final resumo = await repositorio.listar();

      expect(resumo.totalDisponivel, Decimal.parse('1234.56'));
      final conta = resumo.contas.single;
      expect(conta.saldoAtual, Decimal.parse('-120.40'));
      expect(conta.tipo, TipoConta.corrente);
      expect(conta.instituicao, 'Banco Fictício');
      expect(conta.dataSaldoInicial, DateTime(2026, 10, 1));
    },
  );

  test('criar carteira manda saldo com duas casas e sem instituição', () async {
    responder((
      status: 201,
      corpo: _contaJson(tipo: 'carteira', saldo: '50.00'),
    ));

    final conta = await repositorio.criar(
      NovaConta(
        nome: 'Carteira',
        tipo: TipoConta.carteira,
        saldoInicial: Decimal.parse('-120.4'),
        dataSaldoInicial: DateTime(2026, 10, 20),
      ),
    );

    final corpo = corpoDe(adaptador.requisicoes.single);
    expect(corpo['tipo'], 'carteira');
    expect(corpo['saldo_inicial'], '-120.40');
    expect(corpo['data_saldo_inicial'], '2026-10-20');
    expect(corpo.containsKey('instituicao'), isFalse);
    expect(conta.tipo, TipoConta.carteira);
    expect(conta.instituicao, isNull);
  });

  test('listar preenche o cartão só na conta de cartão', () async {
    responder((
      status: 200,
      corpo: {
        'total_disponivel': '0.00',
        'contas': [_contaJson(), _cartaoJson()],
      },
    ));

    final contas = (await repositorio.listar()).contas;

    expect(contas.first.cartao, isNull);
    final cartao = contas.last.cartao!;
    expect(contas.last.tipo, TipoConta.cartaoCredito);
    expect(cartao.diaFechamento, 3);
    expect(cartao.limite, Decimal.parse('3000.00'));
    expect(cartao.faturaAtual.competencia, DateTime(2026, 11));
    expect(cartao.faturaAtual.dataVencimento, DateTime(2026, 11, 10));
    expect(cartao.faturaAtual.status, StatusFatura.aberta);
    expect(cartao.faturaAtual.valor, Decimal.parse('544.80'));
    expect(cartao.faturaAtual.valorInformado, isNull);
  });

  test('criarCartao manda os dias e o limite com duas casas', () async {
    responder((status: 201, corpo: _cartaoJson()));

    final conta = await repositorio.criarCartao(
      NovoCartao(
        nome: 'Cartão Exemplo',
        instituicao: 'Banco Exemplo',
        contaPagamentoId: 'c1',
        diaFechamento: 3,
        diaVencimento: 10,
        limite: Decimal.parse('3000'),
      ),
    );

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.path, '/cartoes');
    expect(corpoDe(requisicao), {
      'nome': 'Cartão Exemplo',
      'instituicao': 'Banco Exemplo',
      'conta_pagamento_id': 'c1',
      'dia_fechamento': 3,
      'dia_vencimento': 10,
      'limite': '3000.00',
    });
    expect(conta.cartao, isNotNull);
  });

  test('previaFatura pede a prévia com os dois dias', () async {
    responder((
      status: 200,
      corpo: {
        'competencia': '2026-11-01',
        'data_fechamento': '2026-11-03',
        'data_vencimento': '2026-11-10',
      },
    ));

    final previa = await repositorio.previaFatura(
      diaFechamento: 3,
      diaVencimento: 10,
    );

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.path, '/cartoes/previa');
    expect(requisicao.queryParameters, {
      'dia_fechamento': 3,
      'dia_vencimento': 10,
    });
    expect(previa.competencia, DateTime(2026, 11));
    expect(previa.dataFechamento, DateTime(2026, 11, 3));
  });

  test('erro da API vira ErroApi com os campos', () async {
    responder((
      status: 422,
      corpo: {
        'detail': 'Dados inválidos.',
        'campos': [
          {
            'campo': 'body.data_saldo_inicial',
            'mensagem': 'A data do saldo não pode ser depois de hoje.',
          },
        ],
      },
    ));

    await expectLater(
      repositorio.criar(
        NovaConta(
          nome: 'Conta principal',
          tipo: TipoConta.corrente,
          instituicao: 'Banco Exemplo',
          saldoInicial: Decimal.zero,
          dataSaldoInicial: DateTime(2026, 10, 20),
        ),
      ),
      throwsA(
        isA<ErroApi>().having(
          (e) => e.campos['data_saldo_inicial'],
          'campo',
          'A data do saldo não pode ser depois de hoje.',
        ),
      ),
    );
  });
}
