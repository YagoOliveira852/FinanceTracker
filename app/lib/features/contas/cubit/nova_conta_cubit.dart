import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/conta.dart';
import '../data/contas_repositorio.dart';

part 'nova_conta_cubit.freezed.dart';

@freezed
abstract class NovaContaEstado with _$NovaContaEstado {
  const factory NovaContaEstado({
    @Default(TipoConta.corrente) TipoConta tipo,
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes da API: `nome`, `instituicao`,
    /// `saldo_inicial`, `data_saldo_inicial`.
    @Default({}) Map<String, String> erros,

    /// Erro que não é de um campo (sem rede, erro no servidor).
    String? erroGeral,

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

  static const _camposDoFormulario = {
    'nome',
    'instituicao',
    'saldo_inicial',
    'data_saldo_inicial',
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
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }

    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final conta = await _contas.criar(
        NovaConta(
          nome: nome.trim(),
          tipo: state.tipo,
          instituicao: carteira ? null : instituicao.trim(),
          saldoInicial: lerDinheiro(saldoInicial)!,
          dataSaldoInicial: somenteData(dataSaldoInicial),
        ),
      );
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
}
