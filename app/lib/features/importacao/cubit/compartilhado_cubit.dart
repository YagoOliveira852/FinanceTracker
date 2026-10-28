import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/arquivos.dart';
import '../data/importacao.dart';

/// Guarda o arquivo recebido pelo Compartilhar até a tela de importação
/// abrir. Fica no topo do app: o arquivo pode chegar com o app fechado,
/// antes do login (sessão expirada), e só é entregue com a sessão conectada.
class CompartilhadoCubit extends Cubit<ArquivoEscolhido?> {
  CompartilhadoCubit(FonteCompartilhamento fonte) : super(null) {
    // Um erro do plugin só perde aquele compartilhamento: fica registrado e
    // o app segue.
    _inscricao = fonte.ouvir().listen(
      emit,
      onError: (Object erro, StackTrace pilha) => FlutterError.reportError(
        FlutterErrorDetails(
          exception: erro,
          stack: pilha,
          library: 'importacao',
          context: ErrorDescription('ao receber um arquivo do Compartilhar'),
        ),
      ),
    );
  }

  late final StreamSubscription<ArquivoEscolhido> _inscricao;

  /// Entrega o arquivo pendente (uma vez só) e esvazia.
  ArquivoEscolhido? consumir() {
    final arquivo = state;
    if (arquivo != null) emit(null);
    return arquivo;
  }

  @override
  Future<void> close() async {
    await _inscricao.cancel();
    return super.close();
  }
}
