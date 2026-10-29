import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/importacao.dart';

/// Textos da importação que dependem de números (singular e plural).
String plural(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';

/// `OFX · 18 KB`.
String descricaoDoArquivo(ArquivoEscolhido arquivo) {
  final extensao = arquivo.nome.contains('.')
      ? arquivo.nome.split('.').last.toUpperCase()
      : 'Arquivo';
  final kb = (arquivo.bytes.length / 1024).ceil();
  return '$extensao · $kb KB';
}

/// `1 a 25 de outubro`, ou `4 set a 3 out` quando cruza o mês.
String formatarPeriodo(DateTime inicio, DateTime fim) {
  if (inicio.year == fim.year && inicio.month == fim.month) {
    return '${inicio.day} a ${fim.day} de ${nomeDoMes(fim)}';
  }
  return '${formatarDiaMes(inicio)} a ${formatarDiaMes(fim)}';
}

/// `Conta principal · 6 out`: subtítulo de um item do histórico.
String subtituloDoHistorico(Importacao importacao) =>
    [?importacao.contaNome, formatarDiaMes(importacao.criadoEm)].join(' · ');

/// Ajuda abaixo da conta de destino.
String? ajudaDaConta({
  required ArquivoEscolhido? arquivo,
  required bool contaSugerida,
}) {
  if (arquivo == null) {
    return 'Depois de escolher o arquivo, o app sugere a conta.';
  }
  if (!contaSugerida) return null;
  return switch (arquivo.tipo) {
    TipoArquivo.ofxFatura => 'O mesmo da última importação de OFX de fatura.',
    TipoArquivo.csvMercadoPago =>
      'A mesma da última importação de CSV do Mercado Pago.',
    TipoArquivo.ofxConta ||
    TipoArquivo.outro => 'A mesma da última importação de OFX de conta.',
  };
}

String avisoJaImportada(Importacao anterior) =>
    'Este arquivo já foi importado em ${formatarDiaMes(anterior.criadoEm)}'
    '${anterior.contaNome == null ? '' : ', na ${anterior.contaNome}'}, '
    'com ${plural(anterior.qtdNovas, 'nova', 'novas')}. Nada mudou. '
    'Se foi na conta errada, desfaça aquela importação e importe de novo.';

String avisoFitidRepetido(int linhas) =>
    'Nada foi importado. O arquivo tem $linhas lançamentos com o mesmo '
    'identificador, e o app não escolhe sozinho qual descartar.';

/// `7c1e…a42f`: o identificador inteiro (FITID ou REFERENCE_ID) não cabe na
/// linha.
String fitidCurto(String fitid) => fitid.length <= 12
    ? fitid
    : '${fitid.substring(0, 4)}…${fitid.substring(fitid.length - 4)}';

String valorDaLinha(LinhaRepetida linha) =>
    formatarDinheiroComSinal(linha.valor.abs(), entrada: linha.valor.sign > 0);

String subtituloDasNovas(Importacao importacao) => importacao.qtdConfirmadas > 0
    ? '${plural(importacao.qtdConfirmadas, 'já confirmada', 'já confirmadas')}, '
          '${importacao.qtdPendentes} ainda na Revisão'
    : 'Entraram como rascunho, com a categoria sugerida quando alguma regra casa';

String tituloDaImportacao(Importacao importacao) =>
    'Importação de ${formatarDiaMes(importacao.criadoEm)}';

String textoDoDesfazer(Importacao importacao) {
  final arquivo = importacao.nomeArquivo ?? 'este arquivo';
  final rascunhos = plural(importacao.qtdRascunhos, 'rascunho', 'rascunhos');
  final extra = importacao.fatura != null
      ? ' e a fatura volta ao valor e ao fechamento de antes'
      : importacao.saldoExtrato != null
      ? ' e o saldo do extrato deixa de ser guardado'
      : '';
  return 'Os $rascunhos de $arquivo saem da Revisão$extra. '
      'O arquivo fica livre para importar de novo, na conta certa.';
}

String avisoSemDesfazer(Importacao importacao) =>
    'Não dá mais para desfazer: '
    '${plural(importacao.qtdConfirmadas, 'transação desta importação já foi confirmada', 'transações desta importação já foram confirmadas')}.';

/// Sem desfazer, o botão leva às pendentes desta importação.
String rotuloIrParaRevisao(Importacao importacao) {
  final pendentes = importacao.qtdPendentes;
  if (importacao.podeDesfazer || pendentes == 0) return 'Ir para a Revisão';
  return pendentes == 1
      ? 'Revisar a pendente'
      : 'Revisar as $pendentes pendentes';
}
