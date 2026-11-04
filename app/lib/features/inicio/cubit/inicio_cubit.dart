import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/datas.dart';
import '../../open_finance/data/open_finance.dart';
import '../../open_finance/data/open_finance_repositorio.dart';
import '../../planejamento/data/planejamento_repositorio.dart';
import '../../planejamento/data/resumo.dart';
import '../data/aporte_dispensado.dart';

part 'inicio_cubit.freezed.dart';

@freezed
sealed class InicioEstado with _$InicioEstado {
  const factory InicioEstado.carregando() = InicioCarregando;
  const factory InicioEstado.carregado({
    required Resumo resumo,

    /// O dia da carga: "caiu hoje", "caiu ontem".
    required DateTime hoje,

    /// "Agora não" no salário recebido: o card volta à sobra e ao alerta.
    @Default(false) bool aporteDispensado,

    /// Conexões da Pluggy, para o card de problema (só quando há um). Nula se
    /// a leitura falhou: o Open Finance não derruba o Início.
    ListaConexoes? openFinance,
  }) = InicioCarregado;
  const factory InicioEstado.erro(String mensagem) = InicioErro;
}

/// Início: o resumo do planejamento e a dispensa da sugestão de aporte.
///
/// Fica no topo do app (como o das contas) e recarrega no login, ao voltar
/// para a aba e ao puxar para atualizar. Depois da primeira carga, recarregar
/// não volta a "carregando": a tela continua com o resumo anterior até o
/// novo chegar.
class InicioCubit extends Cubit<InicioEstado> {
  InicioCubit(
    this._planejamento,
    this._dispensado, {
    this.openFinance,
    DateTime Function()? hoje,
  }) : _hoje = hoje ?? DateTime.now,
       super(const InicioEstado.carregando());

  final PlanejamentoRepositorio _planejamento;

  /// Para o card de problema do Open Finance; sem ele, não há card.
  final OpenFinanceRepositorio? openFinance;
  final AporteDispensado _dispensado;
  final DateTime Function() _hoje;

  /// Só a resposta da carga mais recente vale.
  var _versao = 0;

  Future<void> carregar() async {
    final versao = ++_versao;
    if (state is! InicioCarregado) emit(const InicioEstado.carregando());
    try {
      final conexoes = _conexoes();
      final resumo = await _planejamento.lerResumo();
      final openFinance = await conexoes;
      final chave = chaveDoAporte(resumo);
      final dispensado = chave != null && await _dispensado.ler() == chave;
      if (isClosed || versao != _versao) return;
      emit(
        InicioEstado.carregado(
          resumo: resumo,
          hoje: somenteData(_hoje()),
          aporteDispensado: dispensado,
          openFinance: openFinance,
        ),
      );
    } on ErroApi catch (erro) {
      if (isClosed || versao != _versao) return;
      emit(InicioEstado.erro(erro.mensagem));
    }
  }

  Future<ListaConexoes?> _conexoes() async {
    try {
      return await openFinance?.listar();
    } on ErroApi {
      return null;
    }
  }

  /// "Agora não": a sugestão some até o salário seguinte.
  Future<void> dispensarAporte() async {
    final estado = state;
    if (estado is! InicioCarregado) return;
    final chave = chaveDoAporte(estado.resumo);
    if (chave == null) return;
    emit(estado.copyWith(aporteDispensado: true));
    await _dispensado.salvar(chave);
  }
}
