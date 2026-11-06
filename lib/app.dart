import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roleNotifier = ref.read(userRoleProvider.notifier);
      final membroId = roleNotifier.selectedMembroId;
      if (membroId != null) {
        PushNotificationService.registerAndSaveToken(membroId);
      }

      // Checagem de atualização OTA
      UpdateService.checkForUpdateAndPrompt(context);

      // Primeira carga do widget Android e agendamento de notificações pessoais
      _atualizarWidget();
      _agendarNotificacoes();
    });
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
        selectedIcon: Icon(PhosphorIconsBold.house),
        label: 'Início',
      ),
      NavigationDestination(
        icon: const Icon(PhosphorIconsRegular.calendar),
        selectedIcon: const Icon(PhosphorIconsBold.calendar),
        label: isMembro ? 'Minha Escala' : 'Escala',
      ),
      const NavigationDestination(
        icon: Icon(PhosphorIconsRegular.musicNote),
        selectedIcon: Icon(PhosphorIconsBold.musicNote),
        label: 'Músicas',
      ),
      if (!isMembro)
        const NavigationDestination(
          icon: Icon(PhosphorIconsRegular.users),
          selectedIcon: Icon(PhosphorIconsBold.users),
          label: 'Membros',
        ),
      const NavigationDestination(
        icon: Icon(PhosphorIconsRegular.gear),
        selectedIcon: Icon(PhosphorIconsBold.gear),
        label: 'Config',
      ),
    ];

    final railDestinations = [
      const NavigationRailDestination(
        icon: Icon(PhosphorIconsRegular.house),
        selectedIcon: Icon(PhosphorIconsBold.house),
        label: Text('Início'),
      ),
      NavigationRailDestination(
        icon: const Icon(PhosphorIconsRegular.calendar),
        selectedIcon: const Icon(PhosphorIconsBold.calendar),
        label: Text(isMembro ? 'Minha Escala' : 'Escala'),
      ),
      const NavigationRailDestination(
        icon: Icon(PhosphorIconsRegular.musicNote),
        selectedIcon: Icon(PhosphorIconsBold.musicNote),
        label: Text('Músicas'),
      ),
      if (!isMembro)
        const NavigationRailDestination(
          icon: Icon(PhosphorIconsRegular.users),
          selectedIcon: Icon(PhosphorIconsBold.users),
          label: Text('Membros'),
        ),
      const NavigationRailDestination(
        icon: Icon(PhosphorIconsRegular.gear),
        selectedIcon: Icon(PhosphorIconsBold.gear),
        label: Text('Config'),
      ),
    ];

    if (_idx >= screens.length) {
      _idx = screens.length - 1;
    }

    return LayoutBuilder(
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
                  minExtendedWidth: 160,
                  destinations: railDestinations,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  indicatorColor: AppColors.acento.withValues(alpha: 0.2),
                  selectedLabelTextStyle: const TextStyle(
                      color: AppColors.acento, fontWeight: FontWeight.bold),
                  unselectedLabelTextStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7)),
                  selectedIconTheme:
                      const IconThemeData(color: AppColors.acento),
                  unselectedIconTheme: IconThemeData(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7)),
                ),
                const VerticalDivider(
                    thickness: 1, width: 1, color: AppColors.bgBorda),
                Container(
                  width: 350,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: AppColors.bgBorda)),
                  ),
                  child: const Scaffold(
                    body: Padding(
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
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.bgBorda)),
            ),
            child: NavigationBar(
              selectedIndex: _idx,
              onDestinationSelected: (i) => setState(() => _idx = i),
              destinations: destinations,
            ),
          ),
        );
      },
    );
  }
}
