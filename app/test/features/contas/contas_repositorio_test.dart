import 'package:decimal/decimal.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/contas/data/contas_repositorio.dart';
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
