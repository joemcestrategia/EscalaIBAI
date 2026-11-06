import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../firebase_options.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('🔔 [FCM Background] Mensagem recebida: ${message.messageId}');
  } catch (e) {
    debugPrint('Erro no background handler do FCM: $e');
  }
}

class PushNotificationService {
  static String? _currentMembroId;
  static DateTime? _ultimaNotificacaoRepertorio;
  static RealtimeChannel? _repertorioChannel;

  static Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Inscreve no tópico geral como fallback
        try {
          await FirebaseMessaging.instance.subscribeToTopic('todos');
        } catch (e) {
          debugPrint('Aviso ao inscrever no tópico todos: $e');
        }
      }

      // Handler de notificação push em foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('🔔 [FCM Foreground] Mensagem recebida!');
        if (message.notification != null) {
          if (message.data['tipo'] == 'novo_repertorio') {
            _ultimaNotificacaoRepertorio = DateTime.now();
          }
          NotificationService.mostrarNotificacaoImediata(
            id: message.messageId?.hashCode ??
                DateTime.now().millisecondsSinceEpoch ~/ 1000,
            titulo: message.notification!.title ?? 'Nova Notificação',
            corpo: message.notification!.body ?? '',
          );
        }
      });

      // Atualiza o token automaticamente caso o FCM rotacione o token do aparelho
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (_currentMembroId != null) {
          _salvarTokenNoBanco(_currentMembroId!, newToken);
        }
      });

      // Escuta Realtime da tabela repertorios para garantir aviso imediato em foreground
      _iniciarEscutaRealtimeRepertorios();
    } catch (e) {
      debugPrint('Erro ao inicializar Firebase/PushNotificationService: $e');
    }
  }

  static void _iniciarEscutaRealtimeRepertorios() {
    try {
      final supabase = Supabase.instance.client;
      _repertorioChannel?.unsubscribe();
      _repertorioChannel = supabase
          .channel('public:repertorios_notificacao')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'repertorios',
            callback: (payload) {
              if (payload.eventType == PostgresChangeEvent.insert ||
                  payload.eventType == PostgresChangeEvent.update) {
                final agora = DateTime.now();
                // Evita duplicar se a push FCM já tiver disparado nos últimos 15 segundos
                if (_ultimaNotificacaoRepertorio != null &&
                    agora.difference(_ultimaNotificacaoRepertorio!).inSeconds <
                        15) {
                  return;
                }
                _ultimaNotificacaoRepertorio = agora;

                final record = payload.newRecord;
                final dataCulto = (record['data_culto'] ?? '').toString();
                final horaCulto = (record['hora_culto'] ?? '').toString();
                final lista = record['lista_musicas'];
                final qtd = lista is List ? lista.length : 0;

                if (dataCulto.isEmpty || qtd == 0) return;

                final partes = dataCulto.split('-');
                final dataFmt = partes.length == 3
                    ? '${partes[2]}/${partes[1]}/${partes[0]}'
                    : dataCulto;
                final horaFmt = horaCulto.length >= 5
                    ? horaCulto.substring(0, 5)
                    : horaCulto;

                String diaSemana = '';
                if (partes.length == 3) {
                  final dt = DateTime.tryParse(dataCulto);
                  if (dt != null) {
                    const dias = ['', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
                    diaSemana = '${dias[dt.weekday]}, ';
                  }
                }

                NotificationService.mostrarNotificacaoImediata(
                  id: ('rep_$dataCulto$horaFmt').hashCode.abs() % 100000000,
                  titulo: '🎵 Playlist do Culto',
                  corpo: '$diaSemana$dataFmt às $horaFmt • $qtd música(s)',
                );
              }
            },
          )
        ..subscribe();
    } catch (e) {
      debugPrint('Erro ao iniciar escuta realtime de repertorios: $e');
    }
  }

  static Future<void> registerAndSaveToken(String membroId) async {
    _currentMembroId = membroId;
    try {
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        String? token;
        if (kIsWeb) {
          token = await messaging.getToken(
            vapidKey:
                'BALHPwHz6uLR58kTKoZ188SWJp9OsUHaJPa43sA4umFw8homZaNovHbBCcGtVvau5ZHQ9-zaU4OZ77MxCAtnL40',
          );
        } else {
          token = await messaging.getToken();
        }

        if (token != null) {
          debugPrint('🔔 FCM Token obtido para membro $membroId');
          await _salvarTokenNoBanco(membroId, token);
        }
      }
    } catch (e) {
      debugPrint('Erro ao registrar push token: $e');
    }
  }

  static Future<void> _salvarTokenNoBanco(String membroId, String token) async {
    try {
      final supabase = Supabase.instance.client;
      const plataforma = kIsWeb ? 'web' : 'android';

      // Remove vínculos antigos deste mesmo token em outros membros (caso tenha trocado de perfil no mesmo aparelho)
      await supabase
          .from('membro_tokens')
          .delete()
          .eq('token', token)
          .neq('membro_id', membroId);

      await supabase.from('membro_tokens').upsert(
        {
          'membro_id': membroId,
          'token': token,
          'plataforma': plataforma,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'membro_id, token',
      );
    } catch (e) {
      debugPrint('Erro ao salvar token no Supabase: $e');
    }
  }
}
