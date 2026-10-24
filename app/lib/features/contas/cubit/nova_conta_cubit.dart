import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../faturas/data/fatura.dart';
import '../data/conta.dart';
import '../data/contas_repositorio.dart';

part 'nova_conta_cubit.freezed.dart';

@freezed
abstract class NovaContaEstado with _$NovaContaEstado {
  const factory NovaContaEstado({
    @Default(TipoConta.corrente) TipoConta tipo,
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes da API: `nome`, `instituicao`,
    /// `saldo_inicial`, `data_saldo_inicial` e, no cartão,
    /// `conta_pagamento_id`, `dia_fechamento`, `dia_vencimento`, `limite`.
    @Default({}) Map<String, String> erros,

    /// Erro que não é de um campo (sem rede, erro no servidor).
    String? erroGeral,

    /// Cartão: a fatura em que entraria uma compra feita hoje, para os dias
    /// digitados. Nula enquanto os dias não são válidos.
    DatasFatura? previa,

    /// Preenchida quando a conta foi criada: a tela fecha.
    Conta? salva,
  }) = _NovaContaEstado;
}

/// Formulário Nova conta: valida no aparelho e, depois, mostra o que a API
/// recusar no campo correspondente.
class NovaContaCubit extends Cubit<NovaContaEstado> {
  NovaContaCubit(this._contas, {DateTime Function()? hoje})
    : _hoje = hoje ?? DateTime.now,
      super(const NovaContaEstado());

  final ContasRepositorio _contas;
  final DateTime Function() _hoje;

  /// Conta as consultas de prévia: só a resposta da última vale (o usuário
  /// pode digitar mais rápido do que a API responde).
  var _consultaPrevia = 0;

  static const _camposDoFormulario = {
    'nome',
    'instituicao',
    'saldo_inicial',
    'data_saldo_inicial',
    'conta_pagamento_id',
    'dia_fechamento',
    'dia_vencimento',
    'limite',
  };

  /// O usuário mexeu no campo: o erro dele some até o próximo envio.
  void limparErro(String campo) {
    if (!state.erros.containsKey(campo)) return;
    emit(state.copyWith(erros: {...state.erros}..remove(campo)));
  }

  void escolherTipo(TipoConta tipo) =>
      emit(state.copyWith(tipo: tipo, erros: {}, erroGeral: null));

  Future<void> salvar({
    required String nome,
    required String instituicao,
    required String saldoInicial,
    required DateTime dataSaldoInicial,
  }) async {
    final carteira = state.tipo == TipoConta.carteira;
    final erros = <String, String>{
      if (nome.trim().isEmpty)
        'nome': 'Dê um nome à conta, por exemplo: Conta principal.',
      if (!carteira && instituicao.trim().isEmpty)
        'instituicao': 'Informe a instituição da conta.',
      'saldo_inicial': ?validarDinheiro(saldoInicial, aceitaNegativo: true),
      if (somenteData(dataSaldoInicial).isAfter(somenteData(_hoje())))
        'data_saldo_inicial': 'A data do saldo não pode ser depois de hoje.',
    };
    await _enviar(
      erros,
      () => _contas.criar(
        NovaConta(
          nome: nome.trim(),
          tipo: state.tipo,
          instituicao: carteira ? null : instituicao.trim(),
          saldoInicial: lerDinheiro(saldoInicial)!,
          dataSaldoInicial: somenteData(dataSaldoInicial),
        ),
      ),
    );
  }

  /// Pede a prévia da próxima fatura quando os dois dias são válidos e
  /// diferentes; senão, a prévia some. Falha de rede só deixa sem prévia.
  Future<void> atualizarPrevia(
    String diaFechamento,
    String diaVencimento,
  ) async {
    final consulta = ++_consultaPrevia;
    final fechamento = _lerDia(diaFechamento);
    final vencimento = _lerDia(diaVencimento);
    if (fechamento == null || vencimento == null || fechamento == vencimento) {
      if (state.previa != null) emit(state.copyWith(previa: null));
      return;
    }
    DatasFatura? previa;
    try {
      previa = await _contas.previaFatura(
        diaFechamento: fechamento,
        diaVencimento: vencimento,
      );
    } on ErroApi {
      previa = null;
    }
    if (isClosed || consulta != _consultaPrevia) return;
    emit(state.copyWith(previa: previa));
  }

  Future<void> salvarCartao({
    required String nome,
    required String instituicao,
    required String? contaPagamentoId,
    required String diaFechamento,
    required String diaVencimento,
    required String limite,
  }) async {
    final fechamento = _lerDia(diaFechamento);
    final vencimento = _lerDia(diaVencimento);
    final semLimite = limite.trim().isEmpty;
    final erros = <String, String>{
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
      if (!semLimite) 'limite': ?validarDinheiro(limite, exigePositivo: true),
    };
    await _enviar(
      erros,
      () => _contas.criarCartao(
        NovoCartao(
          nome: nome.trim(),
          instituicao: instituicao.trim(),
          contaPagamentoId: contaPagamentoId!,
          diaFechamento: fechamento!,
          diaVencimento: vencimento!,
          limite: semLimite ? null : lerDinheiro(limite),
        ),
      ),
    );
  }

  /// Mostra os erros locais ou envia; o que a API recusar vai para o campo.
  Future<void> _enviar(
    Map<String, String> erros,
    Future<Conta> Function() criar,
  ) async {
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }

    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final conta = await criar();
      if (isClosed) return;
      emit(state.copyWith(enviando: false, salva: conta));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      final doFormulario = {
        for (final MapEntry(:key, :value) in erro.campos.entries)
          if (_camposDoFormulario.contains(key)) key: value,
      };
      emit(
        state.copyWith(
          enviando: false,
          erros: doFormulario,
          erroGeral: doFormulario.isEmpty ? erro.mensagem : null,
        ),
      );
    }
  }

  static int? _lerDia(String texto) {
    final dia = int.tryParse(texto.trim());
    return dia != null && dia >= 1 && dia <= 31 ? dia : null;
  }
}
