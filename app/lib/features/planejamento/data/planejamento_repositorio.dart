import 'package:api_client/api_client.dart' as api;
import 'package:decimal/decimal.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/dinheiro.dart';
import 'planejamento.dart';
import 'resumo.dart';

/// Rendas previstas, configuração do cálculo e o resumo do Início. Erros da
/// API chegam como [ErroApi].
abstract interface class PlanejamentoRepositorio {
  /// Ativas primeiro, pela próxima data; depois as inativas.
  Future<List<Renda>> listarRendas();
  Future<Renda> criarRenda(DadosRenda dados);

  /// Edita a renda ou a desativa/reativa ([DadosRenda.ativa]).
  Future<Renda> editarRenda(String id, DadosRenda dados);

  /// A próxima data para um dia ainda não salvo (formulário da renda).
  Future<ProximaData> previaRenda(int diaPrevisto);
  Future<LeituraConfiguracao> lerConfiguracao();

  /// Cria a configuração no primeiro salvamento; depois, atualiza.
  Future<LeituraConfiguracao> salvarConfiguracao(Configuracao configuracao);

  /// Sobra, alerta, aporte e reserva: o que o Início mostra.
  Future<Resumo> lerResumo();
}

/// Usa o cliente gerado e converte os modelos `built_value` nos do app:
/// valores `String` → [Decimal], `Date` → [DateTime].
class PlanejamentoRepositorioApi implements PlanejamentoRepositorio {
  PlanejamentoRepositorioApi(this._cliente);

  final api.ApiClient _cliente;

  api.PlanejamentoApi get _api => _cliente.getPlanejamentoApi();

  @override
  Future<List<Renda>> listarRendas() async {
    try {
      final rendas = (await _api.listarRendas()).data!;
      return rendas.map(_renda).toList();
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<Renda> criarRenda(DadosRenda dados) async {
    final entrada = api.RendaEntrada(
      (b) => b
        ..descricao = dados.descricao
        ..valor = dinheiroParaApi(dados.valor)
        ..diaPrevisto = dados.diaPrevisto
        ..contaId = dados.contaId,
    );
    try {
      return _renda((await _api.criarRenda(rendaEntrada: entrada)).data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<Renda> editarRenda(String id, DadosRenda dados) async {
    final edicao = api.RendaEdicao(
      (b) => b
        ..descricao = dados.descricao
        ..valor = dinheiroParaApi(dados.valor)
        ..diaPrevisto = dados.diaPrevisto
        ..contaId = dados.contaId
        ..ativa = dados.ativa,
    );
    try {
      final resposta = await _api.editarRenda(rendaId: id, rendaEdicao: edicao);
      return _renda(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<ProximaData> previaRenda(int diaPrevisto) async {
    try {
      final resposta = await _api.previaRenda(diaPrevisto: diaPrevisto);
      return _proxima(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<LeituraConfiguracao> lerConfiguracao() async {
    try {
      return _leitura((await _api.obterConfiguracao()).data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<LeituraConfiguracao> salvarConfiguracao(
    Configuracao configuracao,
  ) async {
    final entrada = api.ConfiguracaoEntrada(
      (b) => b
        ..colchao = dinheiroParaApi(configuracao.colchao)
        ..metaReservaMeses = configuracao.metaReservaMeses.toStringAsFixed(1)
        ..gastoSemanalEstimado = dinheiroParaApi(
          configuracao.gastoSemanalEstimado,
        )
        ..gastoMensalReferencia = switch (configuracao.gastoMensalReferencia) {
          final valor? => dinheiroParaApi(valor),
          null => null,
        },
    );
    try {
      final resposta = await _api.salvarConfiguracao(
        configuracaoEntrada: entrada,
      );
      return _leitura(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<Resumo> lerResumo() async {
    try {
      return _resumo((await _api.resumo()).data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  static Resumo _resumo(api.ResumoSaida resumo) {
    final gasto = resumo.gastoMensal;
    return Resumo(
      saldoDisponivel: Decimal.parse(resumo.saldoDisponivel),
      rascunhos: resumo.rascunhos,
      previsao: switch (resumo.previsao) {
        final previsao? => _previsao(previsao),
        null => null,
      },
      gastoMensal: gasto == null
          ? null
          : GastoMensalReferencia(
              valor: Decimal.parse(gasto.valor),
              automatico: gasto.automatico,
            ),
      metaReservaMeses: _decimal(resumo.metaReservaMeses),
    );
  }

  static Previsao _previsao(api.PrevisaoSaida previsao) {
    final recebido = previsao.salarioRecebido;
    return Previsao(
      proximoSalario: previsao.proximoSalario.toDateTime(),
      diasAteSalario: previsao.diasAteSalario,
      faturas: [
        for (final fatura in previsao.faturas)
          FaturaReservada(
            cartaoId: fatura.cartaoId,
            cartao: fatura.cartao,
            competencia: fatura.competencia.toDateTime(),
            vencimento: fatura.vencimento.toDateTime(),
            valor: Decimal.parse(fatura.valor),
          ),
      ],
      gastosPrevistos: Decimal.parse(previsao.gastosPrevistos),
      gastosPelaMedia: previsao.gastosPelaMedia,
      sobra: Decimal.parse(previsao.sobra),
      nivel: NivelRitmo.values.byName(previsao.nivel.name),
      colchao: Decimal.parse(previsao.colchao),
      salarioRecebido: recebido == null
          ? null
          : SalarioRecebido(
              rendaId: recebido.rendaId,
              descricao: recebido.descricao,
              contaId: recebido.contaId,
              conta: recebido.conta,
              dataEsperada: recebido.dataEsperada.toDateTime(),
              data: recebido.data.toDateTime(),
              valor: Decimal.parse(recebido.valor),
            ),
      aporte: _decimal(previsao.aporte),
    );
  }

  static Renda _renda(api.RendaSaida renda) => Renda(
    id: renda.id,
    descricao: renda.descricao,
    valor: Decimal.parse(renda.valor),
    diaPrevisto: renda.diaPrevisto,
    contaId: renda.contaId,
    ativa: renda.ativa,
    proxima: _proxima(renda.proxima),
  );

  static ProximaData _proxima(api.ProximaDataSaida proxima) => ProximaData(
    data: proxima.data.toDateTime(),
    dataPrevista: proxima.dataPrevista.toDateTime(),
    feriados: {
      for (final f in proxima.feriados) f.data.toDateTime(): f.descricao,
    },
  );

  static LeituraConfiguracao _leitura(api.ConfiguracaoSaida leitura) {
    final configuracao = leitura.configuracao;
    final automatico = leitura.gastoMensalAutomatico;
    return LeituraConfiguracao(
      configuracao: configuracao == null
          ? null
          : Configuracao(
              colchao: Decimal.parse(configuracao.colchao),
              metaReservaMeses: Decimal.parse(configuracao.metaReservaMeses),
              gastoSemanalEstimado: Decimal.parse(
                configuracao.gastoSemanalEstimado,
              ),
              gastoMensalReferencia: _decimal(
                configuracao.gastoMensalReferencia,
              ),
            ),
      gastoMensalAutomatico: automatico == null
          ? null
          : GastoMensal(
              valor: Decimal.parse(automatico.valor),
              meses: [for (final mes in automatico.meses) mes.toDateTime()],
            ),
      mediaSemanalReal: _decimal(leitura.mediaSemanalReal),
      mesesDeReserva: _decimal(leitura.mesesDeReserva),
    );
  }

  static Decimal? _decimal(String? texto) =>
      texto == null ? null : Decimal.parse(texto);
}
