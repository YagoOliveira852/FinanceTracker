import 'package:freezed_annotation/freezed_annotation.dart';

part 'notificador.freezed.dart';

/// Uma notificação agendada para um horário no fuso de negócio
/// (`America/Fortaleza`).
@freezed
abstract class Lembrete with _$Lembrete {
  const factory Lembrete({
    /// Agendar outro lembrete com o mesmo id substitui este.
    required int id,

    /// Data e hora no fuso de negócio (os campos, não um instante UTC).
    required DateTime quando,
    required String titulo,
    required String corpo,
  }) = _Lembrete;
}

/// Notificações locais do aparelho. Interface para os testes trocarem o
/// plugin por um falso.
abstract interface class Notificador {
  /// Prepara o plugin; uma vez, antes da primeira tela.
  Future<void> iniciar();

  /// Agora, no fuso de negócio: decide se um horário de hoje já passou.
  DateTime agora();

  /// Cada toque numa notificação com o app aberto.
  Stream<void> get toques;

  /// Pede a permissão de notificação (Android 13+); `false` se recusada.
  Future<bool> pedirPermissao();

  /// Troca todos os lembretes agendados por [lembretes]. As notificações já
  /// mostradas ficam.
  Future<void> substituirAgendados(List<Lembrete> lembretes);

  /// Cancela os agendados e tira da bandeja as já mostradas.
  Future<void> cancelarTodos();
}
