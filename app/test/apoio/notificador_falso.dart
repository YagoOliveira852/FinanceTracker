import 'dart:async';

import 'package:financas/core/notificacoes/notificador.dart';

/// Notificações em memória. [agendados] é o que o Android teria na fila;
/// [tocar] simula o toque numa notificação com o app aberto.
class NotificadorFalso implements Notificador {
  NotificadorFalso({DateTime? agora, this.permite = true})
    : _agora = agora ?? DateTime(2026, 11, 2, 8);

  final DateTime _agora;

  /// A resposta ao pedido de permissão.
  final bool permite;

  var agendados = <Lembrete>[];
  var pedidosDePermissao = 0;
  var cancelamentos = 0;
  final _toques = StreamController<void>.broadcast();

  void tocar() => _toques.add(null);

  @override
  Future<void> iniciar() async {}

  @override
  DateTime agora() => _agora;

  @override
  Stream<void> get toques => _toques.stream;

  @override
  Future<bool> pedirPermissao() async {
    pedidosDePermissao++;
    return permite;
  }

  @override
  Future<void> substituirAgendados(List<Lembrete> lembretes) async =>
      agendados = List.of(lembretes);

  @override
  Future<void> cancelarTodos() async {
    cancelamentos++;
    agendados = [];
  }
}
