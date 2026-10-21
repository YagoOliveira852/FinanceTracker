import 'package:dio/dio.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _resposta(int status, Object? corpo) {
  final requisicao = RequestOptions(path: '/contas');
  return DioException(
    requestOptions: requisicao,
    response: Response(
      requestOptions: requisicao,
      statusCode: status,
      data: corpo,
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  test('422 traz a mensagem de cada campo, sem o prefixo body.', () {
    final erro = ErroApi.de(
      _resposta(422, {
        'detail': 'Dados inválidos.',
        'campos': [
          {
            'campo': 'body.data_saldo_inicial',
            'mensagem': 'A data do saldo não pode ser depois de hoje.',
          },
          {'campo': 'body.nome', 'mensagem': 'Não pode ficar em branco.'},
        ],
      }),
    );

    expect(erro.status, 422);
    expect(erro.mensagem, 'Dados inválidos.');
    expect(erro.campos, {
      'data_saldo_inicial': 'A data do saldo não pode ser depois de hoje.',
      'nome': 'Não pode ficar em branco.',
    });
  });

  test('401 do login usa o detail da API', () {
    final erro = ErroApi.de(
      _resposta(401, {'detail': 'E-mail ou senha incorretos.'}),
    );

    expect(erro.status, 401);
    expect(erro.mensagem, 'E-mail ou senha incorretos.');
    expect(erro.campos, isEmpty);
  });

  test('sem resposta (sem rede, API fora do ar)', () {
    final erro = ErroApi.de(
      DioException(
        requestOptions: RequestOptions(path: '/contas'),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(erro.mensagem, 'Não foi possível falar com o servidor.');
    expect(erro.status, isNull);
  });

  test('500 não mostra o corpo da resposta', () {
    final erro = ErroApi.de(_resposta(500, 'Internal Server Error'));

    expect(erro.mensagem, 'Erro no servidor. Tente de novo.');
  });

  test('erro que não é da API vira mensagem genérica', () {
    expect(
      ErroApi.de(StateError('x')).mensagem,
      'Algo deu errado. Tente de novo.',
    );
  });
}
