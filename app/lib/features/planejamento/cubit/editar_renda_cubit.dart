import 'package:decimal/decimal.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/cubit/validacao_cartao.dart';
import '../data/planejamento.dart';
import '../data/planejamento_repositorio.dart';

part 'editar_renda_cubit.freezed.dart';

@freezed
abstract class EditarRendaEstado with _$EditarRendaEstado {
  const factory EditarRendaEstado({
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes da API.
    @Default({}) Map<String, String> erros,
    String? erroGeral,

    /// "Próxima data" do dia digitado; nula enquanto o dia não vale.
    ProximaData? previa,

    /// Preenchida quando salvou: a tela fecha.
    Renda? salva,
  }) = _EditarRendaEstado;
}

/// Nova renda e Editar renda (com desativar e reativar pelo [salvar]).
class EditarRendaCubit extends Cubit<EditarRendaEstado> {
  EditarRendaCubit(this._planejamento, {Renda? existente})
    : _existente = existente,
      super(EditarRendaEstado(previa: existente?.proxima));

  final PlanejamentoRepositorio _planejamento;

  /// A renda como está, na edição; nula na Nova renda.
  final Renda? _existente;

  static const _camposDoFormulario = {
    'descricao',
    'valor',
    'dia_previsto',
    'conta_id',
  };

  /// Só a resposta da prévia mais recente vale.
  var _consultaPrevia = 0;

  /// O usuário mexeu no campo: o erro dele some até o próximo envio.
  void limparErro(String campo) {
    if (!state.erros.containsKey(campo)) return;
    emit(state.copyWith(erros: {...state.erros}..remove(campo)));
  }

  /// Busca a próxima data do dia digitado (fim de semana, feriado e mês
  /// curto vêm da API).
  Future<void> atualizarPrevia(String dia) async {
    final consulta = ++_consultaPrevia;
    final lido = lerDiaDoMes(dia);
    if (lido == null) {
      if (state.previa != null) emit(state.copyWith(previa: null));
      return;
    }
    ProximaData? previa;
    try {
      previa = await _planejamento.previaRenda(lido);
    } on ErroApi {
      // Sem a prévia o formulário continua valendo.
      previa = null;
    }
    if (isClosed || consulta != _consultaPrevia) return;
    emit(state.copyWith(previa: previa));
  }

  Future<void> salvar({
    required String descricao,
    required String valor,
    required String dia,
    required String? contaId,
    required bool ativa,
  }) async {
    final erros = _validar(descricao, valor, dia, contaId);
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }
    final dados = DadosRenda(
      descricao: descricao.trim(),
      valor: lerDinheiro(valor)!,
      diaPrevisto: lerDiaDoMes(dia)!,
      contaId: contaId!,
      ativa: ativa,
    );
    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final existente = _existente;
      final renda = existente == null
          ? await _planejamento.criarRenda(dados)
          : await _planejamento.editarRenda(existente.id, dados);
      if (isClosed) return;
      emit(state.copyWith(enviando: false, salva: renda));
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

  static Map<String, String> _validar(
    String descricao,
    String valor,
    String dia,
    String? contaId,
  ) {
    final lido = lerDinheiro(valor);
    return {
      if (descricao.trim().isEmpty)
        'descricao': 'Dê um nome à renda, por exemplo: Salário.',
      if (valor.trim().isEmpty || (lido != null && lido <= Decimal.zero))
        'valor': 'O valor precisa ser maior que zero.'
      else
        'valor': ?validarDinheiro(valor, exigePositivo: true),
      if (lerDiaDoMes(dia) == null) 'dia_previsto': 'Use um dia de 1 a 31.',
      if (contaId == null)
        'conta_id': 'Escolha a conta corrente ou a carteira onde a renda cai.',
    };
  }
}
