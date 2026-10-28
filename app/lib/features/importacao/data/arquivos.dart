import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'importacao.dart';

/// De onde vem o arquivo do extrato: o seletor do Android ou o Compartilhar de
/// outro app (banco, e-mail). Interfaces para os testes trocarem por falsos.
abstract interface class SeletorArquivo {
  /// Nulo quando o usuário fecha o seletor sem escolher.
  Future<ArquivoEscolhido?> escolher();
}

abstract interface class FonteCompartilhamento {
  /// Começa a ouvir: cada arquivo recebido pelo Compartilhar, com o app
  /// aberto ou fechado. Chamado uma vez, no topo do app.
  Stream<ArquivoEscolhido> ouvir();
}

/// O seletor do sistema (Storage Access Framework): não pede permissão de
/// armazenamento. Sem filtro por extensão: o Android não conhece o tipo do
/// `.ofx` e esconderia o arquivo.
class SeletorArquivoSistema implements SeletorArquivo {
  @override
  Future<ArquivoEscolhido?> escolher() async {
    final arquivo = await FilePicker.pickFile(dialogTitle: 'Escolher extrato');
    if (arquivo == null) return null;
    return ArquivoEscolhido(
      nome: arquivo.name,
      bytes: await arquivo.readAsBytes(),
    );
  }
}

/// Recebe o `ACTION_SEND` pelo `receive_sharing_intent`, que copia o content
/// URI para um arquivo do cache e entrega o caminho (intent-filter no
/// `AndroidManifest.xml`).
class FonteCompartilhamentoSistema implements FonteCompartilhamento {
  @override
  Stream<ArquivoEscolhido> ouvir() {
    final intent = ReceiveSharingIntent.instance;
    final controlador = StreamController<ArquivoEscolhido>();
    Future<void> receber(List<SharedMediaFile> recebidos) async {
      for (final recebido in recebidos) {
        // OFX compartilhado como `text/plain` vem como texto, mas com o
        // caminho do arquivo copiado; texto solto e link não servem.
        if (recebido.type == SharedMediaType.url) continue;
        final arquivo = File(recebido.path);
        try {
          controlador.add(
            ArquivoEscolhido(
              nome: arquivo.uri.pathSegments.last,
              bytes: await arquivo.readAsBytes(),
              compartilhado: true,
            ),
          );
        } on FileSystemException {
          // Não é um arquivo legível (texto solto): nada a importar.
          continue;
        }
      }
    }

    // App fechado: o arquivo vem na abertura; aberto: pelo stream.
    intent
        .getInitialMedia()
        .then((recebidos) async {
          await receber(recebidos);
          await intent.reset();
        })
        .catchError(controlador.addError);
    final inscricao = intent.getMediaStream().listen(
      receber,
      onError: controlador.addError,
    );
    controlador.onCancel = inscricao.cancel;
    return controlador.stream;
  }
}
