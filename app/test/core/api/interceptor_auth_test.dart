import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:financas/core/api/cliente_api.dart';
import 'package:financas/core/api/interceptor_auth.dart';
import 'package:financas/core/auth/armazenamento_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/adaptador_falso.dart';
import '../../apoio/armazenamento_memoria.dart';

const _url = 'http://api.exemplo.test';
const _resumoVazio = {'total_disponivel': '0.00', 'contas': <Object>[]};
const _naoAutenticado = (status: 401, corpo: {'detail': 'Não autenticado.'});

/// Cliente com o interceptor, como em produção, sobre um adaptador falso.
class _Cenario {
  _Cenario({
    TokensSessao? tokens = const TokensSessao(
      access: 'access-1',
      refresh: 'refresh-1',
    ),
    bool refreshAceito = true,
    void Function(ArmazenamentoTokensMemoria)? duranteRefresh,
  }) : armazenamento = ArmazenamentoTokensMemoria(tokens) {
    adaptador = AdaptadorFalso((options) async {
      // Atraso para requisições paralelas estarem todas em voo juntas.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (options.path == '/auth/refresh') {
        duranteRefresh?.call(armazenamento);
        if (!refreshAceito) return _naoAutenticado;
        return (
          status: 200,
          corpo: {
            'access_token': 'access-2',
            'refresh_token': 'refresh-2',
            'token_type': 'bearer',
            'expires_in': 900,
          },
        );
      }
      if (options.path == '/auth/login') return _naoAutenticado;
      // O servidor só aceita o access renovado.
      if (options.headers['Authorization'] == 'Bearer access-2') {
        return (status: 200, corpo: _resumoVazio);
      }
      return _naoAutenticado;
    });

    final dio = criarDio(baseUrl: _url)..httpClientAdapter = adaptador;
    final dioSemAuth = criarDio(baseUrl: _url)..httpClientAdapter = adaptador;
    cliente = criarClienteApi(
      dio: dio,
      interceptors: [
        InterceptorAuth(
          armazenamento: armazenamento,
          dioSemAuth: dioSemAuth,
          aoExpirarSessao: () => expiracoes++,
        ),
      ],
    );
  }

  final ArmazenamentoTokensMemoria armazenamento;
  late final AdaptadorFalso adaptador;
  late final ApiClient cliente;
  var expiracoes = 0;

  Future<Response<ContasResumo>> listarContas() =>
      cliente.getContasApi().listar();
}

void main() {
  test('requisição leva o access token no Authorization', () async {
    final cenario = _Cenario(
      tokens: const TokensSessao(access: 'access-2', refresh: 'refresh-1'),
    );

    await cenario.listarContas();

    expect(
      cenario.adaptador.requisicoes.single.headers['Authorization'],
      'Bearer access-2',
    );
  });

  test('sem sessão, a requisição vai sem Authorization', () async {
    final cenario = _Cenario(tokens: null);

    await expectLater(cenario.listarContas(), throwsA(isA<DioException>()));

    expect(
      cenario.adaptador.requisicoes.single.headers.containsKey('Authorization'),
      isFalse,
    );
    expect(cenario.adaptador.chamadasA('/auth/refresh'), 0);
  });

  test('401 renova a sessão, salva o par novo e repete a requisição', () async {
    final cenario = _Cenario();

    final resposta = await cenario.listarContas();

    expect(resposta.data!.totalDisponivel, '0.00');
    expect(cenario.adaptador.chamadasA('/auth/refresh'), 1);
    expect(corpoDe(cenario.adaptador.requisicoes[1]), {
      'refresh_token': 'refresh-1',
    });
    expect(cenario.adaptador.chamadasA('/contas'), 2);
    expect(cenario.armazenamento.tokens!.access, 'access-2');
    expect(cenario.armazenamento.tokens!.refresh, 'refresh-2');
  });

  test('vários 401 ao mesmo tempo fazem um refresh só', () async {
    final cenario = _Cenario();

    final respostas = await Future.wait([
      cenario.listarContas(),
      cenario.listarContas(),
      cenario.listarContas(),
    ]);

    expect(respostas, hasLength(3));
    expect(cenario.adaptador.chamadasA('/auth/refresh'), 1);
    expect(cenario.expiracoes, 0);
  });

  test('refresh recusado apaga a sessão e avisa uma vez', () async {
    final cenario = _Cenario(refreshAceito: false);

    Future<Object?> erroDe(Future<Object?> chamada) async {
      try {
        await chamada;
        return null;
      } catch (erro) {
        return erro;
      }
    }

    final resultados = await Future.wait([
      erroDe(cenario.listarContas()),
      erroDe(cenario.listarContas()),
    ]);

    for (final erro in resultados) {
      expect(erro, isA<DioException>());
      expect((erro! as DioException).response!.statusCode, 401);
    }
    expect(cenario.adaptador.chamadasA('/auth/refresh'), 1);
    expect(cenario.armazenamento.tokens, isNull);
    expect(cenario.expiracoes, 1);
  });

  test('sair durante o refresh não traz a sessão de volta', () async {
    final cenario = _Cenario(duranteRefresh: (a) => a.tokens = null);

    await expectLater(cenario.listarContas(), throwsA(isA<DioException>()));

    expect(cenario.adaptador.chamadasA('/auth/refresh'), 1);
    expect(cenario.armazenamento.tokens, isNull);
  });

  test('401 do login não tenta refresh', () async {
    final cenario = _Cenario();

    await expectLater(
      cenario.cliente.getAuthApi().login(
        loginEntrada: LoginEntrada(
          (b) => b
            ..email = 'ana@exemplo.com'
            ..senha = 'senha-errada',
        ),
      ),
      throwsA(isA<DioException>()),
    );

    expect(cenario.adaptador.chamadasA('/auth/refresh'), 0);
    expect(
      cenario.adaptador.requisicoes.single.headers.containsKey('Authorization'),
      isFalse,
    );
    expect(cenario.expiracoes, 0);
  });
}
