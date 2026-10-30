import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/planejamento.dart';
import '../data/planejamento_repositorio.dart';

part 'planejamento_cubit.freezed.dart';

@freezed
sealed class PlanejamentoEstado with _$PlanejamentoEstado {
  const factory PlanejamentoEstado.carregando() = PlanejamentoCarregando;
  const factory PlanejamentoEstado.carregado({
    required List<Renda> rendas,
    required LeituraConfiguracao leitura,
  }) = PlanejamentoCarregado;
  const factory PlanejamentoEstado.erro(String mensagem) = PlanejamentoErro;
}

/// Tela Planejamento: rendas previstas e a configuração do cálculo, que
/// chegam juntas (a primeira vez depende das duas).
class PlanejamentoCubit extends Cubit<PlanejamentoEstado> {
  PlanejamentoCubit(this._planejamento)
    : super(const PlanejamentoEstado.carregando());

  final PlanejamentoRepositorio _planejamento;

  /// Só a resposta da carga mais recente vale.
  var _versao = 0;

  Future<void> carregar() async {
    final versao = ++_versao;
    emit(const PlanejamentoEstado.carregando());
    late List<Renda> rendas;
    late LeituraConfiguracao leitura;
    try {
      // As duas em paralelo; o primeiro erro interrompe a espera.
      await Future.wait([
        _planejamento.listarRendas().then((r) => rendas = r),
        _planejamento.lerConfiguracao().then((l) => leitura = l),
      ]);
      if (isClosed || versao != _versao) return;
      emit(PlanejamentoEstado.carregado(rendas: rendas, leitura: leitura));
    } on ErroApi catch (erro) {
      if (isClosed || versao != _versao) return;
      emit(PlanejamentoEstado.erro(erro.mensagem));
    }
  }
}
