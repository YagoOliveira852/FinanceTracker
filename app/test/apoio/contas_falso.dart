import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/contas/data/contas_repositorio.dart';
import 'package:financas/features/faturas/data/fatura.dart';

Conta contaExemplo({
  String id = 'c1',
  String nome = 'Conta principal',
  TipoConta tipo = TipoConta.corrente,
  String? instituicao = 'Banco Exemplo',
  String saldo = '2350.00',
  bool ativa = true,
  Cartao? cartao,
}) => Conta(
  id: id,
  nome: nome,
  tipo: tipo,
  instituicao: tipo == TipoConta.carteira ? null : instituicao,
  saldoInicial: Decimal.parse(saldo),
  dataSaldoInicial: DateTime(2026, 10, 1),
  saldoAtual: Decimal.parse(saldo),
  ativa: ativa,
  cartao: cartao,
);

/// Fatura de novembro do cartão do exemplo (fecha dia 3, vence dia 10).
ResumoFatura faturaExemplo({
  String valor = '544.80',
  String? informado,
  StatusFatura status = StatusFatura.aberta,
}) => ResumoFatura(
  competencia: DateTime(2026, 11),
  dataFechamento: DateTime(2026, 11, 3),
  dataVencimento: DateTime(2026, 11, 10),
  status: status,
  valor: Decimal.parse(valor),
  valorCalculado: Decimal.parse(valor),
  valorInformado: informado == null ? null : Decimal.parse(informado),
);

Conta cartaoExemplo({String id = 'k1', bool ativa = true}) => contaExemplo(
  id: id,
  nome: 'Cartão Exemplo',
  tipo: TipoConta.cartaoCredito,
  saldo: '0.00',
  ativa: ativa,
  cartao: Cartao(
    contaPagamentoId: 'c1',
    diaFechamento: 3,
    diaVencimento: 10,
    limite: Decimal.parse('3000.00'),
    faturaAtual: faturaExemplo(),
  ),
);

/// Prévia de "Próxima fatura" que o falso devolve.
final previaExemplo = DatasFatura(
  competencia: DateTime(2026, 11),
  dataFechamento: DateTime(2026, 11, 3),
  dataVencimento: DateTime(2026, 11, 10),
);

/// Repositório de contas em memória. [erro] faz a próxima chamada falhar.
class ContasRepositorioFalso implements ContasRepositorio {
  ContasRepositorioFalso({List<Conta>? contas}) : contas = contas ?? [];

  final List<Conta> contas;
  final criadas = <NovaConta>[];
  final cartoesCriados = <NovoCartao>[];
  final previas = <({int diaFechamento, int diaVencimento})>[];
  final cartoesEditados = <({String contaId, EdicaoCartao dados})>[];
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

  @override
  Future<Conta> criarCartao(NovoCartao dados) async {
    if (erro case final e?) throw e;
    cartoesCriados.add(dados);
    final conta = cartaoExemplo(id: 'cartao-${cartoesCriados.length}')
        .copyWith(nome: dados.nome, instituicao: dados.instituicao);
    contas.add(conta);
    return conta;
  }

  @override
  Future<DatasFatura> previaFatura({
    required int diaFechamento,
    required int diaVencimento,
  }) async {
    previas.add((diaFechamento: diaFechamento, diaVencimento: diaVencimento));
    if (erro case final e?) throw e;
    return previaExemplo;
  }

  @override
  Future<Conta> editarCartao(String contaId, EdicaoCartao dados) async {
    if (erro case final e?) throw e;
    cartoesEditados.add((contaId: contaId, dados: dados));
    final indice = contas.indexWhere((c) => c.id == contaId);
    final conta = contas[indice].copyWith(
      nome: dados.nome,
      instituicao: dados.instituicao,
      ativa: dados.ativa,
    );
    contas[indice] = conta;
    return conta;
  }
}
