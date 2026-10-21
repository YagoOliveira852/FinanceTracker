import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/transacoes/data/transacao.dart';
import 'package:financas/features/transacoes/data/transacoes_repositorio.dart';

Transacao transacaoExemplo({
  String id = 't1',
  String contaId = 'c1',
  TipoTransacao tipo = TipoTransacao.despesa,
  String valor = '187.40',
  DateTime? data,
  String descricao = 'Mercado do bairro',
  StatusTransacao status = StatusTransacao.confirmada,
}) => Transacao(
  id: id,
  contaId: contaId,
  tipo: tipo,
  valor: Decimal.parse(valor),
  data: data ?? DateTime(2026, 10, 20),
  descricao: descricao,
  status: status,
);

/// Repositório de transações em memória: filtra por conta e período como a
/// API e devolve da mais recente para a mais antiga.
class TransacoesRepositorioFalso implements TransacoesRepositorio {
  TransacoesRepositorioFalso({List<Transacao>? transacoes})
    : transacoes = transacoes ?? [];

  final List<Transacao> transacoes;
  final consultas = <({String? contaId, DateTime de, DateTime ate})>[];
  final lancados = <NovoLancamento>[];
  ErroApi? erro;

  @override
  Future<List<Transacao>> listar({
    String? contaId,
    required DateTime de,
    required DateTime ate,
  }) async {
    consultas.add((contaId: contaId, de: de, ate: ate));
    if (erro case final e?) throw e;
    return transacoes
        .where((t) => contaId == null || t.contaId == contaId)
        .where((t) => !t.data.isBefore(de) && !t.data.isAfter(ate))
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));
  }

  @override
  Future<Transacao> lancar(NovoLancamento dados) async {
    if (erro case final e?) throw e;
    lancados.add(dados);
    final transacao = Transacao(
      id: 'novo-${lancados.length}',
      contaId: dados.contaId,
      tipo: dados.tipo,
      valor: dados.valor,
      data: dados.data,
      descricao: dados.descricao,
      status: StatusTransacao.confirmada,
    );
    transacoes.add(transacao);
    return transacao;
  }
}
