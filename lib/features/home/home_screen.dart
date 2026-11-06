import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/ministerio.dart';
import '../../core/models/escala_item.dart';
import '../../core/models/agenda_item.dart';

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
      duration: const Duration(milliseconds: 1200),
    );
    _fades = List.generate(
      5,
      (i) => Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(i * 0.2, (i * 0.2 + 0.6).clamp(0.0, 1.0),
            curve: Curves.easeOut),
      )),
    );
    _slides = List.generate(
      5,
      (i) => Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(i * 0.2, (i * 0.2 + 0.6).clamp(0.0, 1.0),
            curve: Curves.easeOut),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.acento,
          backgroundColor: Theme.of(context).colorScheme.surface,
          onRefresh: () async {
            ref.invalidate(versiculoProvider);
            ref.invalidate(proximaEscalaProvider);
            ref.invalidate(proximasAtividadesProvider);
            ref.invalidate(kpiMesProvider);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return _buildWebLayout(context);
              }
              return _buildMobileLayout(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final hoje = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());
    final versiculo = ref.watch(versiculoProvider);
    final proxima = ref.watch(proximaEscalaProvider);
    final prefs = ref.watch(homePreferencesProvider);
    final proximasAtividades = ref.watch(proximasAtividadesProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.acento.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.acento.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.church, color: AppColors.acento, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_saudacao(), style: AppTextStyles.subheading()),
                    Text(hoje, style: AppTextStyles.bodySmall()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          versiculo.when(
            data: (v) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.acento.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.acento.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${v['texto']}"',
                    style: AppTextStyles.bodySmall(color: context.textoPrimario).copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    v['ref'] ?? '',
                    style: AppTextStyles.monoSmall(color: AppColors.acento),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 16),
          if (prefs.mostrarEventos) ...[
            _animated(1, _ProximoEventoCard(atividades: proximasAtividades)),
            const SizedBox(height: 16),
          ],
          if (prefs.mostrarEscalas) ...[
            _animated(2, _ProximaEscalaCard(proxima: proxima)),
            const SizedBox(height: 16),
          ],
          if (prefs.mostrarJejum) ...[
            _animated(3, const _JejumDoDiaCard()),
            const SizedBox(height: 24),
          ],
          if (prefs.mostrarRelatorio) ...[
            _animated(4, const _RelatorioEscalasCard()),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    final hoje = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());
    final versiculo = ref.watch(versiculoProvider);
    final proxima = ref.watch(proximaEscalaProvider);
    final prefs = ref.watch(homePreferencesProvider);
    final proximasAtividades = ref.watch(proximasAtividadesProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna 1: Saudação + Agenda + Jejum (Largura fixa ~320)
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.acento.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.acento.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.church, color: AppColors.acento, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_saudacao(), style: AppTextStyles.subheading().copyWith(fontSize: 22)),
                          Text(hoje, style: AppTextStyles.bodySmall()),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (prefs.mostrarEventos) ...[
                  _animated(1, _ProximoEventoCard(atividades: proximasAtividades)),
                  const SizedBox(height: 16),
                ],
                if (prefs.mostrarJejum) ...[
                  _animated(3, const _JejumDoDiaCard()),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Coluna 2: Feed/Versículo e Próximas Escalas (Flexível)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                versiculo.when(
                  data: (v) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.acento.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.acento.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"${v['texto']}"',
                          style: AppTextStyles.body(color: context.textoPrimario).copyWith(fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          v['ref'] ?? '',
                          style: AppTextStyles.monoSmall(color: AppColors.acento),
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 24),
                if (prefs.mostrarEscalas) ...[
                  Text('Escalas Atuais', style: AppTextStyles.subheading(color: context.textoPrimario)),
                  const SizedBox(height: 16),
                  _animated(2, _ProximaEscalaCard(proxima: proxima)),
                  const SizedBox(height: 24),
                ],
                if (prefs.mostrarRelatorio) ...[
                  _animated(4, const _RelatorioEscalasCard()),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}




// ─── Próxima Escala Card ──────────────────────────────────────────────────────
class _ProximaEscalaCard extends ConsumerWidget {
  final AsyncValue<List<EscalaItem>> proxima;
  const _ProximaEscalaCard({required this.proxima});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return proxima.when(
      data: (lista) {
        if (lista.isEmpty) return const SizedBox();

        // Agrupa por Ministério
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
      loading: () => const _ShimmerBox(height: 150),
      error: (err, stack) => Column(
        children: [
          Text('Erro ao carregar escala.', style: AppTextStyles.body(color: AppColors.perigo)),
          Text(err.toString(), style: AppTextStyles.bodySmall(color: context.textoSecund), maxLines: 2),
          TextButton(onPressed: () => ref.invalidate(proximaEscalaProvider), child: const Text('Recarregar')),
        ],
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
    // Agrupa os itens deste ministério por Data/Horário para as páginas do carrossel
    final Map<String, List<EscalaItem>> ocorrencias = {};
    for (var e in widget.itens) {
      final key = '${e.data}_${e.horario}';
      ocorrencias.putIfAbsent(key, () => []).add(e);
    }
    final chaves = ocorrencias.keys.toList();
    
    // Calcula a tag para a página atual
    String? tag;
    if (chaves.isNotEmpty) {
      final data = DateTime.parse(ocorrencias[chaves[_currentPage]]!.first.data);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final compareDate = DateTime(data.year, data.month, data.day);
      if (compareDate == today) {
        tag = 'HOJE';
      } else if (compareDate == tomorrow) {
        tag = 'AMANHÃ';
      }
    }

    // Calcula a altura ideal para os membros
    if (chaves.isEmpty) return const SizedBox();
    
    final itensDaPagina = ocorrencias[chaves[_currentPage]] ?? [];
    final temTema = itensDaPagina.isNotEmpty && itensDaPagina.first.tema.isNotEmpty;
    // Base: data/hora(20) + tema(20) + margens(20) + itens(n * 28)
    final double alturaCalculada = 40.0 + (temTema ? 20.0 : 0.0) + (itensDaPagina.length * 28.0) + 20.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight),
      ),
      child: Column(
        children: [
          // Header Fixo do Ministério
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        widget.ministerioObj?.iconData ?? PhosphorIconsBold.usersThree,
                        size: 20,
                        color: AppColors.acento,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.nomeMinisterio,
                          style: AppTextStyles.heading(color: AppColors.acento).copyWith(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                if (tag != null)
                  Text(
                    tag, 
                    style: AppTextStyles.monoSmall(color: AppColors.acento).copyWith(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          
          // Carrossel de Datas
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
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
                final dataStr = DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(data);

                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          dataStr, 
                          style: AppTextStyles.mono(color: context.textoPrimario),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.acento.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(primeiro.horario, style: AppTextStyles.monoSmall(color: AppColors.acento)),
                        ),
                      ]),
                      if (primeiro.tema.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(primeiro.tema, style: AppTextStyles.bodySmall(color: context.textoSecund), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 12),
                      Column(
                        children: itensDaData.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                _getFuncaoIcon(e.funcao),
                                size: 14,
                                color: e.statusConvite == 'FALTA' ? AppColors.perigo : e.statusConvite == 'PRESENTE' ? AppColors.sucesso : context.textoSecund,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(e.nome, style: AppTextStyles.body(), overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              Text(e.funcao, style: AppTextStyles.bodySmall(color: context.textoSecund)),
                            ],
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (chaves.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  chaves.length > 5 ? 5 : chaves.length,
                  (i) => Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == i ? AppColors.acento : context.textoSecund.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getFuncaoIcon(String funcao) {
    final f = funcao.toLowerCase();
    if (f.contains('vocal') || f.contains('voz') || f.contains('ministro')) return PhosphorIconsBold.microphone;
    if (f.contains('violão') || f.contains('guitarra')) return PhosphorIconsBold.guitar;
    if (f.contains('baixo')) return PhosphorIconsBold.guitar;
    if (f.contains('teclado') || f.contains('piano')) return PhosphorIconsBold.musicNotes;
    if (f.contains('bateria')) return PhosphorIconsBold.musicNotesSimple;
    if (f.contains('mídia') || f.contains('projetor')) return PhosphorIconsBold.monitor;
    if (f.contains('som') || f.contains('mesa')) return PhosphorIconsBold.speakerHigh;
    if (f.contains('transmissão') || f.contains('câmera')) return PhosphorIconsBold.videoCamera;
    if (f.contains('recepção') || f.contains('boas vindas')) return PhosphorIconsBold.handWaving;
    if (f.contains('infantil') || f.contains('criança')) return PhosphorIconsBold.baby;
    if (f.contains('intercessão') || f.contains('oração')) return PhosphorIconsBold.handsPraying;
    return PhosphorIconsBold.user;
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.acento.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.acento.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.atividades.when(
            data: (lista) {
              if (lista.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(PhosphorIconsBold.star, color: AppColors.acento, size: 16),
                          const SizedBox(width: 6),
                          Text('Agenda da Igreja', style: AppTextStyles.label(color: AppColors.acento)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Nenhum evento próximo.', style: AppTextStyles.body()),
                  ],
                );
              }

              // Agrupa por Dia
              final Map<String, List<Map<String, dynamic>>> porDia = {};
              for (var e in lista) {
                final data = e['data'] as DateTime;
                final key = DateFormat('yyyy-MM-dd').format(data);
                porDia.putIfAbsent(key, () => []).add(e);
              }
              final dias = porDia.keys.toList();
              
              // Calcula a altura ideal com base no dia atual
              final eventosDoDiaAtual = porDia[dias[_currentPage]]?.length ?? 0;
              final double alturaCalculada = (eventosDoDiaAtual * 52.0) + 10;

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(PhosphorIconsBold.star, color: AppColors.acento, size: 16),
                        const SizedBox(width: 6),
                        Text('Agenda da Igreja', style: AppTextStyles.label(color: AppColors.acento)),
                      ]),
                      if (dias.isNotEmpty)
                        _buildTagHeader(porDia[dias[_currentPage]]!.first['data'] as DateTime),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: alturaCalculada,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: dias.length,
                      onPageChanged: (v) => setState(() => _currentPage = v),
                      itemBuilder: (context, idx) {
                        final diaKey = dias[idx];
                        final eventosDoDia = porDia[diaKey]!;
                        
                        // Tag agora é exibida no header (topo direito)

                        return SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            children: eventosDoDia.map((e) {
                              final item = e['item'] as AgendaItem;
                              final data = e['data'] as DateTime;
                              final dataStr = DateFormat('dd/MM (EEEE)', 'pt_BR').format(data);

                              IconData icone = PhosphorIconsBold.church;
                              Color cor = AppColors.acento;
                              if (item.tipo == TipoAgenda.evento) {
                                icone = PhosphorIconsBold.calendarStar;
                                cor = const Color(0xFFF59E0B);
                              } else if (item.tipo == TipoAgenda.reuniao) {
                                icone = PhosphorIconsBold.usersThree;
                                cor = AppColors.acentoAzul;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: cor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(icone, color: cor, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                              '${item.titulo} (${item.horario})', 
                                              style: AppTextStyles.body(color: context.textoPrimario).copyWith(fontWeight: FontWeight.bold),
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Text(dataStr, style: AppTextStyles.bodySmall(color: context.textoSecund)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        dias.length > 5 ? 5 : dias.length,
                        (i) => Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == i ? AppColors.acento : context.textoSecund.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const _ShimmerBox(height: 90),
            error: (_, __) => Text('Erro ao carregar agenda.', style: AppTextStyles.body()),
          ),
        ],
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
        color: context.bgBorda,
        borderRadius: BorderRadius.circular(8),
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

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? context.bgBorda
              : AppColors.bgBordaLight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          jejumAsync.when(
            data: (lista) {
              if (lista.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(PhosphorIconsBold.drop, color: Color(0xFFE83E8C), size: 16),
                          const SizedBox(width: 6),
                          Text('Escala de Jejum', style: AppTextStyles.label(color: const Color(0xFFE83E8C))),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Nenhum jejum escalado.', style: AppTextStyles.body()),
                  ],
                );
              }

              final Map<String, List<EscalaItem>> grupos = {};
              for (var e in lista) {
                grupos.putIfAbsent(e.data, () => []).add(e);
              }
              final chaves = grupos.keys.toList()..sort();
              
              // Calcula a altura ideal com base no dia atual
              final eventosDoDiaAtual = grupos[chaves[_currentPage]]?.length ?? 0;
              final double alturaCalculada = (eventosDoDiaAtual * 36.0) + 40;

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(PhosphorIconsBold.drop, color: Color(0xFFE83E8C), size: 16),
                        const SizedBox(width: 6),
                        Text('Escala de Jejum', style: AppTextStyles.label(color: const Color(0xFFE83E8C))),
                      ]),
                      if (lista.isNotEmpty)
                        _buildTagHeader(DateTime.parse(chaves[_currentPage])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: alturaCalculada,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: chaves.length,
                      onPageChanged: (v) => setState(() => _currentPage = v),
                      itemBuilder: (context, idx) {
                        final chave = chaves[idx];
                        final itens = grupos[chave]!;
                        final data = DateTime.parse(chave);
                        final dataStr = DateFormat('dd/MM (EEEE)', 'pt_BR').format(data);
                        
                        // Tag agora é exibida no header (topo direito)

                        return SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dataStr, style: AppTextStyles.monoSmall(color: context.textoSecund)),
                              const SizedBox(height: 12),
                              ...itens.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(PhosphorIconsBold.drop, size: 16, color: Color(0xFFE83E8C)),
                                    const SizedBox(width: 10),
                                    Text(e.nome, style: AppTextStyles.body(color: context.textoPrimario)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        chaves.length > 5 ? 5 : chaves.length,
                        (i) => Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == i ? const Color(0xFFE83E8C) : context.textoSecund.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const _ShimmerBox(height: 100),
            error: (_, __) => Text('Erro ao carregar.', style: AppTextStyles.body()),
          ),
        ],
      ),
    );
  }
}


// ─── Relatório de Escalas ────────────────────────────────────────────────────────
class _RelatorioEscalasCard extends ConsumerWidget {
  const _RelatorioEscalasCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final escalaAsync = ref.watch(escalaDoMesProvider);
    final prefs = ref.watch(homePreferencesProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? context.bgBorda
              : AppColors.bgBordaLight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(PhosphorIconsBold.chartBar,
                color: Color(0xFFF59E0B), size: 16),
            const SizedBox(width: 6),
            Text('Relatório de Escalas (Mês Atual)',
                style: AppTextStyles.label(color: const Color(0xFFF59E0B))),
          ]),
          const SizedBox(height: 12),
          escalaAsync.when(
            data: (lista) {
              final listaFiltrada = prefs.ministeriosVisiveis.isEmpty
                  ? lista
                  : lista.where((e) => prefs.ministeriosVisiveis.contains(e.ministerio)).toList();

              if (listaFiltrada.isEmpty) {
                return Text('Nenhuma escala gerada no mês.',
                    style: AppTextStyles.body());
              }
              
              final Map<String, int> contagem = {};
              for (var e in listaFiltrada) {
                if (e.nome != '[FALTA]' && e.funcao != 'Jejum') {
                  contagem[e.nome] = (contagem[e.nome] ?? 0) + 1;
                }
              }
              
              if (contagem.isEmpty) {
                return Text('Nenhum membro escalado.', style: AppTextStyles.body());
              }

              final ranking = contagem.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)); // Maior para o menor

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ranking.length,
                separatorBuilder: (_, __) => Divider(height: 16, color: context.bgBorda),
                itemBuilder: (context, i) {
                  final item = ranking[i];
                  return Row(
                    children: [
                      Container(
                        width: 24,
                        alignment: Alignment.center,
                        child: Text('${i + 1}º',
                            style: AppTextStyles.monoSmall(color: context.textoSecund)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item.key,
                            style: AppTextStyles.body(color: context.textoPrimario)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.acento.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item.value}x',
                          style: AppTextStyles.label(color: AppColors.acento),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const SizedBox(
              height: 30,
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.acento)),
            ),
            error: (_, __) =>
                Text('Erro ao carregar.', style: AppTextStyles.body()),
          ),
        ],
      ),
    );
  }
}

Widget _buildTagHeader(DateTime data) {
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

  return Text(
    tag,
    style: AppTextStyles.monoSmall(color: AppColors.acento).copyWith(fontWeight: FontWeight.bold),
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
