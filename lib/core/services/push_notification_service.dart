import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../firebase_options.dart';
import 'notification_service.dart';

class PushNotificationService {
  static Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } else {
          await Firebase.initializeApp(); // Usa google-services.json
        }
      }

      // Handler de notificação em foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        if (message.notification != null) {
          NotificationService.mostrarNotificacaoImediata(
            id: message.messageId.hashCode,
            titulo: message.notification!.title ?? '',
            corpo: message.notification!.body ?? '',
          );
        }
      });
    } catch (e) {
      debugPrint('Erro ao inicializar Firebase: $e');
    }
  }

  static Future<void> registerAndSaveToken(String membroId) async {
    try {
      final messaging = FirebaseMessaging.instance;
      // Solicitar permissão
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Pega o token
        String? token;
        if (kIsWeb) {
          token = await messaging.getToken(
            vapidKey: 'BALHPwHz6uLR58kTKoZ188SWJp9OsUHaJPa43sA4umFw8homZaNovHbBCcGtVvau5ZHQ9-zaU4OZ77MxCAtnL40',
          );
        } else {
          token = await messaging.getToken();
        }

        if (token != null) {
          debugPrint('FCM Token: $token');
          // Salva no Supabase
          final supabase = Supabase.instance.client;
          final plataforma = kIsWeb ? 'web' : 'android';
          
          await supabase.from('membro_tokens').upsert(
            {
              'membro_id': membroId,
              'token': token,
              'plataforma': plataforma,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'membro_id, token',
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao registrar push token: $e');
    }
  }
}
