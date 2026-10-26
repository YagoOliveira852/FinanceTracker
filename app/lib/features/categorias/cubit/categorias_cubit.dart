import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/categoria.dart';
import '../data/categorias_repositorio.dart';

part 'categorias_cubit.freezed.dart';

@freezed
sealed class CategoriasEstado with _$CategoriasEstado {
  const factory CategoriasEstado.carregando() = CategoriasCarregando;
  const factory CategoriasEstado.carregado(List<Categoria> categorias) =
      CategoriasCarregado;
  const factory CategoriasEstado.erro(String mensagem) = CategoriasErro;
}

/// Todas as categorias (tela Categorias e opções do Lançamento). Fica no topo
/// do app, como o `ContasCubit`: editar uma categoria muda as opções do
/// Lançamento sem outra carga.
class CategoriasCubit extends Cubit<CategoriasEstado> {
  CategoriasCubit(this._categorias)
    : super(const CategoriasEstado.carregando());

  final CategoriasRepositorio _categorias;

  /// Só a resposta da carga mais recente vale.
  var _versao = 0;

  Future<void> carregar() async {
    final versao = ++_versao;
    emit(const CategoriasEstado.carregando());
    try {
      final categorias = await _categorias.listar();
      if (isClosed || versao != _versao) return;
      emit(CategoriasEstado.carregado(categorias));
    } on ErroApi catch (erro) {
      if (isClosed || versao != _versao) return;
      emit(CategoriasEstado.erro(erro.mensagem));
    }
  }
}
