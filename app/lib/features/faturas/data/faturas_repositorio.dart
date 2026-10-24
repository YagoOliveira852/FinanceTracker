import 'package:api_client/api_client.dart' as api;
import 'package:decimal/decimal.dart';

import '../../../core/api/erro_api.dart';
import 'fatura.dart';

/// Faturas dos cartões. Erros da API chegam como [ErroApi].
abstract interface class FaturasRepositorio {
  /// Em que fatura do cartão [contaId] entra uma compra feita em [data].
  Future<DatasFatura> paraCompra(String contaId, DateTime data);
}

class FaturasRepositorioApi implements FaturasRepositorio {
  FaturasRepositorioApi(this._cliente);

  final api.ApiClient _cliente;

  @override
  Future<DatasFatura> paraCompra(String contaId, DateTime data) async {
    try {
      final resposta = await _cliente.getFaturasApi().paraCompra(
        contaId: contaId,
        data: data.toDate(),
      );
      return datasFaturaDaApi(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }
}

/// Conversões dos modelos gerados (`built_value`) nos do app; também usadas
/// pelo repositório de contas, que recebe a fatura atual de cada cartão.
DatasFatura datasFaturaDaApi(api.DatasFaturaSaida d) => DatasFatura(
  competencia: d.competencia.toDateTime(),
  dataFechamento: d.dataFechamento.toDateTime(),
  dataVencimento: d.dataVencimento.toDateTime(),
);

ResumoFatura resumoFaturaDaApi(api.FaturaResumo f) => ResumoFatura(
  competencia: f.competencia.toDateTime(),
  dataFechamento: f.dataFechamento.toDateTime(),
  dataVencimento: f.dataVencimento.toDateTime(),
  status: StatusFatura.values.byName(f.status.name),
  valor: Decimal.parse(f.valor),
  valorCalculado: Decimal.parse(f.valorCalculado),
  valorInformado: f.valorInformado == null
      ? null
      : Decimal.parse(f.valorInformado!),
);
