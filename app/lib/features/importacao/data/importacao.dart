import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../contas/data/conta.dart';

part 'importacao.freezed.dart';

/// Uma importação de extrato e o resumo dela (tela de resumo e histórico).
@freezed
abstract class Importacao with _$Importacao {
  const factory Importacao({
    required String id,
    required DateTime criadoEm,
    String? nomeArquivo,
    @Default(FormatoArquivo.ofx) FormatoArquivo formato,
    String? contaId,
    String? contaNome,
    TipoConta? contaTipo,
    DateTime? periodoInicio,
    DateTime? periodoFim,

    /// Entraram como rascunho (sem as possíveis duplicatas).
    required int qtdNovas,
    required int qtdPossiveisDuplicatas,

    /// Já estavam no app; ficaram de fora.
    required int qtdJaImportadas,

    /// Parcelas, com a data da compra estimada.
    required int qtdParcelas,

    /// Contadas agora: mudam conforme a Revisão confirma.
    required int qtdConfirmadas,
    required int qtdPendentes,
    required bool podeDesfazer,

    /// Saldo final do extrato da conta; nulo na fatura.
    SaldoExtrato? saldoExtrato,

    /// O que a importação gravou na fatura; nulo no extrato da conta.
    FaturaImportada? fatura,
  }) = _Importacao;

  const Importacao._();

  /// O que foi para a Revisão: as novas e as possíveis duplicatas.
  int get qtdRascunhos => qtdNovas + qtdPossiveisDuplicatas;

  /// Tipo do arquivo, para sugerir a conta da próxima importação igual: o
  /// CSV pela fonte; no OFX, a fatura é o que foi para um cartão.
  TipoArquivo get tipoArquivo => switch (formato) {
    FormatoArquivo.csvMercadoPago => TipoArquivo.csvMercadoPago,
    FormatoArquivo.ofx =>
      contaTipo == TipoConta.cartaoCredito
          ? TipoArquivo.ofxFatura
          : TipoArquivo.ofxConta,
  };
}

@freezed
abstract class SaldoExtrato with _$SaldoExtrato {
  const factory SaldoExtrato({required Decimal valor, required DateTime data}) =
      _SaldoExtrato;
}

@freezed
abstract class FaturaImportada with _$FaturaImportada {
  const factory FaturaImportada({
    /// Primeiro dia do mês do vencimento.
    required DateTime competencia,
    Decimal? valorInformado,
    required DateTime dataFechamento,
  }) = _FaturaImportada;
}

/// Resposta do envio: a importação nova ou, se o arquivo já tinha entrado,
/// a anterior ([jaImportada]).
@freezed
abstract class ResultadoImportacao with _$ResultadoImportacao {
  const factory ResultadoImportacao({
    required bool jaImportada,
    required Importacao importacao,
  }) = _ResultadoImportacao;
}

/// Uma das linhas com o mesmo identificador (FITID no OFX, REFERENCE_ID no
/// CSV) que fizeram o arquivo ser recusado.
@freezed
abstract class LinhaRepetida with _$LinhaRepetida {
  const factory LinhaRepetida({
    required String fitid,
    required DateTime data,

    /// Com sinal, como no arquivo: negativo é saída.
    required Decimal valor,
    required String descricao,
  }) = _LinhaRepetida;
}

/// Arquivo escolhido no seletor ou recebido pelo Compartilhar.
@freezed
abstract class ArquivoEscolhido with _$ArquivoEscolhido {
  const factory ArquivoEscolhido({
    required String nome,
    required Uint8List bytes,
    @Default(false) bool compartilhado,
  }) = _ArquivoEscolhido;

  const ArquivoEscolhido._();

  TipoArquivo get tipo => tipoDoArquivo(bytes);
}

/// O formato do arquivo importado (a `fonte` da importação).
enum FormatoArquivo { ofx, csvMercadoPago }

enum TipoArquivo { ofxConta, ofxFatura, csvMercadoPago, outro }

/// Cabeçalho dos lançamentos no CSV do extrato do Mercado Pago.
const cabecalhoCsvMercadoPago =
    'RELEASE_DATE;TRANSACTION_TYPE;REFERENCE_ID;TRANSACTION_NET_AMOUNT;'
    'PARTIAL_BALANCE';

/// Reconhece o arquivo só para sugerir a conta: a fatura do cartão tem a
/// marca `CREDITCARDMSGSRSV1`, e o CSV do Mercado Pago, o cabeçalho dos
/// lançamentos; o servidor valida de novo.
TipoArquivo tipoDoArquivo(Uint8List bytes) {
  // latin1 nunca falha: as marcas são ASCII em qualquer encoding.
  final texto = String.fromCharCodes(bytes).toUpperCase();
  if (texto.contains(cabecalhoCsvMercadoPago)) {
    return TipoArquivo.csvMercadoPago;
  }
  if (!texto.contains('<OFX>')) return TipoArquivo.outro;
  return texto.contains('CREDITCARDMSGSRSV1')
      ? TipoArquivo.ofxFatura
      : TipoArquivo.ofxConta;
}
