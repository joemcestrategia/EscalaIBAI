import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../firebase_options.dart';
import 'notification_service.dart';
import 'web_push_bridge.dart';

enum PushRegistrationStatus {
  registered,
  needsHomeScreenInstall,
  needsUserGesture,
  denied,
  unsupported,
  error,
}

class PushRegistrationResult {
  final PushRegistrationStatus status;
  final String? token;
  final String? message;

  const PushRegistrationResult({
    required this.status,
    this.token,
    this.message,
  });

  bool get isSuccess => status == PushRegistrationStatus.registered;
}

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
  static const String _webVapidKey =
      'BALHPwHz6uLR58kTKoZ188SWJp9OsUHaJPa43sA4umFw8homZaNovHbBCcGtVvau5ZHQ9-zaU4OZ77MxCAtnL40';

  static String? _currentMembroId;
  static String? _currentToken;
  static PushRegistrationResult? _lastResult;
  static DateTime? _ultimaNotificacaoRepertorio;
  static RealtimeChannel? _repertorioChannel;
  static bool _listenersRegistrados = false;
  static final StreamController<RemoteMessage> _foregroundMessageController =
      StreamController<RemoteMessage>.broadcast();

  static Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundMessageController.stream;

  static PushRegistrationResult? get lastResult => _lastResult;
  static String? get currentToken => _currentToken;

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

        // Inscreve no tópico geral como fallback no Android
        try {
          await FirebaseMessaging.instance.subscribeToTopic('todos');
        } catch (e) {
          debugPrint('Aviso ao inscrever no tópico todos: $e');
        }
      } else {
        // No Web/iOS PWA, prepara o Service Worker do Firebase Messaging sem bloquear o startup
        unawaited(WebPushBridge.ensureFirebaseSwReady());
        final supported = await _isWebPushSupported();
        if (!supported) {
          debugPrint(
            'ℹ️ [Web Push] Navegador atual não suporta Push API (no iOS exige PWA na Tela de Início).',
          );
          _iniciarEscutaRealtimeRepertorios();
          return;
        }
      }

      if (!_listenersRegistrados) {
        _listenersRegistrados = true;

        // Handler de notificação push em foreground
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('🔔 [FCM Foreground] Mensagem recebida!');
          _foregroundMessageController.add(message);

          final titulo = message.notification?.title ??
              (message.data['title'] as String?) ??
              (message.data['titulo'] as String?) ??
              'Nova Notificação';
          final corpo = message.notification?.body ??
              (message.data['body'] as String?) ??
              (message.data['corpo'] as String?) ??
              '';

          if (message.data['tipo'] == 'novo_repertorio') {
            _ultimaNotificacaoRepertorio = DateTime.now();
          }

          if (message.notification != null ||
              titulo != 'Nova Notificação' ||
              corpo.isNotEmpty) {
            NotificationService.mostrarNotificacaoImediata(
              id: message.messageId?.hashCode ??
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
              titulo: titulo,
              corpo: corpo,
            );
          }
        });

        // Atualiza o token automaticamente caso o FCM rotacione o token do aparelho
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          _currentToken = newToken;
          if (_currentMembroId != null) {
            _salvarTokenNoBanco(_currentMembroId!, newToken);
          }
        });
      }

      // Escuta Realtime da tabela repertorios para garantir aviso imediato em foreground
      _iniciarEscutaRealtimeRepertorios();
    } catch (e) {
      debugPrint('Erro ao inicializar Firebase/PushNotificationService: $e');
    }
  }

  static Future<bool> _isWebPushSupported() async {
    if (!kIsWeb) return true;
    try {
      if (!WebPushBridge.supportsPush) return false;
      return await FirebaseMessaging.instance.isSupported();
    } catch (_) {
      return false;
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

                // Cancela qualquer cobrança pendente caso a playlist tenha sido montada
                NotificationService.cancelarCobrancaPlaylist(
                  dataCulto,
                  horaCulto,
                );

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
                    const dias = [
                      '',
                      'Segunda',
                      'Terça',
                      'Quarta',
                      'Quinta',
                      'Sexta',
                      'Sábado',
                      'Domingo'
                    ];
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

  /// Verifica o status atual das notificações neste aparelho sem disparar popups.
  static Future<PushRegistrationResult> checkStatus(String? membroId) async {
    if (!kIsWeb) {
      try {
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          return const PushRegistrationResult(
            status: PushRegistrationStatus.denied,
            message: 'Permissão negada nas configurações do aparelho.',
          );
        }
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          return PushRegistrationResult(
            status: _currentToken != null
                ? PushRegistrationStatus.registered
                : PushRegistrationStatus.needsUserGesture,
            token: _currentToken,
            message: _currentToken != null
                ? 'Notificações ativas neste aparelho.'
                : 'Pronto para sincronizar token.',
          );
        }
        return const PushRegistrationResult(
          status: PushRegistrationStatus.needsUserGesture,
          message: 'Permissão ainda não solicitada.',
        );
      } catch (e) {
        return PushRegistrationResult(
          status: PushRegistrationStatus.error,
          message: e.toString(),
        );
      }
    }

    if (WebPushBridge.isIos && !WebPushBridge.isStandalone) {
      return const PushRegistrationResult(
        status: PushRegistrationStatus.needsHomeScreenInstall,
        message:
            'No iPhone, toque em Compartilhar > "Adicionar à Tela de Início" e abra o app pelo ícone instalado.',
      );
    }

    final supported = await _isWebPushSupported();
    if (!supported) {
      return const PushRegistrationResult(
        status: PushRegistrationStatus.unsupported,
        message: 'Este navegador não suporta notificações Web Push.',
      );
    }

    final perm = WebPushBridge.permissionStatus;
    if (perm == 'denied') {
      return const PushRegistrationResult(
        status: PushRegistrationStatus.denied,
        message:
            'Notificações bloqueadas. No iPhone, abra Ajustes > Notificações > Escala IBAI e ative.',
      );
    }

    if (perm != 'granted') {
      return const PushRegistrationResult(
        status: PushRegistrationStatus.needsUserGesture,
        message: 'Toque no botão abaixo para ativar as notificações no iPhone.',
      );
    }

    if (_currentToken != null) {
      return PushRegistrationResult(
        status: PushRegistrationStatus.registered,
        token: _currentToken,
        message: 'Notificações Web Push ativas neste aparelho.',
      );
    }

    if (membroId != null && membroId.isNotEmpty) {
      return registerAndSaveToken(membroId, promptIfNeeded: false);
    }

    return const PushRegistrationResult(
      status: PushRegistrationStatus.needsUserGesture,
      message: 'Permissão concedida; selecione seu nome para registrar o aparelho.',
    );
  }

  /// Registra o token FCM do aparelho e salva na tabela `membro_tokens`.
  /// No Web/iOS, `promptIfNeeded: false` evita chamar `requestPermission` fora
  /// de um gesto explícito do usuário (ex.: no `initState`), renovando apenas se
  /// a permissão já estiver concedida.
  static Future<PushRegistrationResult> registerAndSaveToken(
    String membroId, {
    bool promptIfNeeded = true,
  }) async {
    _currentMembroId = membroId;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      if (kIsWeb) {
        if (WebPushBridge.isIos && !WebPushBridge.isStandalone) {
          const res = PushRegistrationResult(
            status: PushRegistrationStatus.needsHomeScreenInstall,
            message:
                'No iPhone, instale o app pela opção Compartilhar > Adicionar à Tela de Início para receber notificações.',
          );
          _lastResult = res;
          return res;
        }

        // Verificação síncrona primeiro para NÃO perder o contexto do gesto do usuário (user activation)
        // antes de chamar Notification.requestPermission() no Safari iOS!
        if (!WebPushBridge.supportsPush) {
          const res = PushRegistrationResult(
            status: PushRegistrationStatus.unsupported,
            message: 'Este navegador não suporta notificações Web Push.',
          );
          _lastResult = res;
          return res;
        }

        final permAtual = WebPushBridge.permissionStatus;
        if (permAtual == 'denied') {
          const res = PushRegistrationResult(
            status: PushRegistrationStatus.denied,
            message:
                'Permissão bloqueada. Reative em Ajustes do iOS > Notificações > Escala IBAI.',
          );
          _lastResult = res;
          return res;
        }

        if (!promptIfNeeded && permAtual != 'granted') {
          const res = PushRegistrationResult(
            status: PushRegistrationStatus.needsUserGesture,
            message: 'Aguardando toque do usuário para ativar notificações.',
          );
          _lastResult = res;
          return res;
        }
      }

      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings;
      if (kIsWeb && WebPushBridge.permissionStatus == 'granted') {
        settings = await messaging.getNotificationSettings();
      } else {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        String? token;
        if (kIsWeb) {
          final supported = await messaging.isSupported();
          if (!supported) {
            const res = PushRegistrationResult(
              status: PushRegistrationStatus.unsupported,
              message: 'Este navegador não suporta Firebase Web Push.',
            );
            _lastResult = res;
            return res;
          }
          final swOk = await WebPushBridge.ensureFirebaseSwReady();
          if (!swOk) {
            debugPrint(
              '⚠️ [Web Push] Service Worker do Firebase ainda não está pronto; tentando getToken mesmo assim.',
            );
          }
          token = await _getWebTokenComRetry(messaging);
        } else {
          token = await messaging.getToken();
        }

        if (token != null && token.isNotEmpty) {
          _currentToken = token;
          debugPrint('🔔 FCM Token obtido para membro $membroId');
          await _salvarTokenNoBanco(membroId, token);
          final res = PushRegistrationResult(
            status: PushRegistrationStatus.registered,
            token: token,
            message: 'Notificações ativas e token salvo com sucesso.',
          );
          _lastResult = res;
          return res;
        }

        const res = PushRegistrationResult(
          status: PushRegistrationStatus.error,
          message: 'Não foi possível gerar o token push neste aparelho.',
        );
        _lastResult = res;
        return res;
      }

      final res = PushRegistrationResult(
        status: settings.authorizationStatus == AuthorizationStatus.denied
            ? PushRegistrationStatus.denied
            : PushRegistrationStatus.needsUserGesture,
        message: settings.authorizationStatus == AuthorizationStatus.denied
            ? 'Permissão de notificações negada.'
            : 'Permissão não concedida.',
      );
      _lastResult = res;
      return res;
    } catch (e) {
      debugPrint('Erro ao registrar push token: $e');
      final res = PushRegistrationResult(
        status: PushRegistrationStatus.error,
        message: 'Falha ao ativar notificações: $e',
      );
      _lastResult = res;
      return res;
    }
  }

  static Future<String?> _getWebTokenComRetry(
    FirebaseMessaging messaging,
  ) async {
    try {
      return await messaging.getToken(vapidKey: _webVapidKey);
    } catch (e) {
      debugPrint('Aviso na 1ª tentativa de getToken Web ($e), aguardando SW...');
      await WebPushBridge.ensureFirebaseSwReady();
      await Future.delayed(const Duration(milliseconds: 600));
      return await messaging.getToken(vapidKey: _webVapidKey);
    }
  }

  /// Dispara uma notificação push real pelo Supabase Edge Function para validar o aparelho.
  static Future<Map<String, dynamic>> enviarNotificacaoTeste(
    String membroId,
  ) async {
    final res = await Supabase.instance.client.functions.invoke(
      'notificar-repertorio',
      body: {
        'membroId': membroId,
        'titulo': '🔔 Teste de Notificação',
        'corpo': 'Seu aparelho está configurado e recebendo avisos do Escala IBAI!',
      },
    );
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return {'status': res.status, 'data': res.data};
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
