import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/supabase_config.dart';
import 'core/providers/app_providers.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forçar portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Barra de status transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF1A1D27),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Locale PT-BR
  await initializeDateFormatting('pt_BR', null);

  // Inicializar SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Inicializar Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Inicializar Notificações Locais
  await NotificationService.init();

  // Inicializar Push Notifications (Firebase)
  await PushNotificationService.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const IgrejaAdminApp(),
    ),
  );
}

