import 'package:api_client/api_client.dart' as api;
import 'package:decimal/decimal.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/dinheiro.dart';
import 'transacao.dart';

/// Transações. Erros da API chegam como [ErroApi].
abstract interface class TransacoesRepositorio {
  /// Transações de [de] a [ate] (inclusive), da mais recente para a mais
  /// antiga, de todas as contas ou só de [contaId].
  Future<List<Transacao>> listar({
    String? contaId,
    required DateTime de,
    required DateTime ate,
  });

  Future<Transacao> lancar(NovoLancamento dados);
}

class TransacoesRepositorioApi implements TransacoesRepositorio {
  TransacoesRepositorioApi(this._cliente);

  final api.ApiClient _cliente;

  @override
  Future<List<Transacao>> listar({
    String? contaId,
    required DateTime de,
    required DateTime ate,
  }) async {
    try {
      final resposta = await _cliente.getTransacoesApi().listar(
        contaId: contaId,
        de: de.toDate(),
        ate: ate.toDate(),
      );
      return resposta.data!.map(transacaoDaApi).toList();
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<Transacao> lancar(NovoLancamento dados) async {
    final entrada = api.TransacaoEntrada(
      (b) => b
        ..contaId = dados.contaId
        ..tipo = switch (dados.tipo) {
          TipoTransacao.despesa => api.TransacaoEntradaTipoEnum.despesa,
          TipoTransacao.receita => api.TransacaoEntradaTipoEnum.receita,
          _ => throw ArgumentError('Só despesa e receita são lançadas aqui.'),
        }
        ..valor = dinheiroParaApi(dados.valor)
        ..data = dados.data.toDate()
        ..descricao = dados.descricao,
    );
    try {
      final resposta = await _cliente.getTransacoesApi().lancar(
        transacaoEntrada: entrada,
      );
      return transacaoDaApi(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }
}

/// Transação do cliente gerado no modelo do app; também usada pelo
/// repositório de faturas (transações do detalhe).
Transacao transacaoDaApi(api.TransacaoSaida t) => Transacao(
  id: t.id,
  contaId: t.contaId,
  tipo: TipoTransacao.values.byName(t.tipo.name),
  valor: Decimal.parse(t.valor),
  data: t.data.toDateTime(),
  descricao: t.descricao,
  status: StatusTransacao.values.byName(t.status.name),
  faturaId: t.faturaId,
);
