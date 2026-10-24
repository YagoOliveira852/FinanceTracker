import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../data/conta.dart';
import '../data/contas_repositorio.dart';
import 'validacao_cartao.dart';

part 'editar_cartao_cubit.freezed.dart';

@freezed
abstract class EditarCartaoEstado with _$EditarCartaoEstado {
  const factory EditarCartaoEstado({
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes da API (os mesmos do cadastro).
    @Default({}) Map<String, String> erros,
    String? erroGeral,

    /// Preenchida quando salvou: a tela fecha.
    Conta? salva,
  }) = _EditarCartaoEstado;
}

/// Editar cartão: os dados do cadastro e desativar/reativar.
class EditarCartaoCubit extends Cubit<EditarCartaoEstado> {
  EditarCartaoCubit(this._contas, this._conta)
    : super(const EditarCartaoEstado());

  final ContasRepositorio _contas;

  /// O cartão como está, antes da edição.
  final Conta _conta;

  static const _camposDoFormulario = {
    'nome',
    'instituicao',
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

  Future<void> salvar({
    required String nome,
    required String instituicao,
    required String? contaPagamentoId,
    required String diaFechamento,
    required String diaVencimento,
    required String limite,
  }) async {
    final erros = validarCartao(
      nome: nome,
      instituicao: instituicao,
      contaPagamentoId: contaPagamentoId,
      diaFechamento: diaFechamento,
      diaVencimento: diaVencimento,
      limite: limite,
    );
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }
    await _enviar(
      EdicaoCartao(
        nome: nome.trim(),
        instituicao: instituicao.trim(),
        contaPagamentoId: contaPagamentoId!,
        diaFechamento: lerDiaDoMes(diaFechamento)!,
        diaVencimento: lerDiaDoMes(diaVencimento)!,
        limite: lerDinheiro(limite),
        ativa: _conta.ativa,
      ),
    );
  }

  /// Desativa ([ativa] falso) ou reativa o cartão, com os dados atuais dele.
  Future<void> mudarAtivo(bool ativa) {
    final cartao = _conta.cartao!;
    return _enviar(
      EdicaoCartao(
        nome: _conta.nome,
        instituicao: _conta.instituicao ?? '',
        contaPagamentoId: cartao.contaPagamentoId,
        diaFechamento: cartao.diaFechamento,
        diaVencimento: cartao.diaVencimento,
        limite: cartao.limite,
        ativa: ativa,
      ),
    );
  }

  Future<void> _enviar(EdicaoCartao dados) async {
    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final conta = await _contas.editarCartao(_conta.id, dados);
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
