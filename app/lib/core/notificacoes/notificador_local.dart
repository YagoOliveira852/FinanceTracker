import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz_dados;
import 'package:timezone/timezone.dart' as tz;

import 'notificador.dart';

/// [Notificador] com o `flutter_local_notifications`, que agenda pelo
/// `AlarmManager` do Android e refaz os agendamentos depois de reiniciar o
/// aparelho (receivers no `AndroidManifest.xml`).
class NotificadorLocal implements Notificador {
  /// O fuso de negócio (`TZ_NEGOCIO` da API), não o do aparelho.
  static const fuso = 'America/Fortaleza';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _toques = StreamController<void>.broadcast();
  late final tz.Location _local;

  /// Ícone monocromático em `res/drawable` (o Android pinta só pelo alfa).
  static const _icone = 'ic_notificacao';

  @override
  Future<void> iniciar() async {
    // A base dos últimos 10 anos basta para agendar daqui para a frente.
    tz_dados.initializeTimeZones();
    _local = tz.getLocation(fuso);
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icone),
      ),
      // Só com o app aberto; fechado, o toque abre o app na rota inicial.
      onDidReceiveNotificationResponse: (_) => _toques.add(null),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  DateTime agora() {
    final agora = tz.TZDateTime.now(_local);
    return DateTime(
      agora.year,
      agora.month,
      agora.day,
      agora.hour,
      agora.minute,
      agora.second,
    );
  }

  @override
  Stream<void> get toques => _toques.stream;

  @override
  Future<bool> pedirPermissao() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> substituirAgendados(List<Lembrete> lembretes) async {
    await _plugin.cancelAllPendingNotifications();
    for (final lembrete in lembretes) {
      final quando = lembrete.quando;
      await _plugin.zonedSchedule(
        id: lembrete.id,
        title: lembrete.titulo,
        body: lembrete.corpo,
        scheduledDate: tz.TZDateTime(
          _local,
          quando.year,
          quando.month,
          quando.day,
          quando.hour,
          quando.minute,
        ),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'lembrete_salario',
            'Lembretes de salário',
            channelDescription:
                'Aviso nos dias de salário para ver o aporte e o alerta.',
            icon: _icone,
            // O corpo inteiro, sem cortar em uma linha.
            styleInformation: BigTextStyleInformation(lembrete.corpo),
          ),
        ),
        // Inexato: pode atrasar alguns minutos, mas dispensa a permissão de
        // alarme exato, que o usuário teria de conceder nas configurações.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelarTodos() => _plugin.cancelAll();
}
