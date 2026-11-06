import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/agenda_item.dart';
import '../models/escala_item.dart';
class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: android);
    
    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Lógica ao clicar na notificação
      },
    );

    // Solicitar permissão de notificação (Android 13+)
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> agendarNotificacoesAgenda(List<AgendaItem> itens) async {
    debugPrint('🔔 Notificações: Agendando agenda (${itens.length} itens)...');
    
    // Para simplificar e garantir que não haja duplicidade, limpamos tudo antes de reagendar.
    // Em um cenário real, poderíamos ser mais seletivos.
    await _notifications.cancelAll(); 

    for (var item in itens) {
      // Agendamos as próximas 3 ocorrências de cada item recorrente
      final proximas = item.calcularProximasDatas(3);
      
      for (int i = 0; i < proximas.length; i++) {
        final data = proximas[i];
        // Geramos um ID único baseado no hash do ID da String e na ocorrência
        final baseId = item.id.hashCode.abs() + (i * 1000);
        
        final hParts = item.horario.split(':');
        final dataHoraComHorario = DateTime(
          data.year,
          data.month,
          data.day,
          int.parse(hParts[0]),
          int.parse(hParts[1]),
        );

        // Alerta às 08:00 do dia
        await agendarAlertaMatinal(
          id: baseId,
          titulo: 'Hoje tem: ${item.titulo}',
          corpo: 'Às ${item.horario} na igreja.',
          dataHora: dataHoraComHorario,
        );

        // Alerta 1 hora antes
        await agendarAlertaUmaHoraAntes(
          id: baseId + 5000,
          titulo: 'Lembrete: ${item.titulo}',
          corpo: 'O evento "${item.titulo}" começa em 1 hora.',
          dataHora: dataHoraComHorario,
        );
      }
    }
  }

  static Future<void> agendarNotificacoesEscala(List<EscalaItem> escalas) async {
    debugPrint('🔔 Notificações: Agendando escalas (${escalas.length} itens)...');
    
    for (var item in escalas) {
      final parts = item.data.split('-');
      if (parts.length != 3) continue;

      final hParts = item.horario.split(':');
      if (hParts.length != 2) continue;

      final dataHora = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        int.parse(hParts[0]),
        int.parse(hParts[1]),
      );

      // Não agendar se já passou
      if (dataHora.isBefore(DateTime.now())) continue;

      final baseId = item.id.hashCode.abs() + 20000; // Offset para não conflitar com agenda

      if (item.ministerio == 'Jejum') {
        // Alerta no dia anterior, por exemplo às 20h
        final diaAnterior = dataHora.subtract(const Duration(days: 1));
        final alertaJejum = DateTime(
          diaAnterior.year,
          diaAnterior.month,
          diaAnterior.day,
          20,
          0,
        );

        if (alertaJejum.isAfter(DateTime.now())) {
          await agendarAlertaCustomizado(
            id: baseId + 10000,
            titulo: 'Dia de Jejum Amanhã!',
            corpo: 'Se prepare pois amanhã é o seu dia de Jejuar pela igreja.',
            dataHora: alertaJejum,
          );
        }
        continue;
      }

      await agendarAlertaMatinal(
        id: baseId,
        titulo: 'Você está escalado hoje!',
        corpo: '${item.ministerio} - ${item.funcao} às ${item.horario}.',
        dataHora: dataHora,
      );

      await agendarAlertaUmaHoraAntes(
        id: baseId + 5000,
        titulo: 'Sua escala está próxima',
        corpo: 'Prepare-se! Sua escala em ${item.ministerio} começa em 1 hora.',
        dataHora: dataHora,
      );
    }
  }



  static Future<void> agendarAlertaMatinal({
    required int id,
    required String titulo,
    required String corpo,
    required DateTime dataHora,
  }) async {
    final agendado = tz.TZDateTime.from(
      DateTime(dataHora.year, dataHora.month, dataHora.day, 8, 0),
      tz.local,
    );

    if (agendado.isBefore(tz.TZDateTime.now(tz.local))) return;

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: titulo,
        body: corpo,
        scheduledDate: agendado,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'alertas_igreja_v4', // Novo canal para fixar o toque_escala
            'Alertas da Igreja',
            importance: Importance.max,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('toque_escala'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Erro ao agendar alerta matinal: $e');
    }
  }

  static Future<void> agendarAlertaCustomizado({
    required int id,
    required String titulo,
    required String corpo,
    required DateTime dataHora,
  }) async {
    final agendado = tz.TZDateTime.from(dataHora, tz.local);

    if (agendado.isBefore(tz.TZDateTime.now(tz.local))) return;

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: titulo,
        body: corpo,
        scheduledDate: agendado,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'alertas_igreja_v4',
            'Alertas da Igreja',
            importance: Importance.max,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('toque_escala'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Erro ao agendar alerta customizado: $e');
    }
  }

  static Future<void> agendarAlertaUmaHoraAntes({
    required int id,
    required String titulo,
    required String corpo,
    required DateTime dataHora,
  }) async {
    final agendado = tz.TZDateTime.from(
      dataHora.subtract(const Duration(hours: 1)),
      tz.local,
    );

    if (agendado.isBefore(tz.TZDateTime.now(tz.local))) return;

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: titulo,
        body: corpo,
        scheduledDate: agendado,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'alertas_igreja_v4',
            'Lembretes de Eventos',
            importance: Importance.max,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('toque_escala'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Erro ao agendar lembrete imediato: $e');
    }
  }

  static Future<void> cancelarTodas() async {
    await _notifications.cancelAll();
  }

  static Future<void> mostrarNotificacaoImediata({
    required int id,
    required String titulo,
    required String corpo,
  }) async {
    try {
      await _notifications.show(
        id: id,
        title: titulo,
        body: corpo,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'alertas_igreja_v4',
            'Alertas da Igreja',
            importance: Importance.max,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('toque_escala'),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao mostrar notificação imediata: $e');
    }
  }
}
