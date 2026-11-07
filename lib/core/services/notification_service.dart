import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/agenda_item.dart';
import '../models/escala_item.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool _agendando = false;

  static const _channelId = 'alertas_igreja_v4';
  static const _channelName = 'Alertas da Igreja';
  static const _channelDesc =
      'Notificações de escalas pessoais, jejum e novas playlists de cultos';

  static const _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('toque_escala'),
  );

  static String _nomeDiaSemana(DateTime data) {
    const dias = [
      '',
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];
    return dias[data.weekday];
  }

  static Future<void> init() async {
    if (kIsWeb) return;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (e) {
      debugPrint('Erro ao definir timezone America/Sao_Paulo: $e');
    }

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: android);

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Lógica ao clicar na notificação
      },
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      try {
        await androidPlugin.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Aviso ao solicitar permissão de alarme exato: $e');
      }

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('toque_escala'),
        ),
      );
    }
  }

  /// Mantido apenas por compatibilidade caso algum ponto antigo referencie,
  /// mas desativado por padrão para evitar notificações gerais desnecessárias.
  static Future<void> agendarNotificacoesAgenda(List<AgendaItem> itens) async {
    // Desativado conforme preferência: apenas Playlist (para todos)
    // e Escala / Jejum (individualmente para o membro escalado).
  }

  /// Agenda todas as notificações pessoais (Escala de Culto e Jejum)
  /// exclusivamente para o membro identificado neste aparelho.
  static Future<int> agendarNotificacoesEscala(
    List<EscalaItem> escalas, {
    List<dynamic>? repertoriosCache,
  }) async {
    if (kIsWeb) return 0;
    if (_agendando) return 0;
    _agendando = true;

    int totalAgendadas = 0;

    try {
      debugPrint(
          '🔔 Notificações: Reagendando escalas pessoais (${escalas.length} itens)...');

      // Limpa agendamentos anteriores para evitar duplicidade ou dados de outro perfil
      await _notifications.cancelAll();

      // Busca os repertórios no Supabase para validar se as playlists já foram montadas
      List<dynamic> repertorios = repertoriosCache ?? [];
      if (repertoriosCache == null) {
        try {
          final res = await Supabase.instance.client
              .from('repertorios')
              .select('data_culto, hora_culto, lista_musicas');
          repertorios = res as List<dynamic>;
        } catch (e) {
          debugPrint('Aviso ao consultar repertorios para agendamento: $e');
        }
      }

      final validas = escalas.where((item) {
        final nome = item.nome.trim();
        return nome.isNotEmpty &&
            nome != '[FALTA]' &&
            item.statusConvite != 'FALTA';
      }).toList();

      // 1. Separar escalas de Jejum (agrupadas por data para não duplicar no mesmo dia)
      final datasJejum = <String>{};
      for (final item in validas.where((e) => e.ministerio == 'Jejum')) {
        datasJejum.add(item.data);
      }

      for (final dataStr in datasJejum) {
        final parts = dataStr.split('-');
        if (parts.length != 3) continue;
        final ano = int.tryParse(parts[0]);
        final mes = int.tryParse(parts[1]);
        final dia = int.tryParse(parts[2]);
        if (ano == null || mes == null || dia == null) continue;

        final diaFmt =
            '${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}';
        final baseId = ('jejum_$dataStr').hashCode.abs() % 100000000;

        final dataJejum = DateTime(ano, mes, dia);
        final diaSemanaJejum = _nomeDiaSemana(dataJejum);
        final vespera = dataJejum.subtract(const Duration(days: 1));
        final alertaVespera = DateTime(
          vespera.year,
          vespera.month,
          vespera.day,
          20,
          0,
        );

        final agendouVespera = await agendarAlertaCustomizado(
          id: baseId + 1,
          titulo: '🙏 Jejum Amanhã',
          corpo: '$diaSemanaJejum ($diaFmt) é seu dia de jejum.',
          dataHora: alertaVespera,
        );
        if (agendouVespera) totalAgendadas++;

        // Aviso 2: No próprio dia do Jejum às 06:00 da manhã
        final alertaManhaJejum = DateTime(ano, mes, dia, 6, 0);
        final agendouManha = await agendarAlertaCustomizado(
          id: baseId + 2,
          titulo: '🙏 Jejum Hoje',
          corpo: '$diaSemanaJejum ($diaFmt) é seu propósito de jejum.',
          dataHora: alertaManhaJejum,
        );
        if (agendouManha) totalAgendadas++;
      }

      // 2. Separar escalas de Cultos (agrupadas por data + horário para consolidar acúmulo de funções)
      final Map<String, List<EscalaItem>> cultosAgrupados = {};
      for (final item in validas.where((e) => e.ministerio != 'Jejum')) {
        final horaCurta = item.horario.length >= 5
            ? item.horario.substring(0, 5)
            : item.horario;
        final chave = '${item.data}_$horaCurta';
        cultosAgrupados.putIfAbsent(chave, () => []).add(item);
      }

      for (final entry in cultosAgrupados.entries) {
        final itensDoCulto = entry.value;
        final primeiro = itensDoCulto.first;

        final parts = primeiro.data.split('-');
        if (parts.length != 3) continue;
        final ano = int.tryParse(parts[0]);
        final mes = int.tryParse(parts[1]);
        final dia = int.tryParse(parts[2]);
        if (ano == null || mes == null || dia == null) continue;

        final hParts = primeiro.horario.split(':');
        if (hParts.length < 2) continue;
        final hora = int.tryParse(hParts[0]);
        final minuto = int.tryParse(hParts[1]);
        if (hora == null || minuto == null) continue;

        final horaFmt =
            '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';

        final resumoFuncoes = itensDoCulto
            .map((e) => '${e.ministerio} (${e.funcao})')
            .toSet()
            .join(', ');

        final dataHoraCulto = DateTime(ano, mes, dia, hora, minuto);
        final diaSemanaCulto = _nomeDiaSemana(dataHoraCulto);
        final diaFmt =
            '${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}';
        final isCultoMatutino = hora < 12;
        final isMinistro = itensDoCulto.any((e) =>
            e.funcao.toLowerCase().contains('ministro') ||
            e.funcao.toLowerCase().contains('dirigente'));

        final baseId = ('culto_${entry.key}').hashCode.abs() % 100000000;

        // Aviso 1: Especial para Ministros (2 dias antes às 20:00 para montar a playlist)
        if (isMinistro) {
          final doisDiasAntes = dataHoraCulto.subtract(const Duration(days: 2));
          final alertaMinistro = DateTime(
            doisDiasAntes.year,
            doisDiasAntes.month,
            doisDiasAntes.day,
            20,
            0,
          );

          final agendouMinistro = await agendarAlertaCustomizado(
            id: baseId + 3,
            titulo: '🎵 Playlist do Culto',
            corpo:
                'Você ministra $diaSemanaCulto ($diaFmt) às $horaFmt. Defina as músicas no app.',
            dataHora: alertaMinistro,
          );
          if (agendouMinistro) totalAgendadas++;

          // Aviso Novo: Cobrança caso o ministro AINDA NÃO tenha montado a playlist
          bool temPlaylist = false;
          for (final rep in repertorios) {
            final rData = (rep['data_culto'] ?? '').toString();
            final rHora = (rep['hora_culto'] ?? '').toString();
            final rHoraCurta =
                rHora.length >= 5 ? rHora.substring(0, 5) : rHora;
            final rLista = rep['lista_musicas'];
            final rQtd = (rLista is List) ? rLista.length : 0;
            if (rData == primeiro.data && rHoraCurta == horaFmt && rQtd > 0) {
              temPlaylist = true;
              break;
            }
          }

          if (temPlaylist) {
            // Se já possui músicas na playlist, cancela qualquer cobrança de pendência
            await _notifications.cancel(id: baseId + 4);
          } else {
            // Se NÃO montou a playlist ainda:
            // Culto matutino (< 12:00): avisa na véspera às 20:00
            // Culto tarde/noite (>= 12:00): avisa no dia do culto às 08:00
            DateTime alertaCobranca;
            String corpoCobranca;
            if (isCultoMatutino) {
              final vespera = dataHoraCulto.subtract(const Duration(days: 1));
              alertaCobranca = DateTime(
                vespera.year,
                vespera.month,
                vespera.day,
                20,
                0,
              );
              corpoCobranca =
                  '$diaSemanaCulto ($diaFmt) às $horaFmt • A playlist ainda não foi montada!';
            } else {
              alertaCobranca = DateTime(ano, mes, dia, 8, 0);
              corpoCobranca =
                  '$diaSemanaCulto às $horaFmt • A playlist ainda não foi montada!';
            }

            final agendouCobranca = await agendarAlertaCustomizado(
              id: baseId + 4,
              titulo: '🎵 Playlist Pendente',
              corpo: corpoCobranca,
              dataHora: alertaCobranca,
            );
            if (agendouCobranca) {
              totalAgendadas++;
            } else {
              // Se o alarme de cobrança já deveria ter tocado (passou da hora),
              // mas o culto ainda vai acontecer e faltam pelo menos 30 min:
              final agora = DateTime.now();
              if (agora.isAfter(alertaCobranca) &&
                  dataHoraCulto.isAfter(agora) &&
                  dataHoraCulto.difference(agora).inMinutes >= 30) {
                await mostrarNotificacaoImediata(
                  id: baseId + 4,
                  titulo: '🎵 Playlist Pendente',
                  corpo: corpoCobranca,
                );
              }
            }
          }
        }

        // Aviso 2: Notificação prévia do Culto
        // Se culto matutino (< 12:00): avisa um dia antes na parte da noite (20:00)
        // Se culto à tarde/noite (>= 12:00): avisa às 08:00 da manhã do próprio dia
        if (isCultoMatutino) {
          final vespera = dataHoraCulto.subtract(const Duration(days: 1));
          final alertaVespera = DateTime(
            vespera.year,
            vespera.month,
            vespera.day,
            20,
            0,
          );

          final agendouVespera = await agendarAlertaCustomizado(
            id: baseId + 1,
            titulo: '📅 Escala Amanhã',
            corpo: '$diaSemanaCulto ($diaFmt) às $horaFmt • $resumoFuncoes',
            dataHora: alertaVespera,
          );
          if (agendouVespera) totalAgendadas++;
        } else {
          final alertaMatinal = DateTime(ano, mes, dia, 8, 0);
          final agendouMatinal = await agendarAlertaCustomizado(
            id: baseId + 1,
            titulo: '📅 Escala Hoje',
            corpo: '$diaSemanaCulto às $horaFmt • $resumoFuncoes',
            dataHora: alertaMatinal,
          );
          if (agendouMatinal) totalAgendadas++;
        }

        // Aviso 3: 1 hora antes do início do culto
        final alerta1hAntes = dataHoraCulto.subtract(const Duration(hours: 1));
        final agendou1h = await agendarAlertaCustomizado(
          id: baseId + 2,
          titulo: '⏰ Escala em 1 hora',
          corpo: '$resumoFuncoes às $horaFmt',
          dataHora: alerta1hAntes,
        );
        if (agendou1h) totalAgendadas++;
      }

      debugPrint('🔔 Notificações: $totalAgendadas alertas pessoais agendados.');
      return totalAgendadas;
    } finally {
      _agendando = false;
    }
  }

  static Future<bool> agendarAlertaCustomizado({
    required int id,
    required String titulo,
    required String corpo,
    required DateTime dataHora,
  }) async {
    if (kIsWeb) return false;

    final agendado = tz.TZDateTime(
      tz.local,
      dataHora.year,
      dataHora.month,
      dataHora.day,
      dataHora.hour,
      dataHora.minute,
    );

    if (!agendado.isAfter(tz.TZDateTime.now(tz.local))) return false;

    const details = NotificationDetails(android: _androidDetails);

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: titulo,
        body: corpo,
        scheduledDate: agendado,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      debugPrint(
          'Aviso: fallback para inexactAllowWhileIdle no alarme $id ($e)');
      try {
        await _notifications.zonedSchedule(
          id: id,
          title: titulo,
          body: corpo,
          scheduledDate: agendado,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        return true;
      } catch (e2) {
        debugPrint('Erro ao agendar alerta customizado: $e2');
        return false;
      }
    }
  }

  static Future<List<PendingNotificationRequest>>
      listarNotificacoesPendentes() async {
    if (kIsWeb) return [];
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Erro ao listar notificações pendentes: $e');
      return [];
    }
  }

  static Future<void> cancelarTodas() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  /// Cancela o alerta de cobrança de montagem de playlist para um determinado culto
  static Future<void> cancelarCobrancaPlaylist(String data, String hora) async {
    if (kIsWeb) return;
    try {
      final horaCurta = hora.length >= 5 ? hora.substring(0, 5) : hora;
      final baseId = ('culto_${data}_$horaCurta').hashCode.abs() % 100000000;
      await _notifications.cancel(id: baseId + 4);
      debugPrint(
          '🔔 [Notificações] Cobrança de playlist cancelada para $data $horaCurta (ID: ${baseId + 4})');
    } catch (e) {
      debugPrint('Erro ao cancelar cobrança de playlist: $e');
    }
  }

  static Future<void> mostrarNotificacaoImediata({
    required int id,
    required String titulo,
    required String corpo,
  }) async {
    if (kIsWeb) return;
    try {
      await _notifications.show(
        id: id,
        title: titulo,
        body: corpo,
        notificationDetails: const NotificationDetails(android: _androidDetails),
      );
    } catch (e) {
      debugPrint('Erro ao mostrar notificação imediata: $e');
    }
  }
}
