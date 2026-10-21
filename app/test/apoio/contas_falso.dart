import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/contas/data/contas_repositorio.dart';

Conta contaExemplo({
  String id = 'c1',
  String nome = 'Conta principal',
  TipoConta tipo = TipoConta.corrente,
  String? instituicao = 'Banco Exemplo',
  String saldo = '2350.00',
  bool ativa = true,
}) => Conta(
  id: id,
  nome: nome,
  tipo: tipo,
  instituicao: tipo == TipoConta.carteira ? null : instituicao,
  saldoInicial: Decimal.parse(saldo),
  dataSaldoInicial: DateTime(2026, 10, 1),
  saldoAtual: Decimal.parse(saldo),
  ativa: ativa,
);

/// Repositório de contas em memória. [erro] faz a próxima chamada falhar.
class ContasRepositorioFalso implements ContasRepositorio {
  ContasRepositorioFalso({List<Conta>? contas}) : contas = contas ?? [];

  final List<Conta> contas;
  final criadas = <NovaConta>[];
  ErroApi? erro;

  @override
  Future<ResumoContas> listar() async {
    if (erro case final e?) throw e;
    final disponivel = contas
        .where((c) => c.ativa && c.tipo != TipoConta.cartaoCredito)
        .fold(Decimal.zero, (soma, c) => soma + c.saldoAtual);
    return ResumoContas(totalDisponivel: disponivel, contas: List.of(contas));
  }

  @override
  Future<Conta> criar(NovaConta dados) async {
    if (erro case final e?) throw e;
    criadas.add(dados);
    final conta = Conta(
      id: 'nova-${criadas.length}',
      nome: dados.nome,
      tipo: dados.tipo,
      instituicao: dados.instituicao,
      saldoInicial: dados.saldoInicial,
      dataSaldoInicial: dados.dataSaldoInicial,
      saldoAtual: dados.saldoInicial,
      ativa: true,
    );
    contas.add(conta);
    return conta;
  }
}
