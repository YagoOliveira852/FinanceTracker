import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/open_finance/data/open_finance.dart';
import 'package:financas/features/open_finance/data/open_finance_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';

const _id = '6f1c2b3a-0000-4000-8000-000000000001';
const _contaId = '6f1c2b3a-0000-4000-8000-000000000002';

Map<String, Object?> _conexaoJson() => {
  'id': _id,
  'item_id': '8f3c2a91-5d4e-4b7a-9c1f-2e6d0a7b4c35',
  'instituicao': 'Banco Exemplo',
  'status': 'UPDATED',
  'ativa': true,
  'consentimento_expira_em': '2027-08-15T12:00:00Z',
  'ultimo_sync_em': '2026-11-04T10:02:00Z',
  'ultima_tentativa_em': '2026-11-04T10:02:00Z',
  'ultimo_erro': null,
  'proximo_sync': '2026-11-05T10:00:00Z',
  'buscar_a_partir_de': null,
  'problema': 'sem_dados',
  'contas': [
    {'id': _contaId, 'nome': 'Conta principal', 'tipo': 'corrente'},
  ],
};

void main() {
  late AdaptadorFalso adaptador;
  late OpenFinanceRepositorioApi repositorio;

  void responder(RespostaFalsa resposta) {
    adaptador = AdaptadorFalso((_) => resposta);
    final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
    cliente.dio.httpClientAdapter = adaptador;
    repositorio = OpenFinanceRepositorioApi(cliente);
  }

  test('listar converte conexões, datas e o problema do Início', () async {
    responder((
      status: 200,
      corpo: {
        'conexoes': [_conexaoJson()],
        'problema': {
          'problema': 'sem_dados',
          'conexao_id': _id,
          'instituicao': 'Banco Exemplo',
        },
      },
    ));

    final lista = await repositorio.listar();

    expect(adaptador.requisicoes.single.path, '/pluggy/conexoes');
    final conexao = lista.conexoes.single;
    expect(conexao.problema, ProblemaOpenFinance.semDados);
    expect(conexao.ultimoSyncEm, DateTime.utc(2026, 11, 4, 10, 2));
    expect(conexao.contas.single.tipo, TipoConta.corrente);
    expect(
      lista.problema,
      const ProblemaDoInicio(
        problema: ProblemaOpenFinance.semDados,
        conexaoId: _id,
        instituicao: 'Banco Exemplo',
      ),
    );
  });

  test('previa da renovação usa a rota da conexão', () async {
    responder((
      status: 200,
      corpo: {
        'item_id': 'item-novo',
        'instituicao': 'Banco Exemplo',
        'consentimento_expira_em': null,
        'contas': [
          {
            'pluggy_account_id': 'cartao-1',
            'tipo': 'cartao_credito',
            'nome': 'Cartão Exemplo',
            'numero_final': '5678',
            'sugestao': null,
            'pode_criar': false,
          },
        ],
      },
    ));

    final previa = await repositorio.previa('item-novo', conexaoId: _id);

    expect(
      adaptador.requisicoes.single.path,
      '/pluggy/conexoes/$_id/renovacao/previa',
    );
    expect(corpoDe(adaptador.requisicoes.single), {'item_id': 'item-novo'});
    expect(previa.contas.single.tipo, TipoConta.cartaoCredito);
    expect(previa.contas.single.podeCriar, isFalse);
  });

  test('criar manda os vínculos, com conta nula para criar nova', () async {
    responder((status: 201, corpo: _conexaoJson()));

    await repositorio.criar('item', const [
      Vinculo(pluggyAccountId: 'conta-1', contaId: _contaId),
      Vinculo(pluggyAccountId: 'cartao-1'),
    ]);

    expect(corpoDe(adaptador.requisicoes.single), {
      'item_id': 'item',
      'vinculos': [
        {'pluggy_account_id': 'conta-1', 'conta_id': _contaId},
        {'pluggy_account_id': 'cartao-1', 'conta_id': null},
      ],
    });
  });

  test('buscar agora: 429 vira ErroApi com a mensagem do horário', () async {
    responder((
      status: 429,
      corpo: {
        'detail':
            'Já buscou há pouco. Dá para buscar de novo a partir das 08:00.',
      },
    ));

    await expectLater(
      repositorio.buscarAgora(_id),
      throwsA(
        isA<ErroApi>().having(
          (e) => e.mensagem,
          'mensagem',
          endsWith('a partir das 08:00.'),
        ),
      ),
    );
  });
}
