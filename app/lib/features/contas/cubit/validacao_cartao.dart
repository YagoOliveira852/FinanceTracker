import '../../../core/formatacao/dinheiro.dart';

/// Dia de fechamento ou vencimento digitado: 1 a 31, ou nulo.
int? lerDiaDoMes(String texto) {
  final dia = int.tryParse(texto.trim());
  return dia != null && dia >= 1 && dia <= 31 ? dia : null;
}

/// Erros do formulário de cartão (Nova conta e Editar cartão), com os nomes
/// de campo da API. Vazio quando tudo vale.
Map<String, String> validarCartao({
  required String nome,
  required String instituicao,
  required String? contaPagamentoId,
  required String diaFechamento,
  required String diaVencimento,
  required String limite,
}) {
  final fechamento = lerDiaDoMes(diaFechamento);
  final vencimento = lerDiaDoMes(diaVencimento);
  return {
    if (nome.trim().isEmpty)
      'nome': 'Dê um nome ao cartão, por exemplo: Cartão principal.',
    if (instituicao.trim().isEmpty)
      'instituicao': 'Informe a instituição do cartão.',
    if (contaPagamentoId == null)
      'conta_pagamento_id': 'Escolha a conta que paga a fatura.',
    if (fechamento == null) 'dia_fechamento': 'Informe um dia de 1 a 31.',
    if (vencimento == null)
      'dia_vencimento': 'Informe um dia de 1 a 31.'
    else if (vencimento == fechamento)
      'dia_vencimento':
          'O vencimento precisa ser num dia diferente do fechamento.',
    if (limite.trim().isNotEmpty)
      'limite': ?validarDinheiro(limite, exigePositivo: true),
  };
}
