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
}
