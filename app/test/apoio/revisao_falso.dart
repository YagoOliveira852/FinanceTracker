import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/categorias/data/regra.dart';
import 'package:financas/features/contas/data/conta.dart';
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

/// Monta a revisão com o total e os sugeridos coerentes com as listas.
Revisao revisaoCom({
  List<Rascunho>? rascunhos,
  List<Duplicata> duplicatas = const [],
}) {
  final comuns =
      rascunhos ??
      [rascunhoSugerido(), rascunhoDeManual(), rascunhoSemSugestao()];
  return Revisao(
    total: comuns.length + duplicatas.length,
    qtdSugeridos: comuns.where((r) => r.sugestao != null).length,
    duplicatas: duplicatas,
    rascunhos: comuns,
  );
}

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

  void _tirar(List<String> ids) {
    revisao = revisaoCom(
      rascunhos: [
        for (final r in revisao.rascunhos)
          if (!ids.contains(r.item.id)) r,
      ],
      duplicatas: revisao.duplicatas,
    );
  }
}
