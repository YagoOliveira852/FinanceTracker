import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/categorias/data/regra.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/faturas/data/fatura.dart';
import 'package:financas/features/revisao/data/revisao.dart';
import 'package:financas/features/revisao/data/revisao_repositorio.dart';
import 'package:financas/features/transacoes/data/transacao.dart';

ItemRevisao itemExemplo({
  String id = 'i1',
  String contaId = 'c1',
  String contaNome = 'Conta principal',
  TipoConta contaTipo = TipoConta.corrente,
  TipoTransacao tipo = TipoTransacao.despesa,
  String valor = '18.50',
  DateTime? data,
  String descricao = 'Padaria Pão Quente',
  String descricaoOriginal = 'PADARIA PAO QUENTE',
  FonteTransacao fonte = FonteTransacao.pluggy,
  StatusTransacao status = StatusTransacao.rascunho,
  CategoriaDaTransacao? categoria,
  DateTime? faturaCompetencia,
}) => ItemRevisao(
  id: id,
  contaId: contaId,
  contaNome: contaNome,
  contaTipo: contaTipo,
  tipo: tipo,
  valor: Decimal.parse(valor),
  data: data ?? DateTime(2026, 10, 25),
  descricao: descricao,
  descricaoOriginal: descricaoOriginal,
  fonte: fonte,
  status: status,
  categoria: categoria,
  faturaCompetencia: faturaCompetencia,
);

Sugestao sugestaoExemplo({
  String padrao = 'padaria pao quente',
  OrigemRegra origem = OrigemRegra.aprendida,
  String categoriaId = 'cat-alimentacao',
  String categoriaNome = 'Alimentação',
}) => Sugestao(
  regraId: 'r-$padrao',
  padrao: padrao,
  origem: origem,
  categoria: CategoriaDaTransacao(id: categoriaId, nome: categoriaNome),
);

/// Padaria com sugestão aprendida (Alimentação).
Rascunho rascunhoSugerido() => Rascunho(
  item: itemExemplo(),
  padrao: 'padaria pao quente',
  sugestao: sugestaoExemplo(),
  efeitoConfirmando: EfeitoRegra.reforcada,
  efeitoCorrigindo: EfeitoRegra.corrigida,
);

/// Lanchonete com sugestão de uma regra manual (Mercado).
Rascunho rascunhoDeManual() => Rascunho(
  item: itemExemplo(
    id: 'i2',
    valor: '32.00',
    descricao: 'Lanchonete Exemplo',
    descricaoOriginal: 'PIX ENVIADO 25/10 LANCHONETE EXEMPLO LTDA',
  ),
  padrao: 'lanchonete exemplo ltda',
  sugestao: sugestaoExemplo(
    padrao: 'lanchonete',
    origem: OrigemRegra.manual,
    categoriaId: 'cat-mercado',
    categoriaNome: 'Mercado',
  ),
  efeitoConfirmando: EfeitoRegra.reforcada,
  efeitoCorrigindo: EfeitoRegra.manualMantida,
);

/// Posto sem sugestão, num cartão, no dia anterior.
Rascunho rascunhoSemSugestao() => Rascunho(
  item: itemExemplo(
    id: 'i3',
    contaId: 'k1',
    contaNome: 'Cartão Exemplo',
    contaTipo: TipoConta.cartaoCredito,
    valor: '150.00',
    data: DateTime(2026, 10, 24),
    descricao: 'Posto Fictício',
    descricaoOriginal: 'POSTO FICTICIO 0193 FORTALEZA BR',
    fonte: FonteTransacao.ofx,
    faturaCompetencia: DateTime(2026, 11),
  ),
  padrao: 'posto ficticio fortaleza br',
  efeitoConfirmando: EfeitoRegra.criada,
  efeitoCorrigindo: EfeitoRegra.criada,
);

Duplicata duplicataExemplo() => Duplicata(
  rascunho: itemExemplo(
    id: 'd1',
    valor: '64.90',
    data: DateTime(2026, 10, 22),
    descricao: 'Mercado do Bairro Ltda',
    descricaoOriginal: 'MERCADO DO BAIRRO LTDA',
  ),
  outra: itemExemplo(
    id: 'd2',
    valor: '64.90',
    data: DateTime(2026, 10, 22),
    descricao: 'Mercado do bairro',
    descricaoOriginal: 'COMPRA NO DEBITO MERCADO DO BAIRRO',
    fonte: FonteTransacao.ofx,
    status: StatusTransacao.confirmada,
    categoria: const CategoriaDaTransacao(id: 'cat-mercado', nome: 'Mercado'),
  ),
);

ParSugerido parExemplo() => ParSugerido(
  saida: itemExemplo(
    id: 'p1',
    valor: '300.00',
    data: DateTime(2026, 10, 24),
    descricao: 'PIX ENVIADO CONTA DIA A DIA',
    descricaoOriginal: 'PIX ENVIADO CONTA DIA A DIA',
  ),
  entrada: itemExemplo(
    id: 'p2',
    contaId: 'c2',
    contaNome: 'Conta do dia a dia',
    tipo: TipoTransacao.receita,
    valor: '300.00',
    descricao: 'PIX RECEBIDO CONTA PRINCIPAL',
    descricaoOriginal: 'PIX RECEBIDO CONTA PRINCIPAL',
  ),
  dias: 1,
);

ItemRevisao pagamentoExemplo() => itemExemplo(
  id: 'f1',
  tipo: TipoTransacao.pagamentoFatura,
  valor: '1032.15',
  data: DateTime(2026, 10, 13),
  descricao: 'Pagamento de fatura',
  descricaoOriginal: 'PAGAMENTO DE FATURA CARTAO EXEMPLO',
);

ItemRevisao sumidaExemplo() => itemExemplo(
  id: 's1',
  valor: '42.30',
  data: DateTime(2026, 10, 20),
  descricao: 'Farmácia Exemplo',
  descricaoOriginal: 'FARMACIA EXEMPLO',
  status: StatusTransacao.confirmada,
  categoria: const CategoriaDaTransacao(id: 'cat-mercado', nome: 'Mercado'),
);

/// Outubro (fechada, sugerida) e novembro (aberta) do Cartão Exemplo.
List<FaturaCandidata> candidatasExemplo() => [
  FaturaCandidata(
    cartaoId: 'k1',
    cartaoNome: 'Cartão Exemplo',
    competencia: DateTime(2026, 10),
    status: StatusFatura.fechada,
    dataVencimento: DateTime(2026, 10, 13),
    valor: Decimal.parse('1032.15'),
    valorPago: Decimal.zero,
    ficaPaga: true,
    sugerida: true,
  ),
  FaturaCandidata(
    cartaoId: 'k1',
    cartaoNome: 'Cartão Exemplo',
    competencia: DateTime(2026, 11),
    status: StatusFatura.aberta,
    dataVencimento: DateTime(2026, 11, 10),
    valor: Decimal.parse('544.80'),
    valorPago: Decimal.zero,
    ficaPaga: false,
    sugerida: false,
  ),
];

/// Monta a revisão com o total e os sugeridos coerentes com as listas.
Revisao revisaoCom({
  List<Rascunho>? rascunhos,
  List<ParSugerido> pares = const [],
  List<ItemRevisao> pagamentos = const [],
  List<Duplicata> duplicatas = const [],
  List<ItemRevisao> sumidas = const [],
}) {
  final comuns =
      rascunhos ??
      [rascunhoSugerido(), rascunhoDeManual(), rascunhoSemSugestao()];
  return Revisao(
    total:
        comuns.length +
        pares.length +
        pagamentos.length +
        duplicatas.length +
        sumidas.length,
    qtdSugeridos: comuns.where((r) => r.sugestao != null).length,
    pares: pares,
    pagamentos: pagamentos,
    duplicatas: duplicatas,
    sumidas: sumidas,
    rascunhos: comuns,
  );
}

/// Revisão com uma decisão de cada tipo e os três rascunhos comuns.
Revisao revisaoComDecisoes() => revisaoCom(
  pares: [parExemplo()],
  pagamentos: [pagamentoExemplo()],
  duplicatas: [duplicataExemplo()],
  sumidas: [sumidaExemplo()],
);

/// Repositório da revisão em memória: confirmar e ignorar tiram o rascunho
/// da lista, como a API. [erro] faz a próxima chamada falhar.
class RevisaoRepositorioFalso implements RevisaoRepositorio {
  RevisaoRepositorioFalso({Revisao? revisao})
    : revisao = revisao ?? revisaoCom();

  Revisao revisao;
  ErroApi? erro;
  var cargas = 0;
  final confirmados =
      <
        ({String id, String descricao, String categoriaId, TipoTransacao? tipo})
      >[];
  final ignorados = <String>[];
  final lotes = <List<String>>[];

  /// Cada decisão enviada, como texto: "ligar p1 p2", "manter s1"...
  final decisoes = <String>[];
  var candidatas = candidatasExemplo();

  @override
  Future<Revisao> carregar() async {
    cargas++;
    if (erro case final e?) throw e;
    return revisao;
  }

  @override
  Future<ResultadoConfirmacao> confirmar(
    String id, {
    required String descricao,
    required String categoriaId,
    TipoTransacao? tipo,
  }) async {
    if (erro case final e?) throw e;
    confirmados.add((
      id: id,
      descricao: descricao,
      categoriaId: categoriaId,
      tipo: tipo,
    ));
    final rascunho = revisao.rascunhos.firstWhere((r) => r.item.id == id);
    _tirar([id]);
    return ResultadoConfirmacao(
      efeito: rascunho.efeitoPara(categoriaId),
      regraPadrao: rascunho.padrao,
    );
  }

  @override
  Future<void> ignorar(String id) async {
    if (erro case final e?) throw e;
    ignorados.add(id);
    _tirar([id]);
  }

  @override
  Future<int> confirmarLote(List<String> ids) async {
    if (erro case final e?) throw e;
    lotes.add(ids);
    final sugeridos = {for (final r in revisao.sugeridos) r.item.id};
    final confirmados = ids.where(sugeridos.contains).toList();
    _tirar(confirmados);
    return confirmados.length;
  }

  @override
  Future<void> ligarPar(
    String saidaId,
    String entradaId, {
    String? descricao,
  }) => _decidir('ligar $saidaId $entradaId ${descricao ?? '-'}', [saidaId]);

  @override
  Future<void> recusarPar(String saidaId, String entradaId) =>
      _decidir('recusar $saidaId $entradaId', [saidaId]);

  @override
  Future<void> transferir(
    String id, {
    required String contaId,
    required String descricao,
  }) => _decidir('transferir $id $contaId $descricao', [id]);

  @override
  Future<List<FaturaCandidata>> faturasDoPagamento(String id) async {
    if (erro case final e?) throw e;
    return candidatas;
  }

  @override
  Future<void> pagar(
    String id, {
    required String cartaoId,
    required DateTime competencia,
  }) => _decidir('pagar $id $cartaoId ${competencia.month}', [id]);

  @override
  Future<void> resolverDuplicata(String id, ManterDuplicata manter) =>
      _decidir('duplicata $id ${manter.name}', [id]);

  @override
  Future<void> manter(String id) => _decidir('manter $id', [id]);

  @override
  Future<void> remover(String id) => _decidir('remover $id', [id]);

  Future<void> _decidir(String decisao, List<String> ids) async {
    if (erro case final e?) throw e;
    decisoes.add(decisao);
    _tirar(ids);
  }

  /// Tira da revisão os rascunhos e as decisões que envolvem os [ids].
  void _tirar(List<String> ids) {
    revisao = revisaoCom(
      rascunhos: [
        for (final r in revisao.rascunhos)
          if (!ids.contains(r.item.id)) r,
      ],
      pares: [
        for (final p in revisao.pares)
          if (!ids.contains(p.saida.id)) p,
      ],
      pagamentos: [
        for (final p in revisao.pagamentos)
          if (!ids.contains(p.id)) p,
      ],
      duplicatas: [
        for (final d in revisao.duplicatas)
          if (!ids.contains(d.rascunho.id)) d,
      ],
      sumidas: [
        for (final s in revisao.sumidas)
          if (!ids.contains(s.id)) s,
      ],
    );
  }
}
