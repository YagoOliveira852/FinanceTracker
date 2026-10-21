import 'package:decimal/decimal.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/features/transacoes/data/transacao.dart';
import 'package:financas/features/transacoes/data/transacoes_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';

const _contaId = '6f1c2b3a-0000-4000-8000-000000000001';

Map<String, Object?> _transacaoJson() => {
  'id': '6f1c2b3a-0000-4000-8000-0000000000aa',
  'conta_id': _contaId,
  'tipo': 'transferencia_entrada',
  'valor': '1032.15',
  'data': '2026-10-19',
  'descricao': 'Transferência',
  'descricao_original': 'TRANSF RECEBIDA',
  'status': 'rascunho',
  'fonte': 'pluggy',
};

void main() {
  late AdaptadorFalso adaptador;
  late TransacoesRepositorioApi repositorio;

  void responder(RespostaFalsa resposta) {
    adaptador = AdaptadorFalso((_) => resposta);
    final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
    cliente.dio.httpClientAdapter = adaptador;
    repositorio = TransacoesRepositorioApi(cliente);
  }

  test('listar manda o período e a conta e converte o valor', () async {
    responder((status: 200, corpo: [_transacaoJson()]));

    final transacoes = await repositorio.listar(
      contaId: _contaId,
      de: DateTime(2026, 10, 1),
      ate: DateTime(2026, 10, 31),
    );

    final parametros = adaptador.requisicoes.single.uri.queryParameters;
    expect(parametros, {
      'conta_id': _contaId,
      'de': '2026-10-01',
      'ate': '2026-10-31',
    });
    final t = transacoes.single;
    expect(t.valor, Decimal.parse('1032.15'));
    expect(t.tipo, TipoTransacao.transferenciaEntrada);
    expect(t.status, StatusTransacao.rascunho);
    expect(t.data, DateTime(2026, 10, 19));
  });

  test('lançar manda valor com duas casas e o tipo da API', () async {
    responder((status: 201, corpo: _transacaoJson()));

    await repositorio.lancar(
      NovoLancamento(
        contaId: _contaId,
        tipo: TipoTransacao.receita,
        valor: Decimal.parse('850'),
        data: DateTime(2026, 10, 17),
        descricao: 'Freela de design',
      ),
    );

    expect(corpoDe(adaptador.requisicoes.single), {
      'conta_id': _contaId,
      'tipo': 'receita',
      'valor': '850.00',
      'data': '2026-10-17',
      'descricao': 'Freela de design',
    });
  });
}
