import 'package:api_client/api_client.dart' as api;
import 'package:decimal/decimal.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../faturas/data/fatura.dart';
import '../../faturas/data/faturas_repositorio.dart';
import 'conta.dart';

/// Contas do usuário. Erros da API chegam como [ErroApi].
abstract interface class ContasRepositorio {
  Future<ResumoContas> listar();
  Future<Conta> criar(NovaConta dados);
  Future<Conta> criarCartao(NovoCartao dados);

  /// A fatura em que entraria uma compra feita hoje, para dias ainda não
  /// salvos (prévia da Nova conta).
  Future<DatasFatura> previaFatura({
    required int diaFechamento,
    required int diaVencimento,
  });
}

/// Usa o cliente gerado e converte os modelos `built_value` nos do app:
/// dinheiro `String` → [Decimal], `Date` → [DateTime].
class ContasRepositorioApi implements ContasRepositorio {
  ContasRepositorioApi(this._cliente);

  final api.ApiClient _cliente;

  @override
  Future<ResumoContas> listar() async {
    try {
      final resumo = (await _cliente.getContasApi().listar()).data!;
      return ResumoContas(
        totalDisponivel: Decimal.parse(resumo.totalDisponivel),
        contas: resumo.contas.map(_conta).toList(),
      );
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<Conta> criar(NovaConta dados) async {
    final entrada = api.ContaEntrada(
      (b) => b
        ..nome = dados.nome
        ..tipo = switch (dados.tipo) {
          TipoConta.corrente => api.ContaEntradaTipoEnum.corrente,
          TipoConta.carteira => api.ContaEntradaTipoEnum.carteira,
          TipoConta.cartaoCredito => throw ArgumentError(
            'Cartão de crédito não é criado por aqui.',
          ),
        }
        ..instituicao = dados.instituicao
        ..saldoInicial = dinheiroParaApi(dados.saldoInicial)
        ..dataSaldoInicial = dados.dataSaldoInicial.toDate(),
    );
    try {
      final resposta = await _cliente.getContasApi().criar(
        contaEntrada: entrada,
      );
      return _conta(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<Conta> criarCartao(NovoCartao dados) async {
    final entrada = api.CartaoEntrada(
      (b) => b
        ..nome = dados.nome
        ..instituicao = dados.instituicao
        ..contaPagamentoId = dados.contaPagamentoId
        ..diaFechamento = dados.diaFechamento
        ..diaVencimento = dados.diaVencimento
        ..limite = dados.limite == null ? null : dinheiroParaApi(dados.limite!),
    );
    try {
      final resposta = await _cliente.getCartoesApi().criar(
        cartaoEntrada: entrada,
      );
      return _conta(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<DatasFatura> previaFatura({
    required int diaFechamento,
    required int diaVencimento,
  }) async {
    try {
      final resposta = await _cliente.getCartoesApi().previa(
        diaFechamento: diaFechamento,
        diaVencimento: diaVencimento,
      );
      return datasFaturaDaApi(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  static Conta _conta(api.ContaSaida conta) => Conta(
    id: conta.id,
    nome: conta.nome,
    tipo: TipoConta.values.byName(conta.tipo.name),
    instituicao: conta.instituicao?.nome,
    saldoInicial: Decimal.parse(conta.saldoInicial),
    dataSaldoInicial: conta.dataSaldoInicial.toDateTime(),
    saldoAtual: Decimal.parse(conta.saldoAtual),
    ativa: conta.ativa,
    cartao: conta.cartao == null ? null : _cartao(conta.cartao!),
  );

  static Cartao _cartao(api.CartaoSaida cartao) => Cartao(
    contaPagamentoId: cartao.contaPagamentoId,
    diaFechamento: cartao.diaFechamento,
    diaVencimento: cartao.diaVencimento,
    limite: cartao.limite == null ? null : Decimal.parse(cartao.limite!),
    faturaAtual: resumoFaturaDaApi(cartao.faturaAtual),
  );
}
