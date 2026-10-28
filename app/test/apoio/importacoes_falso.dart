import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/importacao/data/arquivos.dart';
import 'package:financas/features/importacao/data/importacao.dart';
import 'package:financas/features/importacao/data/importacoes_repositorio.dart';

/// Um OFX mínimo e fictício: só a marca que o app lê para sugerir a conta.
Uint8List ofxFicticio({bool fatura = false}) => Uint8List.fromList(
  utf8.encode(
    'OFXHEADER:100\n<OFX><${fatura ? 'CREDITCARDMSGSRSV1' : 'BANKMSGSRSV1'}>'
    '</${fatura ? 'CREDITCARDMSGSRSV1' : 'BANKMSGSRSV1'}></OFX>',
  ),
);

ArquivoEscolhido arquivoExemplo({
  String nome = 'extrato-outubro.ofx',
  bool fatura = false,
  bool compartilhado = false,
}) => ArquivoEscolhido(
  nome: nome,
  bytes: ofxFicticio(fatura: fatura),
  compartilhado: compartilhado,
);

Importacao importacaoExemplo({
  String id = 'imp1',
  String nomeArquivo = 'extrato-setembro.ofx',
  String contaId = 'c1',
  String contaNome = 'Conta principal',
  TipoConta contaTipo = TipoConta.corrente,
  DateTime? criadoEm,
  int qtdNovas = 36,
  int qtdPossiveisDuplicatas = 2,
  int qtdJaImportadas = 4,
  int qtdParcelas = 0,
  int qtdConfirmadas = 0,
  int? qtdPendentes,
  SaldoExtrato? saldoExtrato,
  FaturaImportada? fatura,
}) => Importacao(
  id: id,
  criadoEm: criadoEm ?? DateTime(2026, 10, 2, 9),
  nomeArquivo: nomeArquivo,
  contaId: contaId,
  contaNome: contaNome,
  contaTipo: contaTipo,
  periodoInicio: DateTime(2026, 10),
  periodoFim: DateTime(2026, 10, 25),
  qtdNovas: qtdNovas,
  qtdPossiveisDuplicatas: qtdPossiveisDuplicatas,
  qtdJaImportadas: qtdJaImportadas,
  qtdParcelas: qtdParcelas,
  qtdConfirmadas: qtdConfirmadas,
  qtdPendentes:
      qtdPendentes ?? qtdNovas + qtdPossiveisDuplicatas - qtdConfirmadas,
  podeDesfazer: qtdConfirmadas == 0,
  saldoExtrato:
      saldoExtrato ??
      (contaTipo == TipoConta.cartaoCredito
          ? null
          : SaldoExtrato(
              valor: Decimal.parse('2340.15'),
              data: DateTime(2026, 10, 25),
            )),
  fatura: fatura,
);

Importacao importacaoDeFaturaExemplo({String id = 'imp2'}) => importacaoExemplo(
  id: id,
  nomeArquivo: 'fatura-outubro.ofx',
  contaId: 'k1',
  contaNome: 'Cartão Exemplo',
  contaTipo: TipoConta.cartaoCredito,
  criadoEm: DateTime(2026, 10, 6, 9),
  qtdNovas: 21,
  qtdPossiveisDuplicatas: 0,
  qtdJaImportadas: 2,
  qtdParcelas: 3,
  fatura: FaturaImportada(
    competencia: DateTime(2026, 10),
    valorInformado: Decimal.parse('1032.15'),
    dataFechamento: DateTime(2026, 10, 3),
  ),
);

/// Repositório falso: guarda o que foi enviado e responde o que o teste pediu.
class ImportacoesRepositorioFalso implements ImportacoesRepositorio {
  ImportacoesRepositorioFalso({
    List<Importacao>? historico,
    this.resultado,
    this.erroImportar,
    this.erroDesfazer,
  }) : historico = historico ?? [];

  List<Importacao> historico;
  ResultadoImportacao? resultado;
  ErroApi? erroImportar;
  ErroApi? erroDesfazer;
  final enviados = <({String contaId, ArquivoEscolhido arquivo})>[];
  final desfeitas = <String>[];

  /// Segura o envio até o teste completar (para ver o "Processando").
  Completer<void>? segurar;

  @override
  Future<List<Importacao>> listar() async => List.of(historico);

  @override
  Future<Importacao> obter(String id) async =>
      historico.firstWhere((i) => i.id == id);

  @override
  Future<ResultadoImportacao> importar({
    required String contaId,
    required ArquivoEscolhido arquivo,
  }) async {
    enviados.add((contaId: contaId, arquivo: arquivo));
    await segurar?.future;
    if (erroImportar case final erro?) throw erro;
    final r =
        resultado ??
        ResultadoImportacao(
          jaImportada: false,
          importacao: importacaoExemplo(id: 'nova', contaId: contaId),
        );
    if (!r.jaImportada) historico = [r.importacao, ...historico];
    return r;
  }

  @override
  Future<void> desfazer(String id) async {
    if (erroDesfazer case final erro?) throw erro;
    desfeitas.add(id);
    historico = historico.where((i) => i.id != id).toList();
  }
}

class SeletorArquivoFalso implements SeletorArquivo {
  SeletorArquivoFalso([this.arquivo]);

  /// O que o "usuário" escolhe; nulo = fechou o seletor.
  ArquivoEscolhido? arquivo;

  @override
  Future<ArquivoEscolhido?> escolher() async => arquivo;
}

class FonteCompartilhamentoFalsa implements FonteCompartilhamento {
  final controlador = StreamController<ArquivoEscolhido>.broadcast();

  @override
  Stream<ArquivoEscolhido> ouvir() => controlador.stream;
}
