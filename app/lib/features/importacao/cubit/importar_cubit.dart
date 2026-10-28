import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/erro_api.dart';
import '../data/arquivos.dart';
import '../data/importacao.dart';
import '../data/importacoes_repositorio.dart';

part 'importar_cubit.freezed.dart';

/// O mesmo limite da API: um extrato mensal tem ~20 KB.
const tamanhoMaximoArquivo = 5 * 1024 * 1024;

@freezed
abstract class ImportarEstado with _$ImportarEstado {
  const factory ImportarEstado({
    /// Nulo enquanto carrega.
    List<Importacao>? historico,
    String? erroHistorico,
    ArquivoEscolhido? arquivo,
    String? contaId,

    /// A conta veio da última importação do mesmo tipo de arquivo.
    @Default(false) bool contaSugerida,
    @Default(false) bool enviando,

    /// Erro por campo, com os nomes da API: `arquivo` e `conta_id`.
    @Default({}) Map<String, String> erros,

    /// Erro que não é de um campo (sem rede, erro no servidor).
    String? erroGeral,

    /// FITID repetido: as linhas que fizeram o arquivo ser recusado.
    @Default([]) List<LinhaRepetida> linhasRepetidas,

    /// O arquivo já tinha sido importado: a importação anterior (aviso).
    Importacao? jaImportada,

    /// Importação nova: a tela abre o resumo.
    Importacao? importada,
  }) = _ImportarEstado;

  const ImportarEstado._();

  bool get podeImportar => arquivo != null && contaId != null && !enviando;
}

/// Formulário "Importar extrato": arquivo + conta de destino, e o histórico.
///
/// A conta é sugerida pela última importação do mesmo tipo de arquivo (OFX de
/// conta ou de fatura), enquanto o usuário não escolher outra.
class ImportarCubit extends Cubit<ImportarEstado> {
  ImportarCubit(this._importacoes, this._seletor)
    : super(const ImportarEstado());

  final ImportacoesRepositorio _importacoes;
  final SeletorArquivo _seletor;

  Future<void> carregar() async {
    try {
      final historico = await _importacoes.listar();
      if (isClosed) return;
      emit(state.copyWith(historico: historico, erroHistorico: null));
      _sugerirConta();
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(state.copyWith(erroHistorico: erro.mensagem));
    }
  }

  /// Abre o seletor do Android; fechar sem escolher não muda nada.
  Future<void> escolherArquivo() async {
    final arquivo = await _seletor.escolher();
    if (arquivo != null && !isClosed) receberArquivo(arquivo);
  }

  /// Arquivo do seletor ou do Compartilhar: os avisos do anterior somem.
  void receberArquivo(ArquivoEscolhido arquivo) {
    emit(
      state.copyWith(
        arquivo: arquivo,
        erros: {...state.erros}..remove('arquivo'),
        erroGeral: null,
        linhasRepetidas: const [],
        jaImportada: null,
      ),
    );
    _sugerirConta();
  }

  void escolherConta(String contaId) => emit(
    state.copyWith(
      contaId: contaId,
      contaSugerida: false,
      erros: {...state.erros}..remove('conta_id'),
      erroGeral: null,
    ),
  );

  Future<void> importar() async {
    final arquivo = state.arquivo;
    final contaId = state.contaId;
    final erros = <String, String>{
      if (arquivo == null) 'arquivo': 'Escolha o arquivo do extrato.',
      if (arquivo != null && arquivo.bytes.length > tamanhoMaximoArquivo)
        'arquivo': 'O arquivo passa de 5 MB.',
      if (contaId == null) 'conta_id': 'Escolha a conta de destino.',
    };
    if (erros.isNotEmpty) {
      emit(state.copyWith(erros: erros));
      return;
    }

    emit(
      state.copyWith(
        enviando: true,
        erros: {},
        erroGeral: null,
        linhasRepetidas: const [],
        jaImportada: null,
        importada: null,
      ),
    );
    try {
      final resultado = await _importacoes.importar(
        contaId: contaId!,
        arquivo: arquivo!,
      );
      if (isClosed) return;
      emit(
        resultado.jaImportada
            ? state.copyWith(enviando: false, jaImportada: resultado.importacao)
            : state.copyWith(
                enviando: false,
                importada: resultado.importacao,
                arquivo: null,
              ),
      );
      if (!resultado.jaImportada) await carregar();
    } on ErroFitidRepetido catch (erro) {
      if (isClosed) return;
      emit(state.copyWith(enviando: false, linhasRepetidas: erro.linhas));
    } on ErroApi catch (erro) {
      if (isClosed) return;
      emit(
        state.copyWith(
          enviando: false,
          erros: erro.campos,
          erroGeral: erro.campos.isEmpty ? erro.mensagem : null,
        ),
      );
    }
  }

  /// A tela já abriu o resumo da importação nova.
  void resumoAberto() => emit(state.copyWith(importada: null));

  void _sugerirConta() {
    final arquivo = state.arquivo;
    final historico = state.historico;
    if (arquivo == null || historico == null) return;
    if (state.contaId != null && !state.contaSugerida) return;
    final tipo = arquivo.tipo;
    final ultima = historico
        .where((i) => i.contaId != null && i.tipoArquivo == tipo)
        .firstOrNull;
    emit(
      state.copyWith(contaId: ultima?.contaId, contaSugerida: ultima != null),
    );
  }
}
