import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/categorias_repositorio.dart';
import '../data/regra.dart';

part 'editar_regra_cubit.freezed.dart';

@freezed
abstract class EditarRegraEstado with _$EditarRegraEstado {
  const factory EditarRegraEstado({
    /// A regra salva e os rascunhos que ela sugere agora; nulo numa regra
    /// nova ou enquanto carrega.
    RegraDetalhe? detalhe,

    /// Falha ao carregar o [detalhe]; o formulário continua usável.
    String? erroDetalhe,
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes da API: `padrao`, `categoria_id`,
    /// `conta_id`.
    @Default({}) Map<String, String> erros,
    String? erroGeral,

    /// Preenchida quando salvou: a tela fecha e a lista avisa quantos
    /// rascunhos a regra sugere.
    RegraDetalhe? salva,
    @Default(false) bool excluida,
  }) = _EditarRegraEstado;
}

/// Nova regra ([existente] nula) ou Editar regra. Salvar sempre grava uma
/// regra manual.
class EditarRegraCubit extends Cubit<EditarRegraEstado> {
  EditarRegraCubit(this._categorias, {this.existente})
    : super(const EditarRegraEstado());

  final CategoriasRepositorio _categorias;
  final Regra? existente;

  static const _camposDoFormulario = {'padrao', 'categoria_id', 'conta_id'};

  /// Quantos rascunhos a regra sugere agora (só numa regra existente).
  Future<void> carregar() async {
    final regra = existente;
    if (regra == null) return;
    try {
      final detalhe = await _categorias.obterRegra(regra.id);
      if (isClosed) return;
      emit(state.copyWith(detalhe: detalhe, erroDetalhe: null));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(state.copyWith(erroDetalhe: erro.mensagem));
    }
  }

  /// O usuário mexeu no campo: o erro dele some até o próximo envio.
  void limparErro(String campo) {
    if (!state.erros.containsKey(campo)) return;
    emit(state.copyWith(erros: {...state.erros}..remove(campo)));
  }

  Future<void> salvar({
    required String padrao,
    required String? categoriaId,
    required String? contaId,
  }) async {
    final erros = <String, String>{
      if (padrao.trim().isEmpty)
        'padrao': 'Escreva o que procurar, por exemplo: padaria.',
      if (categoriaId == null) 'categoria_id': 'Escolha a categoria.',
    };
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }
    final dados = DadosRegra(
      padrao: padrao.trim(),
      categoriaId: categoriaId!,
      contaId: contaId,
    );
    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final detalhe = switch (existente) {
        final r? => await _categorias.editarRegra(r.id, dados),
        null => await _categorias.criarRegra(dados),
      };
      if (isClosed) return;
      emit(state.copyWith(enviando: false, salva: detalhe));
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

  Future<void> excluir() async {
    emit(state.copyWith(enviando: true, erroGeral: null));
    try {
      await _categorias.excluirRegra(existente!.id);
      if (isClosed) return;
      emit(state.copyWith(enviando: false, excluida: true));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(state.copyWith(enviando: false, erroGeral: erro.mensagem));
    }
  }
}
