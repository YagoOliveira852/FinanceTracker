import 'package:api_client/api_client.dart' as api;
import 'package:decimal/decimal.dart';

import '../../../core/api/erro_api.dart';
import '../../categorias/data/regra.dart';
import '../../contas/data/conta.dart';
import '../../faturas/data/fatura.dart';
import '../../transacoes/data/transacao.dart';
import 'revisao.dart';

/// A lista da revisão e as ações sobre os rascunhos. Erros da API chegam como
/// [ErroApi]; o 409 ("Esta transação já foi revisada.") quer dizer que a lista
/// do app ficou velha.
abstract interface class RevisaoRepositorio {
  Future<Revisao> carregar();

  /// Confirma com a categoria e ensina as regras. [tipo] troca o tipo no
  /// mesmo sentido (saída: despesa; entrada: receita ou estorno).
  Future<ResultadoConfirmacao> confirmar(
    String id, {
    required String descricao,
    required String categoriaId,
    TipoTransacao? tipo,
  });

  /// Ignorada, nunca apagada.
  Future<void> ignorar(String id);

  /// Confirma com a sugestão os [ids] que ainda têm sugestão; devolve quantos.
  Future<int> confirmarLote(List<String> ids);

  /// "Ligar": as duas viram transferência entre contas próprias, confirmadas.
  Future<void> ligarPar(String saidaId, String entradaId, {String? descricao});

  /// "Não é par": a sugestão deste par não volta.
  Future<void> recusarPar(String saidaId, String entradaId);

  /// O rascunho é transferência com [contaId] ("Para" numa saída, "De" numa
  /// entrada). A API cria o outro lado ou liga com o que veio de lá.
  Future<void> transferir(
    String id, {
    required String contaId,
    required String descricao,
  });

  /// As faturas que o pagamento pode ter pago, com a sugerida.
  Future<List<FaturaCandidata>> faturasDoPagamento(String id);

  /// Confirma o pagamento ligado à fatura do cartão na [competencia].
  Future<void> pagar(
    String id, {
    required String cartaoId,
    required DateTime competencia,
  });

  Future<void> resolverDuplicata(String id, ManterDuplicata manter);

  /// A que sumiu da origem continua valendo.
  Future<void> manter(String id);

  /// A que sumiu da origem fica ignorada.
  Future<void> remover(String id);
}

/// Usa o cliente gerado e converte os modelos `built_value` nos do app.
class RevisaoRepositorioApi implements RevisaoRepositorio {
  RevisaoRepositorioApi(this._cliente);

  final api.ApiClient _cliente;

  @override
  Future<Revisao> carregar() async {
    try {
      final r = (await _cliente.getRevisaoApi().listar()).data!;
      return Revisao(
        total: r.total,
        qtdSugeridos: r.qtdSugeridos,
        pares: [
          for (final p in r.pares)
            ParSugerido(
              saida: _item(p.saida),
              entrada: _item(p.entrada),
              dias: p.dias,
            ),
        ],
        pagamentos: r.pagamentos.map(_item).toList(),
        duplicatas: [
          for (final d in r.duplicatas)
            Duplicata(rascunho: _item(d.rascunho), outra: _item(d.outra)),
        ],
        sumidas: r.sumidas.map(_item).toList(),
        rascunhos: r.rascunhos.map(_rascunho).toList(),
      );
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<ResultadoConfirmacao> confirmar(
    String id, {
    required String descricao,
    required String categoriaId,
    TipoTransacao? tipo,
  }) async {
    final entrada = api.ConfirmacaoEntrada(
      (b) => b
        ..descricao = descricao
        ..categoriaId = categoriaId
        ..tipo = tipo == null
            ? null
            : api.ConfirmacaoEntradaTipoEnum.valueOf(tipo.name),
    );
    try {
      final resposta = await _cliente.getRevisaoApi().confirmar(
        transacaoId: id,
        confirmacaoEntrada: entrada,
      );
      final r = resposta.data!;
      return ResultadoConfirmacao(
        efeito: _efeito(r.efeito),
        regraPadrao: r.regraPadrao,
      );
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<void> ignorar(String id) async {
    try {
      await _cliente.getRevisaoApi().ignorar(transacaoId: id);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<int> confirmarLote(List<String> ids) async {
    try {
      final resposta = await _cliente.getRevisaoApi().confirmarLote(
        loteEntrada: api.LoteEntrada((b) => b..ids.addAll(ids)),
      );
      return resposta.data!.confirmados;
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<void> ligarPar(
    String saidaId,
    String entradaId, {
    String? descricao,
  }) => _enviar(
    () => _cliente.getRevisaoApi().ligarPar(
      parEntrada: api.ParEntrada(
        (b) => b
          ..saidaId = saidaId
          ..entradaId = entradaId
          ..descricao = descricao,
      ),
    ),
  );

  @override
  Future<void> recusarPar(String saidaId, String entradaId) => _enviar(
    () => _cliente.getRevisaoApi().recusarPar(
      parRecusaEntrada: api.ParRecusaEntrada(
        (b) => b
          ..saidaId = saidaId
          ..entradaId = entradaId,
      ),
    ),
  );

  @override
  Future<void> transferir(
    String id, {
    required String contaId,
    required String descricao,
  }) => _enviar(
    () => _cliente.getRevisaoApi().transferir(
      transacaoId: id,
      transferenciaRevisaoEntrada: api.TransferenciaRevisaoEntrada(
        (b) => b
          ..contaId = contaId
          ..descricao = descricao,
      ),
    ),
  );

  @override
  Future<List<FaturaCandidata>> faturasDoPagamento(String id) async {
    try {
      final resposta = await _cliente.getRevisaoApi().faturasDoPagamento(
        transacaoId: id,
      );
      return [
        for (final f in resposta.data!)
          FaturaCandidata(
            cartaoId: f.cartaoId,
            cartaoNome: f.cartaoNome,
            competencia: f.competencia.toDateTime(),
            status: StatusFatura.values.byName(f.status.name),
            dataVencimento: f.dataVencimento.toDateTime(),
            valor: Decimal.parse(f.valor),
            valorPago: Decimal.parse(f.valorPago),
            ficaPaga: f.ficaPaga,
            sugerida: f.sugerida,
          ),
      ];
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<void> pagar(
    String id, {
    required String cartaoId,
    required DateTime competencia,
  }) => _enviar(
    () => _cliente.getRevisaoApi().pagar(
      transacaoId: id,
      pagamentoRevisaoEntrada: api.PagamentoRevisaoEntrada(
        (b) => b
          ..cartaoId = cartaoId
          ..competencia = competenciaParaApi(competencia),
      ),
    ),
  );

  @override
  Future<void> resolverDuplicata(String id, ManterDuplicata manter) => _enviar(
    () => _cliente.getRevisaoApi().resolverDuplicata(
      transacaoId: id,
      duplicataEntrada: api.DuplicataEntrada(
        (b) => b..manter = api.ManterDuplicata.valueOf(manter.name),
      ),
    ),
  );

  @override
  Future<void> manter(String id) =>
      _enviar(() => _cliente.getRevisaoApi().manter(transacaoId: id));

  @override
  Future<void> remover(String id) =>
      _enviar(() => _cliente.getRevisaoApi().remover(transacaoId: id));

  /// Ações sem corpo na resposta (204).
  static Future<void> _enviar(Future<Object?> Function() chamada) async {
    try {
      await chamada();
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  static Rascunho _rascunho(api.RascunhoSaida r) => Rascunho(
    item: ItemRevisao(
      id: r.id,
      contaId: r.conta.id,
      contaNome: r.conta.nome,
      contaTipo: TipoConta.values.byName(r.conta.tipo.name),
      tipo: TipoTransacao.values.byName(r.tipo.name),
      valor: Decimal.parse(r.valor),
      data: r.data.toDateTime(),
      descricao: r.descricao,
      descricaoOriginal: r.descricaoOriginal,
      fonte: FonteTransacao.values.byName(r.fonte.name),
      status: StatusTransacao.values.byName(r.status.name),
      faturaCompetencia: r.faturaCompetencia?.toDateTime(),
    ),
    padrao: r.padrao,
    sugestao: switch (r.sugestao) {
      final s? => Sugestao(
        regraId: s.regraId,
        padrao: s.padrao,
        origem: OrigemRegra.values.byName(s.origem.name),
        categoria: CategoriaDaTransacao(
          id: s.categoria.id,
          nome: s.categoria.nome,
        ),
      ),
      null => null,
    },
    efeitoConfirmando: _efeito(r.efeitoConfirmando),
    efeitoCorrigindo: _efeito(r.efeitoCorrigindo),
  );

  static ItemRevisao _item(api.TransacaoRevisao t) => ItemRevisao(
    id: t.id,
    contaId: t.conta.id,
    contaNome: t.conta.nome,
    contaTipo: TipoConta.values.byName(t.conta.tipo.name),
    tipo: TipoTransacao.values.byName(t.tipo.name),
    valor: Decimal.parse(t.valor),
    data: t.data.toDateTime(),
    descricao: t.descricao,
    descricaoOriginal: t.descricaoOriginal,
    fonte: FonteTransacao.values.byName(t.fonte.name),
    status: StatusTransacao.values.byName(t.status.name),
    categoria: switch (t.categoria) {
      final c? => CategoriaDaTransacao(id: c.id, nome: c.nome),
      null => null,
    },
    faturaCompetencia: t.faturaCompetencia?.toDateTime(),
    removidaNaOrigemEm: t.removidaNaOrigemEm?.toLocal(),
  );

  static EfeitoRegra _efeito(api.EfeitoAprendizado efeito) =>
      EfeitoRegra.values.byName(efeito.name);
}
