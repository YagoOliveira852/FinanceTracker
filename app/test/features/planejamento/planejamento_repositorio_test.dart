import 'package:decimal/decimal.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/planejamento/data/planejamento.dart';
import 'package:financas/features/planejamento/data/planejamento_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';

const _id = '6f1c2b3a-0000-4000-8000-000000000001';
const _contaId = '6f1c2b3a-0000-4000-8000-000000000002';

Map<String, Object?> _rendaJson({bool ativa = true}) => {
  'id': _id,
  'descricao': 'Freela mensal',
  'valor': '600.00',
  'dia_previsto': 15,
  'conta_id': _contaId,
  'ativa': ativa,
  'proxima': {
    'data': '2026-11-16',
    'data_prevista': '2026-11-15',
    'feriados': [
      {'data': '2026-11-15', 'descricao': 'Proclamação da República'},
    ],
  },
};

Map<String, Object?> _configuracaoJson({String? mensal}) => {
  'configuracao': {
    'colchao': '500.00',
    'meta_reserva_meses': '6.0',
    'gasto_semanal_estimado': '280.00',
    'gasto_mensal_referencia': mensal,
  },
  'gasto_mensal_automatico': {
    'valor': '3000.00',
    'meses': ['2026-07-01', '2026-08-01', '2026-09-01'],
  },
  'media_semanal_real': '252.00',
  'meses_de_reserva': '4.2',
};

void main() {
  late AdaptadorFalso adaptador;
  late PlanejamentoRepositorioApi repositorio;

  void responder(RespostaFalsa resposta) {
    adaptador = AdaptadorFalso((_) => resposta);
    final cliente = criarClienteApi(baseUrl: 'http://api.exemplo.test');
    cliente.dio.httpClientAdapter = adaptador;
    repositorio = PlanejamentoRepositorioApi(cliente);
  }

  test('listarRendas converte valor em Decimal e as datas', () async {
    responder((status: 200, corpo: [_rendaJson()]));

    final [renda] = await repositorio.listarRendas();

    expect(adaptador.requisicoes.single.path, '/planejamento/rendas');
    expect(
      renda,
      Renda(
        id: _id,
        descricao: 'Freela mensal',
        valor: Decimal.parse('600.00'),
        diaPrevisto: 15,
        contaId: _contaId,
        ativa: true,
        proxima: ProximaData(
          data: DateTime(2026, 11, 16),
          dataPrevista: DateTime(2026, 11, 15),
          feriados: {DateTime(2026, 11, 15): 'Proclamação da República'},
        ),
      ),
    );
  });

  test('criarRenda manda POST com o valor em string', () async {
    responder((status: 201, corpo: _rendaJson()));

    await repositorio.criarRenda(
      DadosRenda(
        descricao: 'Freela mensal',
        valor: Decimal.parse('600'),
        diaPrevisto: 15,
        contaId: _contaId,
      ),
    );

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.method, 'POST');
    expect(requisicao.path, '/planejamento/rendas');
    expect(corpoDe(requisicao), {
      'descricao': 'Freela mensal',
      'valor': '600.00',
      'dia_previsto': 15,
      'conta_id': _contaId,
    });
  });

  test('editarRenda manda PUT com ativa', () async {
    responder((status: 200, corpo: _rendaJson(ativa: false)));

    final renda = await repositorio.editarRenda(
      _id,
      DadosRenda(
        descricao: 'Freela mensal',
        valor: Decimal.parse('600'),
        diaPrevisto: 15,
        contaId: _contaId,
        ativa: false,
      ),
    );

    final requisicao = adaptador.requisicoes.single;
    expect(requisicao.method, 'PUT');
    expect(requisicao.path, '/planejamento/rendas/$_id');
    expect(corpoDe(requisicao)['ativa'], false);
    expect(renda.ativa, isFalse);
  });

  test('previaRenda pede a próxima data do dia', () async {
    responder((status: 200, corpo: _rendaJson()['proxima']));

    final proxima = await repositorio.previaRenda(15);

    expect(adaptador.requisicoes.single.path, '/planejamento/rendas/previa');
    expect(adaptador.requisicoes.single.queryParameters, {'dia_previsto': 15});
    expect(proxima.data, DateTime(2026, 11, 16));
  });

  test('lerConfiguracao converte valores e meses', () async {
    responder((status: 200, corpo: _configuracaoJson()));

    final leitura = await repositorio.lerConfiguracao();

    expect(
      leitura,
      LeituraConfiguracao(
        configuracao: Configuracao(
          colchao: Decimal.parse('500'),
          metaReservaMeses: Decimal.parse('6'),
          gastoSemanalEstimado: Decimal.parse('280'),
        ),
        gastoMensalAutomatico: GastoMensal(
          valor: Decimal.parse('3000'),
          meses: [DateTime(2026, 7), DateTime(2026, 8), DateTime(2026, 9)],
        ),
        mediaSemanalReal: Decimal.parse('252'),
        mesesDeReserva: Decimal.parse('4.2'),
      ),
    );
  });

  test('lerConfiguracao sem configuração salva', () async {
    responder((
      status: 200,
      corpo: {
        'configuracao': null,
        'gasto_mensal_automatico': null,
        'media_semanal_real': null,
        'meses_de_reserva': null,
      },
    ));

    expect(await repositorio.lerConfiguracao(), const LeituraConfiguracao());
  });

  test(
    'salvarConfiguracao manda os quatro campos, nulo no automático',
    () async {
      responder((status: 200, corpo: _configuracaoJson()));

      await repositorio.salvarConfiguracao(
        Configuracao(
          colchao: Decimal.parse('500'),
          metaReservaMeses: Decimal.parse('4.5'),
          gastoSemanalEstimado: Decimal.parse('280'),
        ),
      );

      final requisicao = adaptador.requisicoes.single;
      expect(requisicao.method, 'PUT');
      expect(requisicao.path, '/planejamento/configuracao');
      expect(corpoDe(requisicao), {
        'colchao': '500.00',
        'meta_reserva_meses': '4.5',
        'gasto_semanal_estimado': '280.00',
        'gasto_mensal_referencia': null,
      });
    },
  );

  test('erro da API vira ErroApi com os campos', () async {
    responder((
      status: 422,
      corpo: {
        'detail': 'Dados inválidos.',
        'campos': [
          {
            'campo': 'body.valor',
            'mensagem': 'O valor precisa ser maior que zero.',
          },
        ],
      },
    ));

    await expectLater(
      repositorio.criarRenda(
        DadosRenda(
          descricao: 'Salário',
          valor: Decimal.one,
          diaPrevisto: 10,
          contaId: _contaId,
        ),
      ),
      throwsA(
        isA<ErroApi>().having((e) => e.campos, 'campos', {
          'valor': 'O valor precisa ser maior que zero.',
        }),
      ),
    );
  });
}
