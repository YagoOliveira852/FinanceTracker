import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/categoria.dart';
import '../data/categorias_repositorio.dart';

part 'editar_categoria_cubit.freezed.dart';

@freezed
abstract class EditarCategoriaEstado with _$EditarCategoriaEstado {
  const factory EditarCategoriaEstado({
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes da API: `nome`, `grupo`.
    @Default({}) Map<String, String> erros,
    String? erroGeral,

    /// Preenchida quando salvou: a tela fecha.
    Categoria? salva,
  }) = _EditarCategoriaEstado;
}

/// Nova categoria ([existente] nula) ou Editar categoria: nome, grupo e
/// desativar/reativar.
class EditarCategoriaCubit extends Cubit<EditarCategoriaEstado> {
  EditarCategoriaCubit(this._categorias, {this.existente})
    : super(const EditarCategoriaEstado());

  final CategoriasRepositorio _categorias;
  final Categoria? existente;

  static const _camposDoFormulario = {'nome', 'grupo'};

  /// O usuário mexeu no campo: o erro dele some até o próximo envio.
  void limparErro(String campo) {
    if (!state.erros.containsKey(campo)) return;
    emit(state.copyWith(erros: {...state.erros}..remove(campo)));
  }

  Future<void> salvar({
    required String nome,
    required GrupoCategoria? grupo,
  }) async {
    final erros = <String, String>{
      if (nome.trim().isEmpty) 'nome': 'Dê um nome, por exemplo: Pets.',
      if (grupo == null) 'grupo': 'Escolha o grupo.',
    };
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }
    await _enviar(
      DadosCategoria(
        nome: nome.trim(),
        grupo: grupo!,
        ativa: existente?.ativa ?? true,
      ),
    );
  }

  /// Desativa ([ativa] falso) ou reativa a categoria, com o nome e o grupo
  /// que ela tem.
  Future<void> mudarAtivo(bool ativa) {
    final categoria = existente!;
    return _enviar(
      DadosCategoria(
        nome: categoria.nome,
        grupo: categoria.grupo,
        ativa: ativa,
      ),
    );
  }

  Future<void> _enviar(DadosCategoria dados) async {
    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final categoria = switch (existente) {
        final c? => await _categorias.editar(c.id, dados),
        null => await _categorias.criar(dados),
      };
      if (isClosed) return;
      emit(state.copyWith(enviando: false, salva: categoria));
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
