import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/data/conta.dart';
import '../../faturas/data/fatura.dart';
import '../../faturas/data/faturas_repositorio.dart';
import '../data/transacao.dart';
import '../data/transacoes_repositorio.dart';

part 'lancamento_cubit.freezed.dart';

@freezed
abstract class LancamentoEstado with _$LancamentoEstado {
  const factory LancamentoEstado({
    @Default(TipoTransacao.despesa) TipoTransacao tipo,
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes do formulário: `conta_id`, `valor`,
    /// `data`, `parcelas`, `descricao` (os da compra parcelada na API,
    /// `valor_total`, `data_compra` e `qtd_parcelas`, viram os do formulário).
    @Default({}) Map<String, String> erros,
    String? erroGeral,

    /// Compra no cartão: em que fatura ela entra ("Entra na fatura de …").
    /// Nula em conta comum ou enquanto a API não respondeu.
    DatasFatura? faturaDaCompra,

    /// Preenchida quando o lançamento foi salvo (na parcelada, a 1ª
    /// parcela): a tela fecha.
    Transacao? salva,
  }) = _LancamentoEstado;
}

/// Formulário de lançamento manual (despesa ou receita; no cartão, compra).
class LancamentoCubit extends Cubit<LancamentoEstado> {
  LancamentoCubit(this._transacoes, this._faturas)
    : super(const LancamentoEstado());

  final TransacoesRepositorio _transacoes;
  final FaturasRepositorio _faturas;

  /// Conta e data da última consulta de fatura: a tela pede de novo a cada
  /// quadro, e só uma mudança de verdade chama a API.
  ({String? contaId, DateTime data})? _consultada;

  /// Campo da API → campo do formulário.
  static const _camposDoFormulario = {
    'conta_id': 'conta_id',
    'valor': 'valor',
    'valor_total': 'valor',
    'data': 'data',
    'data_compra': 'data',
    'qtd_parcelas': 'parcelas',
    'descricao': 'descricao',
  };

  /// O usuário mexeu no campo: o erro dele some até o próximo envio.
  void limparErro(String campo) {
    if (!state.erros.containsKey(campo)) return;
    emit(state.copyWith(erros: {...state.erros}..remove(campo)));
  }

  /// Despesa, receita ou um dos formulários próprios: transferência
  /// (`transferenciaSaida`) e pagamento de fatura (`pagamentoFatura`). Só
  /// despesa e receita são salvas por este cubit.
  void escolherTipo(TipoTransacao tipo) {
    assert(_tiposDoLancamento.contains(tipo));
    emit(state.copyWith(tipo: tipo));
  }

  static const _tiposDoLancamento = {
    TipoTransacao.despesa,
    TipoTransacao.receita,
    TipoTransacao.transferenciaSaida,
    TipoTransacao.pagamentoFatura,
  };

  /// Atualiza "Entra na fatura de …" para a conta e a data escolhidas. Conta
  /// que não é cartão (ou nenhuma) limpa a fatura sem chamar a API; erro da
  /// API só deixa sem a informação.
  Future<void> consultarFatura(Conta? conta, DateTime data) async {
    final cartao = conta?.tipo == TipoConta.cartaoCredito ? conta : null;
    final chave = (contaId: cartao?.id, data: somenteData(data));
    if (chave == _consultada) return;
    _consultada = chave;
    if (cartao == null) {
      if (state.faturaDaCompra != null) {
        emit(state.copyWith(faturaDaCompra: null));
      }
      return;
    }
    DatasFatura? fatura;
    try {
      fatura = await _faturas.paraCompra(cartao.id, chave.data);
    } on ErroApi {
      fatura = null;
    }
    if (isClosed || chave != _consultada) return;
    emit(state.copyWith(faturaDaCompra: fatura));
  }

  Future<void> salvar({
    required String? contaId,
    required String valor,
    required DateTime data,
    required String descricao,

    /// 2 ou mais: compra parcelada (só em cartão, a tela garante).
    int parcelas = 1,
  }) async {
    final erros = <String, String>{
      if (contaId == null) 'conta_id': 'Escolha uma conta.',
      'valor': ?validarDinheiro(valor, exigePositivo: true),
      if (descricao.trim().isEmpty)
        'descricao': 'Descreva a transação, por exemplo: Mercado.',
    };
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros, erroGeral: null));
      return;
    }

    emit(state.copyWith(enviando: true, erros: {}, erroGeral: null));
    try {
      final transacao = parcelas > 1
          ? (await _transacoes.lancarParcelada(
              NovaCompraParcelada(
                contaId: contaId!,
                valorTotal: lerDinheiro(valor)!,
                qtdParcelas: parcelas,
                dataCompra: somenteData(data),
                descricao: descricao.trim(),
              ),
            )).first
          : await _transacoes.lancar(
              NovoLancamento(
                contaId: contaId!,
                tipo: state.tipo,
                valor: lerDinheiro(valor)!,
                data: somenteData(data),
                descricao: descricao.trim(),
              ),
            );
      if (isClosed) return;
      emit(state.copyWith(enviando: false, salva: transacao));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      final doFormulario = {
        for (final MapEntry(:key, :value) in erro.campos.entries)
          ?_camposDoFormulario[key]: value,
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
