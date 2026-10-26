import 'package:api_client/api_client.dart' as api;
import 'package:decimal/decimal.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../transacoes/data/transacoes_repositorio.dart';
import 'fatura.dart';

/// Faturas dos cartões, endereçadas pela competência. Erros da API chegam
/// como [ErroApi].
abstract interface class FaturasRepositorio {
  Future<ListaFaturas> listar(String contaId);
  Future<DetalheFatura> obter(String contaId, DateTime competencia);

  /// Edita datas e valor informado; mudar o fechamento realoca compras.
  Future<DetalheFatura> editar(
    String contaId,
    DateTime competencia, {
    required DateTime dataFechamento,
    required DateTime dataVencimento,
    Decimal? valorInformado,
  });

  /// Ajusta a fatura para o valor real (cria, troca ou remove o ajuste).
  Future<DetalheFatura> ajustar(
    String contaId,
    DateTime competencia, {
    required Decimal valorReal,
    String? descricao,
  });

  /// Em que fatura do cartão [contaId] entra uma compra feita em [data].
  Future<DatasFatura> paraCompra(String contaId, DateTime data);

  /// Registra um pagamento da fatura e devolve o detalhe atualizado.
  Future<DetalheFatura> pagar(
    String contaId,
    DateTime competencia,
    NovoPagamento dados,
  );
}

class FaturasRepositorioApi implements FaturasRepositorio {
  FaturasRepositorioApi(this._cliente);

  final api.ApiClient _cliente;

  Future<T> _chamar<T>(
    Future<T> Function(api.FaturasApi faturas) chamada,
  ) async {
    try {
      return await chamada(_cliente.getFaturasApi());
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<ListaFaturas> listar(String contaId) => _chamar((faturas) async {
    final lista = (await faturas.listar(contaId: contaId)).data!;
    return ListaFaturas(
      atual: resumoFaturaDaApi(lista.atual),
      proximas: lista.proximas.map(resumoFaturaDaApi).toList(),
      anteriores: lista.anteriores.map(resumoFaturaDaApi).toList(),
    );
  });

  @override
  Future<DetalheFatura> obter(String contaId, DateTime competencia) =>
      _chamar((faturas) async {
        final resposta = await faturas.obter(
          contaId: contaId,
          competencia: competenciaParaApi(competencia),
        );
        return _detalhe(resposta.data!);
      });

  @override
  Future<DetalheFatura> editar(
    String contaId,
    DateTime competencia, {
    required DateTime dataFechamento,
    required DateTime dataVencimento,
    Decimal? valorInformado,
  }) => _chamar((faturas) async {
    final edicao = api.FaturaEdicao(
      (b) => b
        ..dataFechamento = dataFechamento.toDate()
        ..dataVencimento = dataVencimento.toDate()
        ..valorInformado = valorInformado == null
            ? null
            : dinheiroParaApi(valorInformado),
    );
    final resposta = await faturas.editar(
      contaId: contaId,
      competencia: competenciaParaApi(competencia),
      faturaEdicao: edicao,
    );
    return _detalhe(resposta.data!);
  });

  @override
  Future<DetalheFatura> ajustar(
    String contaId,
    DateTime competencia, {
    required Decimal valorReal,
    String? descricao,
  }) => _chamar((faturas) async {
    final ajuste = api.AjusteEntrada(
      (b) => b
        ..valorReal = dinheiroParaApi(valorReal)
        ..descricao = descricao,
    );
    final resposta = await faturas.ajustar(
      contaId: contaId,
      competencia: competenciaParaApi(competencia),
      ajusteEntrada: ajuste,
    );
    return _detalhe(resposta.data!);
  });

  @override
  Future<DatasFatura> paraCompra(String contaId, DateTime data) =>
      _chamar((faturas) async {
        final resposta = await faturas.paraCompra(
          contaId: contaId,
          data: data.toDate(),
        );
        return datasFaturaDaApi(resposta.data!);
      });

  @override
  Future<DetalheFatura> pagar(
    String contaId,
    DateTime competencia,
    NovoPagamento dados,
  ) => _chamar((faturas) async {
    final entrada = api.PagamentoEntrada(
      (b) => b
        ..contaId = dados.contaId
        ..valor = dinheiroParaApi(dados.valor)
        ..data = dados.data.toDate(),
    );
    final resposta = await faturas.pagar(
      contaId: contaId,
      competencia: competenciaParaApi(competencia),
      pagamentoEntrada: entrada,
    );
    return _detalhe(resposta.data!);
  });

  static DetalheFatura _detalhe(api.FaturaDetalheSaida d) => DetalheFatura(
    resumo: ResumoFatura(
      competencia: d.competencia.toDateTime(),
      dataFechamento: d.dataFechamento.toDateTime(),
      dataVencimento: d.dataVencimento.toDateTime(),
      status: StatusFatura.values.byName(d.status.name),
      valor: Decimal.parse(d.valor),
      valorCalculado: Decimal.parse(d.valorCalculado),
      valorInformado: d.valorInformado == null
          ? null
          : Decimal.parse(d.valorInformado!),
      valorPago: Decimal.parse(d.valorPago),
    ),
    fechamentoCalculado: d.fechamentoCalculado.toDateTime(),
    vencimentoCalculado: d.vencimentoCalculado.toDateTime(),
    ajusteFechamento: _ajuste(d.ajusteFechamento),
    ajusteVencimento: _ajuste(d.ajusteVencimento),
    transacoes: d.transacoes.map(transacaoDaApi).toList(),
    pagamentos: d.pagamentos.map(transacaoDaApi).toList(),
  );

  static AjusteData? _ajuste(api.AjusteDataSaida? a) => a == null
      ? null
      : AjusteData(
          dataPrevista: a.dataPrevista.toDateTime(),
          feriados: {
            for (final f in a.feriados) f.data.toDateTime(): f.descricao,
          },
        );
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
  valorPago: Decimal.parse(f.valorPago),
);
