import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/models/ministerio.dart';
import '../../core/models/escala_item.dart';
import '../../core/models/agenda_item.dart';
import '../../shared/widgets/app_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _fades;
  late List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fades = List.generate(
      6,
      (i) => Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(i * 0.12, (i * 0.12 + 0.55).clamp(0.0, 1.0),
            curve: Curves.easeOut),
      )),
    );
    _slides = List.generate(
      6,
      (i) => Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(i * 0.12, (i * 0.12 + 0.55).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      )),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _animated(int idx, Widget child) => FadeTransition(
        opacity: _fades[idx],
        child: SlideTransition(position: _slides[idx], child: child),
      );

  String _saudacao() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildHeader(BuildContext context) {
    final hoje = _capitalize(
      DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now()),
    );
    final nomeCompleto =
        ref.watch(userRoleProvider.notifier).selectedMembroNome ?? '';
    final primeiroNome = nomeCompleto.trim().isNotEmpty
        ? nomeCompleto.trim().split(RegExp(r'\s+')).first
        : '';
    final saudacaoTexto =
        primeiroNome.isNotEmpty ? '${_saudacao()}, $primeiroNome' : _saudacao();
    final isDark = context.isDark;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hoje,
                style: AppTextStyles.bodySmall(color: context.textoSecund),
              ),
              const SizedBox(height: 2),
              Text(
                saudacaoTexto,
                style: AppTextStyles.display(color: context.textoPrimario)
                    .copyWith(fontSize: 24),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Atalho rápido de Modo Claro (Dia) / Escuro (Palco)
        Material(
          color: context.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: context.bgBorda),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
            },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                isDark ? PhosphorIconsBold.sun : PhosphorIconsBold.moon,
                size: 20,
                color: context.textoPrimario,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            final role = ref.read(userRoleProvider);
            final configIndex = role == UserRole.membro ? 3 : 4;
            AppNavigation.of(context)?.go(configIndex);
          },
          child: AppAvatar(
            name: nomeCompleto.isNotEmpty ? nomeCompleto : 'IB',
            size: 44,
            accentColor: AppColors.acento,
            circular: true,
          ),
        ),
      ],
    );
  }

  Widget _buildVersiculoBanner(
    BuildContext context,
    AsyncValue<Map<String, String>> versiculo,
  ) {
    return versiculo.when(
      data: (v) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.bgSubtle,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.bgBorda),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIconsFill.bookOpenText,
                  size: 18,
                  color: context.corPrimaria,
                ),
                const SizedBox(width: 8),
                Text(
                  'PALAVRA DO DIA',
                  style: AppTextStyles.label(color: context.corPrimaria),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '“${v['texto']}”',
              style: AppTextStyles.body(color: context.textoPrimario),
            ),
            const SizedBox(height: 8),
            Text(
              v['ref'] ?? '',
              style: AppTextStyles.label(color: context.textoSecund),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nomeMembro =
        ref.watch(userRoleProvider.notifier).selectedMembroNome ?? '';

    return Scaffold(
      backgroundColor: context.bgPrincipal,
      body: SafeArea(
        child: RefreshIndicator(
          color: context.corPrimaria,
          backgroundColor: context.bgCard,
          onRefresh: () async {
            ref.invalidate(versiculoProvider);
            ref.invalidate(proximaEscalaProvider);
            ref.invalidate(proximasAtividadesProvider);
            ref.invalidate(kpiMesProvider);
            if (nomeMembro.isNotEmpty) {
              ref.invalidate(compromissosDoMembroProvider(nomeMembro));
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return _buildWebLayout(context, nomeMembro);
              }
              return _buildMobileLayout(context, nomeMembro);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, String nomeMembro) {
    final versiculo = ref.watch(versiculoProvider);
    final proxima = ref.watch(proximaEscalaProvider);
    final prefs = ref.watch(homePreferencesProvider);
    final proximasAtividades = ref.watch(proximasAtividadesProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          if (nomeMembro.isNotEmpty)
            _animated(0, _HeroMinhaProximaEscala(nomeMembro: nomeMembro)),
          _animated(1, _buildVersiculoBanner(context, versiculo)),
          if (prefs.mostrarEventos) ...[
            _animated(2, _ProximoEventoCard(atividades: proximasAtividades)),
            const SizedBox(height: 16),
          ],
          if (prefs.mostrarEscalas) ...[
            _animated(3, _ProximaEscalaCard(proxima: proxima)),
            const SizedBox(height: 16),
          ],
          if (prefs.mostrarJejum) ...[
            _animated(4, const _JejumDoDiaCard()),
            const SizedBox(height: 16),
          ],
          if (prefs.mostrarRelatorio) ...[
            _animated(5, const _RelatorioEscalasCard()),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context, String nomeMembro) {
    final versiculo = ref.watch(versiculoProvider);
    final proxima = ref.watch(proximaEscalaProvider);
    final prefs = ref.watch(homePreferencesProvider);
    final proximasAtividades = ref.watch(proximasAtividadesProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (nomeMembro.isNotEmpty)
                      _animated(
                        0,
                        _HeroMinhaProximaEscala(nomeMembro: nomeMembro),
                      ),
                    _animated(1, _buildVersiculoBanner(context, versiculo)),
                    if (prefs.mostrarEventos) ...[
                      _animated(
                        2,
                        _ProximoEventoCard(atividades: proximasAtividades),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (prefs.mostrarJejum) ...[
                      _animated(4, const _JejumDoDiaCard()),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (prefs.mostrarEscalas) ...[
                      Text(
                        'Próximas Escalas',
                        style: AppTextStyles.heading(
                          color: context.textoPrimario,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _animated(3, _ProximaEscalaCard(proxima: proxima)),
                      const SizedBox(height: 20),
                    ],
                    if (prefs.mostrarRelatorio) ...[
                      _animated(5, const _RelatorioEscalasCard()),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Hero Card: Próximo Compromisso Pessoal do Membro ────────────────────────
class _HeroMinhaProximaEscala extends ConsumerWidget {
  final String nomeMembro;
  const _HeroMinhaProximaEscala({required this.nomeMembro});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItens = ref.watch(compromissosDoMembroProvider(nomeMembro));

    return asyncItens.when(
      data: (todos) {
        final now = DateTime.now();
        final hoje = DateTime(now.year, now.month, now.day);

        final futuros = todos.where((e) {
          final d = DateTime.tryParse(e.data);
          if (d == null) return false;
          final dNorm = DateTime(d.year, d.month, d.day);
          return !dNorm.isBefore(hoje);
        }).toList();

        futuros.sort((a, b) {
          final cmp = a.data.compareTo(b.data);
          if (cmp != 0) return cmp;
          return a.horario.compareTo(b.horario);
        });

        if (futuros.isEmpty) return const SizedBox.shrink();

        final prox = futuros.first;
        final dataObj = DateTime.parse(prox.data);
        final dataNorm = DateTime(dataObj.year, dataObj.month, dataObj.day);
        final amanha = hoje.add(const Duration(days: 1));

        String quandoLabel;
        if (dataNorm == hoje) {
          quandoLabel = 'HOJE';
        } else if (dataNorm == amanha) {
          quandoLabel = 'AMANHÃ';
        } else {
          quandoLabel =
              DateFormat("EEE, dd 'de' MMM", 'pt_BR').format(dataObj).toUpperCase();
        }

        // Agrupa todas as funções do membro nesse mesmo culto/horário
        final funcoesMesmoCulto = futuros
            .where((x) => x.data == prox.data && x.horario == prox.horario)
            .map((x) => x.funcao)
            .toSet()
            .join(' • ');

        final tituloPrincipal =
            prox.tema.trim().isNotEmpty ? prox.tema : prox.ministerio;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: context.heroGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.acento.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'SUA PRÓXIMA ESCALA • $quandoLabel',
                      style: AppTextStyles.label(color: Colors.white)
                          .copyWith(fontSize: 12),
                    ),
                  ),
                  if (prox.horario.isNotEmpty)
                    Text(
                      prox.horario,
                      style: AppTextStyles.mono(color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                tituloPrincipal,
                style: AppTextStyles.heading(color: Colors.white)
                    .copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                '${prox.ministerio} • $funcoesMesmoCulto',
                style: AppTextStyles.body(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AppNavigation.of(context)?.go(2);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(PhosphorIconsBold.musicNotes, size: 18),
                      label: const Text('Músicas & Cifras'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () {
                      ref.read(globalSelectedDateProvider.notifier).state =
                          dataObj;
                      AppNavigation.of(context)?.go(1);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Ver Escala'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─── Próxima Escala Card (Geral por Ministério) ──────────────────────────────
class _ProximaEscalaCard extends ConsumerWidget {
  final AsyncValue<List<EscalaItem>> proxima;
  const _ProximaEscalaCard({required this.proxima});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return proxima.when(
      data: (lista) {
        if (lista.isEmpty) return const SizedBox();

        final Map<String, List<EscalaItem>> porMinisterio = {};
        for (var e in lista) {
          porMinisterio.putIfAbsent(e.ministerio, () => []).add(e);
        }

        final ministeriosList = porMinisterio.keys.toList();
        final ministeriosAsync = ref.watch(ministeriosProvider);
        final ministeriosMap = ministeriosAsync.maybeWhen(
          data: (mins) => {for (var m in mins) m.nome: m},
          orElse: () => <String, Ministerio>{},
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...ministeriosList.map((min) => _CardMinisterioInterno(
                  nomeMinisterio: min,
                  itens: porMinisterio[min]!,
                  ministerioObj: ministeriosMap[min],
                )),
          ],
        );
      },
      loading: () => const _ShimmerBox(height: 160),
      error: (err, stack) => AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              'Erro ao carregar escala.',
              style: AppTextStyles.body(color: AppColors.perigo),
            ),
            const SizedBox(height: 4),
            Text(
              err.toString(),
              style: AppTextStyles.bodySmall(color: context.textoSecund),
              maxLines: 2,
            ),
            TextButton(
              onPressed: () => ref.invalidate(proximaEscalaProvider),
              child: const Text('Recarregar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardMinisterioInterno extends StatefulWidget {
  final String nomeMinisterio;
  final List<EscalaItem> itens;
  final Ministerio? ministerioObj;

  const _CardMinisterioInterno({
    required this.nomeMinisterio,
    required this.itens,
    this.ministerioObj,
  });

  @override
  State<_CardMinisterioInterno> createState() => _CardMinisterioInternoState();
}

class _CardMinisterioInternoState extends State<_CardMinisterioInterno> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<EscalaItem>> ocorrencias = {};
    for (var e in widget.itens) {
      final key = '${e.data}_${e.horario}';
      ocorrencias.putIfAbsent(key, () => []).add(e);
    }
    final chaves = ocorrencias.keys.toList();
    if (chaves.isEmpty) return const SizedBox();

    final safePage = _currentPage.clamp(0, chaves.length - 1);
    final itensDaPagina = ocorrencias[chaves[safePage]] ?? [];
    final primeiroPagina = itensDaPagina.first;
    final dataAtual = DateTime.parse(primeiroPagina.data);
    final temTema = primeiroPagina.tema.isNotEmpty;

    // Altura confortável para fontes grandes + avatares (48px por membro + cabeçalho da data)
    final double alturaCalculada =
        46.0 + (temTema ? 26.0 : 0.0) + (itensDaPagina.length * 50.0) + 12.0;

    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do Ministério
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.acentoSuave,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.ministerioObj?.iconData ??
                            PhosphorIconsBold.usersThree,
                        size: 20,
                        color: context.acentoTexto,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.nomeMinisterio,
                        style: AppTextStyles.subheading(
                          color: context.textoPrimario,
                        ).copyWith(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              _buildTagHeader(context, dataAtual),
            ],
          ),
          const SizedBox(height: 14),

          // Carrossel de Datas
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: alturaCalculada,
            child: PageView.builder(
              controller: _pageController,
              itemCount: chaves.length,
              onPageChanged: (v) => setState(() => _currentPage = v),
              itemBuilder: (context, idx) {
                final chave = chaves[idx];
                final itensDaData = ocorrencias[chave]!;
                final primeiro = itensDaData.first;
                final data = DateTime.parse(primeiro.data);
                final dataStr =
                    DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(data);

                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dataStr,
                              style: AppTextStyles.bodySmall(
                                color: context.textoSecund,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (primeiro.horario.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.acentoSuave,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                primeiro.horario,
                                style: AppTextStyles.monoSmall(
                                  color: context.acentoTexto,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (primeiro.tema.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          primeiro.tema,
                          style: AppTextStyles.bodySmall(
                            color: context.textoPrimario,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      ...itensDaData.map((e) {
                        final isFalta =
                            e.statusConvite == 'FALTA' || e.nome == '[FALTA]';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              AppAvatar(
                                name: e.nome,
                                size: 38,
                                accentColor:
                                    isFalta ? AppColors.perigo : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.nome,
                                  style: AppTextStyles.body(
                                    color: isFalta
                                        ? AppColors.perigo
                                        : context.textoPrimario,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: context.bgSubtle,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  e.funcao,
                                  style: AppTextStyles.label(
                                    color: context.textoSecund,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
          if (chaves.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  chaves.length > 6 ? 6 : chaves.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: safePage == i ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: safePage == i
                          ? context.corPrimaria
                          : context.textoMuted.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Próximo Evento Card ─────────────────────────────────────────────────────
class _ProximoEventoCard extends StatefulWidget {
  final AsyncValue<List<Map<String, dynamic>>> atividades;
  const _ProximoEventoCard({required this.atividades});

  @override
  State<_ProximoEventoCard> createState() => _ProximoEventoCardState();
}

class _ProximoEventoCardState extends State<_ProximoEventoCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: widget.atividades.when(
        data: (lista) {
          if (lista.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIconsFill.calendarStar,
                      color: context.corPrimaria,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Agenda da Igreja',
                      style: AppTextStyles.subheading(
                        color: context.textoPrimario,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Nenhum evento próximo programado.',
                  style: AppTextStyles.body(color: context.textoSecund),
                ),
              ],
            );
          }

          final Map<String, List<Map<String, dynamic>>> porDia = {};
          for (var e in lista) {
            final data = e['data'] as DateTime;
            final key = DateFormat('yyyy-MM-dd').format(data);
            porDia.putIfAbsent(key, () => []).add(e);
          }
          final dias = porDia.keys.toList();
          final safePage = _currentPage.clamp(0, dias.length - 1);
          final eventosDoDiaAtual = porDia[dias[safePage]]?.length ?? 0;
          final double alturaCalculada = (eventosDoDiaAtual * 62.0) + 6;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsFill.calendarStar,
                        color: context.corPrimaria,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Agenda da Igreja',
                        style: AppTextStyles.subheading(
                          color: context.textoPrimario,
                        ),
                      ),
                    ],
                  ),
                  if (dias.isNotEmpty)
                    _buildTagHeader(
                      context,
                      porDia[dias[safePage]]!.first['data'] as DateTime,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: alturaCalculada,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: dias.length,
                  onPageChanged: (v) => setState(() => _currentPage = v),
                  itemBuilder: (context, idx) {
                    final diaKey = dias[idx];
                    final eventosDoDia = porDia[diaKey]!;

                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        children: eventosDoDia.map((e) {
                          final item = e['item'] as AgendaItem;
                          final data = e['data'] as DateTime;
                          final dataStr =
                              DateFormat('dd/MM (EEEE)', 'pt_BR').format(data);

                          IconData icone = PhosphorIconsBold.church;
                          Color cor = context.corPrimaria;
                          if (item.tipo == TipoAgenda.evento) {
                            icone = PhosphorIconsBold.calendarStar;
                            cor = AppColors.alerta;
                          } else if (item.tipo == TipoAgenda.reuniao) {
                            icone = PhosphorIconsBold.usersThree;
                            cor = AppColors.acentoAzul;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: cor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(icone, color: cor, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.titulo,
                                        style: AppTextStyles.body(
                                          color: context.textoPrimario,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$dataStr • ${item.horario}',
                                        style: AppTextStyles.bodySmall(
                                          color: context.textoSecund,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
              if (dias.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      dias.length > 6 ? 6 : dias.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: safePage == i ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: safePage == i
                              ? context.corPrimaria
                              : context.textoMuted.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const _ShimmerBox(height: 100),
        error: (_, __) => Text(
          'Erro ao carregar agenda.',
          style: AppTextStyles.body(color: AppColors.perigo),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _ShimmerBox extends StatelessWidget {
  final double height;
  const _ShimmerBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.bgSubtle,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

class _JejumDoDiaCard extends ConsumerStatefulWidget {
  const _JejumDoDiaCard();

  @override
  ConsumerState<_JejumDoDiaCard> createState() => _JejumDoDiaCardState();
}

class _JejumDoDiaCardState extends ConsumerState<_JejumDoDiaCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jejumAsync = ref.watch(proximosJejunsProvider);
    const jejumColor = Color(0xFFDB2777);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: jejumAsync.when(
        data: (lista) {
          if (lista.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsFill.handsPraying,
                      color: jejumColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Escala de Jejum',
                      style: AppTextStyles.subheading(
                        color: context.textoPrimario,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Nenhum jejum escalado nos próximos dias.',
                  style: AppTextStyles.body(color: context.textoSecund),
                ),
              ],
            );
          }

          final Map<String, List<EscalaItem>> grupos = {};
          for (var e in lista) {
            grupos.putIfAbsent(e.data, () => []).add(e);
          }
          final chaves = grupos.keys.toList()..sort();
          final safePage = _currentPage.clamp(0, chaves.length - 1);
          final eventosDoDiaAtual = grupos[chaves[safePage]]?.length ?? 0;
          final double alturaCalculada = (eventosDoDiaAtual * 48.0) + 38;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.handsPraying,
                        color: jejumColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Escala de Jejum',
                        style: AppTextStyles.subheading(
                          color: context.textoPrimario,
                        ),
                      ),
                    ],
                  ),
                  _buildTagHeader(context, DateTime.parse(chaves[safePage])),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: alturaCalculada,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: chaves.length,
                  onPageChanged: (v) => setState(() => _currentPage = v),
                  itemBuilder: (context, idx) {
                    final chave = chaves[idx];
                    final itens = grupos[chave]!;
                    final data = DateTime.parse(chave);
                    final dataStr =
                        DateFormat('dd/MM (EEEE)', 'pt_BR').format(data);

                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dataStr,
                            style: AppTextStyles.bodySmall(
                              color: context.textoSecund,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...itens.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    AppAvatar(
                                      name: e.nome,
                                      size: 36,
                                      accentColor: jejumColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        e.nome,
                                        style: AppTextStyles.body(
                                          color: context.textoPrimario,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (chaves.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      chaves.length > 6 ? 6 : chaves.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: safePage == i ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: safePage == i
                              ? jejumColor
                              : context.textoMuted.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const _ShimmerBox(height: 100),
        error: (_, __) => Text(
          'Erro ao carregar escala de jejum.',
          style: AppTextStyles.body(color: AppColors.perigo),
        ),
      ),
    );
  }
}

// ─── Relatório de Escalas ─────────────────────────────────────────────────────
class _RelatorioEscalasCard extends ConsumerWidget {
  const _RelatorioEscalasCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final escalaAsync = ref.watch(escalaDoMesProvider);
    final prefs = ref.watch(homePreferencesProvider);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsFill.chartBar,
                color: context.corPrimaria,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Participações no Mês',
                style: AppTextStyles.subheading(color: context.textoPrimario),
              ),
            ],
          ),
          const SizedBox(height: 14),
          escalaAsync.when(
            data: (lista) {
              final listaFiltrada = prefs.ministeriosVisiveis.isEmpty
                  ? lista
                  : lista
                      .where(
                          (e) => prefs.ministeriosVisiveis.contains(e.ministerio))
                      .toList();

              if (listaFiltrada.isEmpty) {
                return Text(
                  'Nenhuma escala gerada no mês.',
                  style: AppTextStyles.body(color: context.textoSecund),
                );
              }

              final Map<String, int> contagem = {};
              for (var e in listaFiltrada) {
                if (e.nome != '[FALTA]' && e.funcao != 'Jejum') {
                  contagem[e.nome] = (contagem[e.nome] ?? 0) + 1;
                }
              }

              if (contagem.isEmpty) {
                return Text(
                  'Nenhum membro escalado.',
                  style: AppTextStyles.body(color: context.textoSecund),
                );
              }

              final ranking = contagem.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ranking.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 18, color: context.bgBorda),
                itemBuilder: (context, i) {
                  final item = ranking[i];
                  return Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}º',
                          style: AppTextStyles.monoSmall(
                            color: context.textoSecund,
                          ),
                        ),
                      ),
                      AppAvatar(name: item.key, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.key,
                          style: AppTextStyles.body(
                            color: context.textoPrimario,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.acentoSuave,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${item.value}x',
                          style: AppTextStyles.label(color: context.acentoTexto),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => SizedBox(
              height: 36,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.corPrimaria,
                ),
              ),
            ),
            error: (_, __) => Text(
              'Erro ao carregar participações.',
              style: AppTextStyles.body(color: AppColors.perigo),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildTagHeader(BuildContext context, DateTime data) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final d = DateTime(data.year, data.month, data.day);

  String? tag;
  if (d == today) {
    tag = 'HOJE';
  } else if (d == tomorrow) {
    tag = 'AMANHÃ';
  }

  if (tag == null) return const SizedBox();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: context.acentoSuave,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      tag,
      style: AppTextStyles.label(color: context.acentoTexto)
          .copyWith(fontSize: 12),
    ),
  );
}

// Navegação global (herdável via InheritedWidget simplificado)
class AppNavigation extends InheritedWidget {
  final void Function(int) go;

  const AppNavigation({super.key, required this.go, required super.child});

  static AppNavigation? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppNavigation>();

  @override
  bool updateShouldNotify(AppNavigation oldWidget) => false;
}
