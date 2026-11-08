import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/app_providers.dart';
import 'features/home/home_screen.dart';
import 'features/escala/escala_screen.dart';
import 'features/escala/minhas_escalas_screen.dart';
import 'features/musicas/musicas_screen.dart';
import 'features/membros/membros_screen.dart';
import 'features/configuracoes/config_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/splash/role_selection_screen.dart';
import 'features/splash/quem_sou_eu_screen.dart';
import 'core/services/notification_service.dart';
import 'features/home/widgets/home_calendar_web.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/widget_service.dart';
import 'core/services/update_service.dart';

class IgrejaAdminApp extends ConsumerStatefulWidget {
  const IgrejaAdminApp({super.key});

  @override
  ConsumerState<IgrejaAdminApp> createState() => _IgrejaAdminAppState();
}

class _IgrejaAdminAppState extends ConsumerState<IgrejaAdminApp> {
  bool _initialized = false;
  bool _showSplash = false;

  @override
  void initState() {
    super.initState();
    WidgetService.init();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final role = ref.watch(userRoleProvider);
    final roleNotifier = ref.watch(userRoleProvider.notifier);
    final hasRole = roleNotifier.hasSelectedRole;
    final hasMembro = roleNotifier.selectedMembroNome != null &&
        roleNotifier.selectedMembroNome!.isNotEmpty;

    Widget homeWidget;
    if (!hasRole) {
      homeWidget = RoleSelectionScreen(
        onRoleSelected: () {
          setState(() {
            _showSplash = true;
          });
        },
      );
    } else if (!hasMembro) {
      homeWidget = QuemSouEuScreen(
        role: role,
        isReconfiguration: true,
        onMemberSelected: () {
          setState(() {
            _showSplash = true;
          });
        },
      );
    } else if (!_initialized || _showSplash) {
      homeWidget = SplashScreen(
        onInitializationComplete: () {
          setState(() {
            _initialized = true;
            _showSplash = false;
          });
        },
      );
    } else {
      homeWidget = const _MainShell();
    }

    return MaterialApp(
      title: 'Escala',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor:
                isDark ? AppColors.bgCard : AppColors.bgCardLight,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: homeWidget,
    );
  }
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  int _idx = 1; // 1 = Escala
  StreamSubscription? _fgPushSub;

  @override
  void initState() {
    super.initState();
    _fgPushSub = PushNotificationService.onForegroundMessage.listen((msg) {
      if (!mounted) return;
      final titulo = msg.notification?.title ??
          (msg.data['title'] as String?) ??
          (msg.data['titulo'] as String?);
      final corpo = msg.notification?.body ??
          (msg.data['body'] as String?) ??
          (msg.data['corpo'] as String?);
      if (titulo != null && titulo.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            content: Text(
              corpo != null && corpo.isNotEmpty ? '$titulo\n$corpo' : titulo,
            ),
          ),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roleNotifier = ref.read(userRoleProvider.notifier);
      final membroId = roleNotifier.selectedMembroId;
      if (membroId != null) {
        PushNotificationService.registerAndSaveToken(
          membroId,
          promptIfNeeded: !kIsWeb,
        );
      }

      // Checagem de atualização OTA
      UpdateService.checkForUpdateAndPrompt(context);

      // Primeira carga do widget Android e agendamento de notificações pessoais
      _atualizarWidget();
      _agendarNotificacoes();
    });
  }

  @override
  void dispose() {
    _fgPushSub?.cancel();
    super.dispose();
  }

  void _atualizarWidget() {
    ref.read(proximaEscalaProvider.future).then((itens) {
      debugPrint(
          '🟦 [MainShell] proximaEscalaProvider retornou ${itens.length} itens para o widget.');
      WidgetService.updateEscalasWidget(itens);
    }).catchError((e) {
      debugPrint('❌ [MainShell] Erro ao carregar proximas escalas: $e');
    });
  }

  void _agendarNotificacoes() {
    final roleNotifier = ref.read(userRoleProvider.notifier);
    final membroNome = roleNotifier.selectedMembroNome;
    if (membroNome != null && membroNome.isNotEmpty) {
      ref.read(escalaRepoProvider).getByMembro(membroNome).then((itens) {
        NotificationService.agendarNotificacoesEscala(itens);
      }).catchError((e) {
        debugPrint('❌ [MainShell] Erro ao agendar notificações de escala: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final isMembro = role == UserRole.membro;

    // Reagenda automaticamente as notificações pessoais quando a escala do mês muda em tempo real
    ref.listen<AsyncValue<dynamic>>(escalaDoMesProvider, (prev, next) {
      if (next.hasValue) {
        _agendarNotificacoes();
      }
    });

    // Reagenda notificações pessoais quando os repertórios mudam em tempo real
    ref.listen<AsyncValue<dynamic>>(repertoriosProvider, (prev, next) {
      if (next.hasValue) {
        _agendarNotificacoes();
      }
    });

    final screens = [
      const HomeScreen(),
      isMembro ? const MinhasEscalasScreen() : const EscalaScreen(),
      const MusicasScreen(),
      if (!isMembro) const MembrosScreen(),
      const ConfigScreen(),
    ];

    final destinations = [
      const NavigationDestination(
        icon: Icon(PhosphorIconsRegular.house),
        selectedIcon: Icon(PhosphorIconsFill.house),
        label: 'Início',
      ),
      NavigationDestination(
        icon: const Icon(PhosphorIconsRegular.calendarBlank),
        selectedIcon: const Icon(PhosphorIconsFill.calendarBlank),
        label: isMembro ? 'Escala' : 'Escala',
      ),
      const NavigationDestination(
        icon: Icon(PhosphorIconsRegular.musicNotes),
        selectedIcon: Icon(PhosphorIconsFill.musicNotes),
        label: 'Músicas',
      ),
      if (!isMembro)
        const NavigationDestination(
          icon: Icon(PhosphorIconsRegular.users),
          selectedIcon: Icon(PhosphorIconsFill.users),
          label: 'Equipe',
        ),
      const NavigationDestination(
        icon: Icon(PhosphorIconsRegular.gearSix),
        selectedIcon: Icon(PhosphorIconsFill.gearSix),
        label: 'Ajustes',
      ),
    ];

    final railDestinations = [
      const NavigationRailDestination(
        icon: Icon(PhosphorIconsRegular.house),
        selectedIcon: Icon(PhosphorIconsFill.house),
        label: Text('Início'),
      ),
      const NavigationRailDestination(
        icon: Icon(PhosphorIconsRegular.calendarBlank),
        selectedIcon: Icon(PhosphorIconsFill.calendarBlank),
        label: Text('Escala'),
      ),
      const NavigationRailDestination(
        icon: Icon(PhosphorIconsRegular.musicNotes),
        selectedIcon: Icon(PhosphorIconsFill.musicNotes),
        label: Text('Músicas'),
      ),
      if (!isMembro)
        const NavigationRailDestination(
          icon: Icon(PhosphorIconsRegular.users),
          selectedIcon: Icon(PhosphorIconsFill.users),
          label: Text('Equipe'),
        ),
      const NavigationRailDestination(
        icon: Icon(PhosphorIconsRegular.gearSix),
        selectedIcon: Icon(PhosphorIconsFill.gearSix),
        label: Text('Ajustes'),
      ),
    ];

    if (_idx >= screens.length) {
      _idx = screens.length - 1;
    }

    return AppNavigation(
      go: (i) => setState(() => _idx = i),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            // Layout Desktop
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _idx,
                    onDestinationSelected: (i) => setState(() => _idx = i),
                    extended: true,
                    minExtendedWidth: 180,
                    destinations: railDestinations,
                    backgroundColor: context.bgCard,
                    indicatorColor: context.acentoSuave,
                    selectedLabelTextStyle: AppTextStyles.bodySmall(
                      color: context.corPrimaria,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelTextStyle: AppTextStyles.bodySmall(
                      color: context.textoSecund,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedIconTheme:
                        IconThemeData(color: context.corPrimaria, size: 22),
                    unselectedIconTheme:
                        IconThemeData(color: context.textoSecund, size: 22),
                  ),
                  VerticalDivider(
                      thickness: 1, width: 1, color: context.bgBorda),
                  Container(
                    width: 360,
                    decoration: BoxDecoration(
                      color: context.bgCard,
                      border: Border(right: BorderSide(color: context.bgBorda)),
                    ),
                    child: Scaffold(
                      backgroundColor: context.bgCard,
                      body: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: HomeCalendarWeb(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _idx,
                      children: screens,
                    ),
                  ),
                ],
              ),
            );
          }

          // Layout Mobile
          return Scaffold(
            body: IndexedStack(
              index: _idx,
              children: screens,
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: context.bgCard,
                border: Border(top: BorderSide(color: context.bgBorda)),
                boxShadow: context.isDark
                    ? null
                    : [
                        BoxShadow(
                          color:
                              const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ],
              ),
              child: NavigationBar(
                selectedIndex: _idx,
                onDestinationSelected: (i) => setState(() => _idx = i),
                destinations: destinations,
              ),
            ),
          );
        },
      ),
    );
  }
}
