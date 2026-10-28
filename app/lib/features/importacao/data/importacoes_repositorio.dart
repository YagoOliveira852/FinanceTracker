import 'package:api_client/api_client.dart' as api;
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../../../core/api/erro_api.dart';
import '../../contas/data/conta.dart';
import 'importacao.dart';

/// Importação de extratos: enviar, histórico, resumo e desfazer. Erros da API
/// chegam como [ErroApi] (`arquivo` e `conta_id` em [ErroApi.campos]); o FITID
/// repetido, como [ErroFitidRepetido], com as linhas.
abstract interface class ImportacoesRepositorio {
  /// Do mais recente para o mais antigo.
  Future<List<Importacao>> listar();

  Future<Importacao> obter(String id);

  Future<ResultadoImportacao> importar({
    required String contaId,
    required ArquivoEscolhido arquivo,
  });

  /// Só enquanto nada da importação foi confirmado (senão, 409).
  Future<void> desfazer(String id);
}

/// O arquivo tem lançamentos com o mesmo FITID: nada foi importado.
class ErroFitidRepetido extends ErroApi {
  const ErroFitidRepetido(super.mensagem, this.linhas) : super(status: 422);

  final List<LinhaRepetida> linhas;
}

/// Usa o cliente gerado e converte os modelos `built_value` nos do app.
class ImportacoesRepositorioApi implements ImportacoesRepositorio {
  ImportacoesRepositorioApi(this._cliente);

  final api.ApiClient _cliente;

  @override
  Future<List<Importacao>> listar() async {
    try {
      final resposta = await _cliente.getImportacoesApi().listar();
      return resposta.data!.map(_importacao).toList();
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<Importacao> obter(String id) async {
    try {
      final resposta = await _cliente.getImportacoesApi().obter(
        importacaoId: id,
      );
      return _importacao(resposta.data!);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  @override
  Future<ResultadoImportacao> importar({
    required String contaId,
    required ArquivoEscolhido arquivo,
  }) async {
    try {
      final resposta = await _cliente.getImportacoesApi().importar(
        arquivo: MultipartFile.fromBytes(arquivo.bytes, filename: arquivo.nome),
        contaId: contaId,
      );
      final r = resposta.data!;
      return ResultadoImportacao(
        jaImportada: r.jaImportada,
        importacao: _importacao(r.importacao),
      );
    } catch (erro) {
      throw _fitidRepetido(erro) ?? ErroApi.de(erro);
    }
  }

  @override
  Future<void> desfazer(String id) async {
    try {
      await _cliente.getImportacoesApi().desfazer(importacaoId: id);
    } catch (erro) {
      throw ErroApi.de(erro);
    }
  }

  /// O 422 do FITID repetido traz `linhas_repetidas` além do `detail`; o
  /// cliente gerado não lê corpo de erro, então ele vem cru do dio.
  static ErroFitidRepetido? _fitidRepetido(Object erro) {
    if (erro is! DioException) return null;
    final corpo = erro.response?.data;
    if (corpo is! Map || corpo['linhas_repetidas'] is! List) return null;
    return ErroFitidRepetido(
      corpo['detail'] as String? ?? 'Nada foi importado.',
      [
        for (final linha
            in (corpo['linhas_repetidas'] as List).whereType<Map>())
          LinhaRepetida(
            fitid: linha['fitid'] as String,
            data: DateTime.parse(linha['data'] as String),
            valor: Decimal.parse(linha['valor'] as String),
            descricao: linha['descricao'] as String,
          ),
      ],
    );
  }

  static Importacao _importacao(api.ImportacaoSaida r) {
    final saldo = r.saldoExtrato;
    final fatura = r.fatura;
    final conta = r.conta;
    return Importacao(
      id: r.id,
      criadoEm: r.criadoEm.toLocal(),
      nomeArquivo: r.nomeArquivo,
      contaId: conta?.id,
      contaNome: conta?.nome,
      contaTipo: conta == null
          ? null
          : TipoConta.values.byName(conta.tipo.name),
      periodoInicio: r.periodoInicio?.toDateTime(),
      periodoFim: r.periodoFim?.toDateTime(),
      qtdNovas: r.qtdNovas,
      qtdPossiveisDuplicatas: r.qtdPossiveisDuplicatas,
      qtdJaImportadas: r.qtdJaImportadas,
      qtdParcelas: r.qtdParcelas,
      qtdConfirmadas: r.qtdConfirmadas,
      qtdPendentes: r.qtdPendentes,
      podeDesfazer: r.podeDesfazer,
      saldoExtrato: saldo == null
          ? null
          : SaldoExtrato(
              valor: Decimal.parse(saldo.valor),
              data: saldo.data.toDateTime(),
            ),
      fatura: fatura == null
          ? null
          : FaturaImportada(
              competencia: fatura.competencia.toDateTime(),
              valorInformado: fatura.valorInformado == null
                  ? null
                  : Decimal.parse(fatura.valorInformado!),
              dataFechamento: fatura.dataFechamento.toDateTime(),
            ),
    );
  }
}
