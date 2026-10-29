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

  /// Lança a compra parcelada e devolve as parcelas, da 1ª à última.
  Future<List<Transacao>> lancarParcelada(NovaCompraParcelada dados);

  /// Transfere entre contas próprias e devolve o lado da saída.
  Future<Transacao> transferir(NovaTransferencia dados);
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
        ..descricao = dados.descricao
        ..categoriaId = dados.categoriaId,
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

  @override
  Future<List<Transacao>> lancarParcelada(NovaCompraParcelada dados) async {
    final entrada = api.CompraParceladaEntrada(
      (b) => b
        ..contaId = dados.contaId
        ..valorTotal = dinheiroParaApi(dados.valorTotal)
        ..qtdParcelas = dados.qtdParcelas
        ..dataCompra = dados.dataCompra.toDate()
        ..descricao = dados.descricao
        ..categoriaId = dados.categoriaId,
    );
    try {
      final resposta = await _cliente.getTransacoesApi().lancarParcelada(
        compraParceladaEntrada: entrada,
      );
      return resposta.data!.parcelas.map(transacaoDaApi).toList();
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<Transacao> transferir(NovaTransferencia dados) async {
    final descricao = dados.descricao?.trim() ?? '';
    final entrada = api.TransferenciaEntrada(
      (b) => b
        ..contaOrigemId = dados.contaOrigemId
        ..contaDestinoId = dados.contaDestinoId
        ..valor = dinheiroParaApi(dados.valor)
        ..data = dados.data.toDate()
        ..descricao = descricao.isEmpty ? null : descricao,
    );
    try {
      final resposta = await _cliente.getTransacoesApi().transferir(
        transferenciaEntrada: entrada,
      );
      return transacaoDaApi(resposta.data!.saida);
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
  categoria: switch (t.categoria) {
    final c? => CategoriaDaTransacao(id: c.id, nome: c.nome),
    null => null,
  },
  faturaId: t.faturaId,
  fatura: switch (t.fatura) {
    final f? => FaturaDaTransacao(
      cartaoId: f.cartaoId,
      competencia: f.competencia.toDateTime(),
    ),
    null => null,
  },
  parcela: switch (t.parcela) {
    final p? => Parcela(numero: p.numero, total: p.total),
    null => null,
  },
  transferencia: switch (t.transferencia) {
    final p? => ParTransferencia(
      parId: p.parId,
      contaOrigemId: p.contaOrigemId,
      contaDestinoId: p.contaDestinoId,
    ),
    null => null,
  },
);
