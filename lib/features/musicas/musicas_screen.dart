import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;
import '../../core/utils/cors_client.dart';
import '../../core/utils/letras_utils.dart';
import '../../core/utils/titulo_normalizer.dart';
import '../../core/repositories/cifra_cache_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/musica.dart';
import '../../core/models/repertorio.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/cifra_bottom_sheet.dart';
import '../../shared/widgets/modal_selecionar_musica.dart';


class MusicasScreen extends ConsumerStatefulWidget {
  const MusicasScreen({super.key});

  @override
  ConsumerState<MusicasScreen> createState() => _MusicasScreenState();
}

class _MusicasScreenState extends ConsumerState<MusicasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _busca = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _busca
        .addListener(() => setState(() => _filtro = _busca.text.toLowerCase()));
  }

  @override
  void dispose() {
    _tab.dispose();
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrincipal,
      appBar: AppBar(
        title: Text(
          'Músicas',
          style: AppTextStyles.heading(color: context.textoPrimario),
        ),
        bottom: AppSegmentedTabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Catálogo'),
            Tab(text: 'Repertórios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CatalogoTab(filtro: _filtro, busca: _busca),
          const _RepertoriosTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, __) => _tab.index == 0
            ? FloatingActionButton.extended(
                onPressed: () => _addMusica(context),
                icon: const Icon(PhosphorIconsBold.plus, size: 18),
                label: Text(
                  'Nova Música',
                  style: AppTextStyles.button(color: Colors.white),
                ),
              )
            : const SizedBox(),
      ),
    );
  }

  Future<void> _addMusica(BuildContext context) async {
    final video = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _YouTubeSearchDialog(initialQuery: ''),
    );
    
    if (video == null) return;

    if (context.mounted) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ModalAddMusica(
          initialTitle: video['title'] ?? '',
          initialLink: video['url'] ?? '',
          initialArtist: video['author'] ?? '',
          initialDuration: video['duration'] ?? '',
        ),
      );
      if (ok == true && mounted) ref.invalidate(musicasProvider);
    }
  }
}

// ─── Catálogo ─────────────────────────────────────────────────────────────────
class _CatalogoTab extends ConsumerWidget {
  final String filtro;
  final TextEditingController busca;

  const _CatalogoTab({required this.filtro, required this.busca});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicasAsync = ref.watch(musicasProvider);

    return musicasAsync.when(
      data: (lista) {
        final filtrada = filtro.isEmpty
            ? lista
            : lista
                .where((m) =>
                    m.titulo.toLowerCase().contains(filtro) ||
                    m.artista.toLowerCase().contains(filtro))
                .toList();

        return RefreshIndicator(
          color: context.corPrimaria,
          backgroundColor: context.bgCard,
          onRefresh: () async => ref.invalidate(musicasProvider),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: busca,
                  style: AppTextStyles.body(color: context.textoPrimario),
                  decoration: InputDecoration(
                    hintText: 'Buscar música ou cantor...',
                    prefixIcon: Icon(
                      PhosphorIconsBold.magnifyingGlass,
                      color: context.textoSecund,
                      size: 20,
                    ),
                    suffixIcon: busca.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: context.textoSecund,
                              size: 20,
                            ),
                            onPressed: () => busca.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: filtrada.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma música encontrada.',
                          style: AppTextStyles.body(color: context.textoSecund),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: filtrada.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _MusicaTile(
                          musica: filtrada[i],
                          onEdit: () async {
                            final ok = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) =>
                                  _ModalEditMusica(musica: filtrada[i]),
                            );
                            if (ok == true && context.mounted) {
                              ref.invalidate(musicasProvider);
                            }
                          },
                          onDelete: () async {
                            final ok = await ConfirmDialog.show(
                              context,
                              titulo: 'Excluir',
                              mensagem: 'Excluir "${filtrada[i].titulo}"?',
                              labelConfirmar: 'Excluir',
                              perigo: true,
                            );
                            if (ok) {
                              await ref
                                  .read(musicasRepoProvider)
                                  .excluir(filtrada[i].id);
                              ref.invalidate(musicasProvider);
                            }
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.acento)),
      error: (e, _) =>
          Center(child: Text('Erro: $e', style: AppTextStyles.body())),
    );
  }
}

class _MusicaTile extends StatelessWidget {
  final Musica musica;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MusicaTile({
    required this.musica,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    void abrirCifra() {
      final videoId = LetrasUtils.extrairVideoId(musica.linkYoutube);
      CifraBottomSheet.mostrar(
        context,
        titulo: musica.titulo,
        artista: musica.artista,
        videoId: videoId,
        linkYoutube: musica.linkYoutube.isNotEmpty ? musica.linkYoutube : null,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: AppColors.acento,
              foregroundColor: Colors.white,
              icon: PhosphorIconsBold.pencilSimple,
              label: 'Editar',
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: AppColors.perigo,
              foregroundColor: Colors.white,
              icon: PhosphorIconsBold.trash,
              label: 'Excluir',
            ),
          ],
        ),
        child: AppSurfaceCard(
          onTap: abrirCifra,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.acentoSuave,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  PhosphorIconsFill.musicNotes,
                  color: context.acentoTexto,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      musica.titulo,
                      style: AppTextStyles.subheading(
                        color: context.textoPrimario,
                      ).copyWith(fontSize: 16.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${musica.artista}${musica.tempo.isNotEmpty ? ' • ${musica.tempo}' : ''}',
                      style: AppTextStyles.bodySmall(
                        color: context.textoSecund,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.bgSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Cifra',
                  style: AppTextStyles.label(color: context.textoPrimario),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  PhosphorIconsFill.youtubeLogo,
                  color: musica.linkYoutube.isNotEmpty
                      ? AppColors.perigo
                      : context.textoMuted,
                  size: 24,
                ),
                onPressed: () async {
                  if (musica.linkYoutube.isNotEmpty) {
                    final uri = Uri.parse(musica.linkYoutube);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  } else {
                    final query = Uri.encodeComponent(
                        '${musica.titulo} ${musica.artista}');
                    final uri = Uri.parse(
                        'https://www.youtube.com/results?search_query=$query');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Repertórios ──────────────────────────────────────────────────────────────
class _RepertoriosTab extends ConsumerStatefulWidget {
  const _RepertoriosTab();

  @override
  ConsumerState<_RepertoriosTab> createState() => _RepertoriosTabState();
}

class _RepertoriosTabState extends ConsumerState<_RepertoriosTab> {
  String _filtro = 'futuros';

  @override
  Widget build(BuildContext context) {
    final repAsync = ref.watch(repertoriosProvider);
    final agendaAsync = ref.watch(agendaProvider);

    return repAsync.when(
      data: (lista) {
        final hoje = DateTime.now();
        final startOfToday = DateTime(hoje.year, hoje.month, hoje.day);

        // Sort descending (newest first)
        final sortedList = List<Repertorio>.from(lista)..sort((a, b) {
          final da = DateTime.parse(a.dataCulto);
          final db = DateTime.parse(b.dataCulto);
          return db.compareTo(da);
        });

        // Filter based on selected option
        final listaFiltrada = sortedList.where((r) {
          final d = DateTime.parse(r.dataCulto);
          final dData = DateTime(d.year, d.month, d.day);
          if (_filtro == 'futuros') {
            return dData.isAtSameMomentAs(startOfToday) || dData.isAfter(startOfToday);
          } else {
            return dData.isBefore(startOfToday);
          }
        }).toList();

        final agenda = agendaAsync.value ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Próximos Cultos'),
                    selected: _filtro == 'futuros',
                    onSelected: (val) => setState(() => _filtro = 'futuros'),
                    selectedColor: AppColors.acento,
                    backgroundColor: context.bgSubtle,
                    checkmarkColor: Colors.white,
                    labelStyle: AppTextStyles.bodySmall(
                      color: _filtro == 'futuros'
                          ? Colors.white
                          : context.textoSecund,
                      fontWeight: _filtro == 'futuros'
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: _filtro == 'futuros'
                          ? AppColors.acento
                          : context.bgBorda,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('Anteriores'),
                    selected: _filtro == 'passados',
                    onSelected: (val) => setState(() => _filtro = 'passados'),
                    selectedColor: AppColors.acento,
                    backgroundColor: context.bgSubtle,
                    checkmarkColor: Colors.white,
                    labelStyle: AppTextStyles.bodySmall(
                      color: _filtro == 'passados'
                          ? Colors.white
                          : context.textoSecund,
                      fontWeight: _filtro == 'passados'
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: _filtro == 'passados'
                          ? AppColors.acento
                          : context.bgBorda,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: context.corPrimaria,
                backgroundColor: context.bgCard,
                onRefresh: () async => ref.invalidate(repertoriosProvider),
                child: listaFiltrada.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIconsRegular.playlist,
                              color: context.textoMuted,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum repertório encontrado.',
                              style:
                                  AppTextStyles.body(color: context.textoSecund),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        itemCount: listaFiltrada.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final rep = listaFiltrada[i];
                          String tituloCulto = 'Culto Programado';
                          final d = DateTime.parse(rep.dataCulto);
                          final w = d.weekday == 7 ? 0 : d.weekday;

                          try {
                            final match = agenda.firstWhere((ag) =>
                                ag.diaSemana == w &&
                                ag.horario == rep.horaCulto);
                            tituloCulto = match.titulo;
                          } catch (_) {}

                          return _RepertorioTile(
                            rep: rep,
                            titulo: tituloCulto,
                            onTap: () async {
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => _ModalSetlist(rep: rep),
                              );
                              ref.invalidate(repertoriosProvider);
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
      error: (e, _) => Center(child: Text('Erro: $e', style: AppTextStyles.body())),
    );
  }
}

class _RepertorioTile extends StatelessWidget {
  final Repertorio rep;
  final String titulo;
  final VoidCallback onTap;

  const _RepertorioTile({required this.rep, required this.titulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(rep.dataCulto);
    final dataFmt = DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(date);

    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.acentoSuave,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              PhosphorIconsFill.playlist,
              color: context.acentoTexto,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppTextStyles.subheading(color: context.textoPrimario),
                ),
                const SizedBox(height: 3),
                Text(
                  '$dataFmt às ${rep.horaCulto}',
                  style: AppTextStyles.bodySmall(color: context.textoSecund),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.acentoSuave,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${rep.listaMusicas.length} mús.',
              style: AppTextStyles.label(color: context.acentoTexto),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Modal Setlist ────────────────────────────────────────────────────────────
class _ModalSetlist extends ConsumerStatefulWidget {
  final Repertorio rep;
  const _ModalSetlist({required this.rep});

  @override
  ConsumerState<_ModalSetlist> createState() => _ModalSetlistState();
}

class _ModalSetlistState extends ConsumerState<_ModalSetlist> {
  late List<Map<String, dynamic>> _lista;
  bool _loading = false;

  /// Extrai o videoId de uma URL YouTube
  static String? _extrairVideoId(String url) {
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v'];
    if (uri.host == 'youtu.be') return uri.pathSegments.firstOrNull;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _lista = List.from(widget.rep.listaMusicas);
    _enriquecerTempos();
  }

  /// Cruza o tempo do catálogo nas músicas do setlist que não têm o campo
  Future<void> _enriquecerTempos() async {
    try {
      final catalogo = await ref.read(musicasRepoProvider).getAll();
      final catalogoMap = <String, String>{};
      for (final m in catalogo) {
        catalogoMap[m.titulo.toLowerCase()] = m.tempo;
      }
      final novaLista = _lista.map((e) {
        final map = Map<String, dynamic>.from(e);
        if (map['tempo'] == null || map['tempo'].toString().isEmpty) {
          final titulo = (map['titulo'] ?? '').toString().toLowerCase();
          if (catalogoMap.containsKey(titulo)) {
            map['tempo'] = catalogoMap[titulo];
          }
        }
        return map;
      }).toList();
      if (mounted) setState(() => _lista = novaLista);
    } catch (e) {
      debugPrint('[_ModalSetlist] Erro ao enriquecer tempos: $e');
    }
  }

  String _calcularTempoTotal() {
    int totalSegundos = 0;
    for (var m in _lista) {
      final t = m['tempo']?.toString() ?? '';
      if (t.isNotEmpty) {
        final partes = t.split(':');
        if (partes.length == 2) {
          totalSegundos += (int.tryParse(partes[0]) ?? 0) * 60 + (int.tryParse(partes[1]) ?? 0);
        } else if (partes.length == 3) {
           totalSegundos += (int.tryParse(partes[0]) ?? 0) * 3600 + (int.tryParse(partes[1]) ?? 0) * 60 + (int.tryParse(partes[2]) ?? 0);
        }
      }
    }
    if (totalSegundos == 0) return '';
    final h = totalSegundos ~/ 3600;
    final m = (totalSegundos % 3600) ~/ 60;
    final s = totalSegundos % 60;
    if (h > 0) {
      return ' • ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return ' • ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: LoadingOverlay(
          loading: _loading,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Text('Setlist — ${widget.rep.dataCulto}${_calcularTempoTotal()}',
                      style: AppTextStyles.heading()),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(PhosphorIconsBold.plus,
                        color: AppColors.acento),
                    onPressed: () => _addMusica(context),
                  ),
                ]),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  onReorder: (o, n) {
                    setState(() {
                      final item = _lista.removeAt(o);
                      _lista.insert(n > o ? n - 1 : n, item);
                    });
                  },
                  itemCount: _lista.length,
                  itemBuilder: (_, i) => ListTile(
                    key: ValueKey(i),
                    leading: Text('${i + 1}',
                        style: AppTextStyles.mono(color: AppColors.acento)),
                    title: Text(_lista[i]['titulo'] ?? '',
                        style: AppTextStyles.body()),
                    subtitle: Text(_lista[i]['artista'] ?? '', style: AppTextStyles.bodySmall()),
                    onTap: () {
                      final link = _lista[i]['link']?.toString() ?? '';
                      final videoId = _extrairVideoId(link);
                      CifraBottomSheet.mostrar(
                        context,
                        titulo: _lista[i]['titulo']?.toString() ?? '',
                        artista: _lista[i]['artista']?.toString() ?? '',
                        videoId: videoId,
                        linkYoutube: link.isNotEmpty ? link : null,
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_lista[i]['tempo'] != null && _lista[i]['tempo'].toString().isNotEmpty)
                          Text(_lista[i]['tempo'].toString(), style: AppTextStyles.monoSmall(color: context.textoSecund)),
                        IconButton(
                          icon: Icon(Icons.close, color: context.textoSecund, size: 18),
                          onPressed: () => setState(() => _lista.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                ),
                child: AppButton(
                  label: 'Salvar Setlist',
                  loading: _loading,
                  onPressed: _salvar,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addMusica(BuildContext context) async {
    final musicasAsync = ref.read(musicasProvider);
    final lista = musicasAsync.value ?? [];
    final sel = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ModalSelecionarMusica(musicas: lista),
    );
    if (sel != null) setState(() => _lista.add(sel));
  }

  Future<void> _salvar() async {
    setState(() => _loading = true);
    try {
      await ref.read(repertoriosRepoProvider).upsert(
            data: widget.rep.dataCulto,
            hora: widget.rep.horaCulto,
            listaMusicas: _lista,
          );
      if (mounted) {
        AppSnackbar.show(context, 'Setlist salvo!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Modal Add Música ─────────────────────────────────────────────────────────
class _ModalAddMusica extends ConsumerStatefulWidget {
  final String initialTitle;
  final String initialLink;
  final String initialArtist;
  final String initialDuration;

  const _ModalAddMusica({
    required this.initialTitle,
    required this.initialLink,
    required this.initialArtist,
    this.initialDuration = '',
  });

  @override
  ConsumerState<_ModalAddMusica> createState() => _ModalAddMusicaState();
}

class _ModalAddMusicaState extends ConsumerState<_ModalAddMusica> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titulo;
  late TextEditingController _artista;
  late TextEditingController _link;
  late TextEditingController _tempo;
  bool _loading = false;
  bool _inspecionando = false;
  bool _oficialYoutube = false;
  ResultadoCifraClub? _cifraVinculada;
  List<ResultadoCifraClub> _opcoesCifra = const [];

  @override
  void initState() {
    super.initState();
    final preliminar = extrairDoTituloYt(
      tituloYt: widget.initialTitle,
      nomeCanal: widget.initialArtist,
    );
    _titulo = TextEditingController(text: preliminar.titulo);
    _artista = TextEditingController(text: preliminar.artista);
    _link = TextEditingController(text: widget.initialLink);
    _tempo = TextEditingController(
      text: LetrasUtils.formatarDuracao(widget.initialDuration),
    );
    _inspecionarAutomaticamente();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _artista.dispose();
    _link.dispose();
    _tempo.dispose();
    super.dispose();
  }

  Future<void> _inspecionarAutomaticamente() async {
    final videoId = LetrasUtils.extrairVideoId(widget.initialLink);
    setState(() => _inspecionando = true);
    try {
      final info = await LetrasUtils.inspecionarVideoYoutube(
        videoId: videoId,
        tituloBruto: widget.initialTitle,
        canalBruto: widget.initialArtist,
        duracaoBruta: widget.initialDuration,
      );
      if (!mounted) return;
      setState(() {
        if (info.titulo.isNotEmpty) _titulo.text = info.titulo;
        if (info.artista.isNotEmpty) _artista.text = info.artista;
        if (_tempo.text.trim().isEmpty && info.duracao.isNotEmpty) {
          _tempo.text = info.duracao;
        }
        _oficialYoutube = info.oficialYoutube;
        _cifraVinculada = info.cifraPrincipal;
        _opcoesCifra = info.opcoesCifra;
      });
    } finally {
      if (mounted) setState(() => _inspecionando = false);
    }
  }

  Future<void> _revalidarCifraManual() async {
    final tit = _titulo.text.trim();
    final art = _artista.text.trim();
    if (tit.isEmpty) return;
    setState(() => _inspecionando = true);
    try {
      final hits = await consultarCifraClub(titulo: tit, artista: art);
      if (!mounted) return;
      setState(() {
        _cifraVinculada = hits.isNotEmpty ? hits.first : null;
        _opcoesCifra = hits.take(4).toList();
      });
    } finally {
      if (mounted) setState(() => _inspecionando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            20 +
            MediaQuery.of(context).padding.bottom,
      ),
      child: LoadingOverlay(
        loading: _loading,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: context.bgBorda,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          Text('Adicionar Música', style: AppTextStyles.heading()),
                    ),
                    if (_oficialYoutube)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.acento.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.acento.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '🎵 Tag Oficial YT',
                          style: AppTextStyles.label(color: AppColors.acento),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _StatusCifraCard(
                  inspecionando: _inspecionando,
                  cifraVinculada: _cifraVinculada,
                  opcoes: _opcoesCifra,
                  onRevalidar: _revalidarCifraManual,
                  onSelecionarOpcao: (op) {
                    setState(() {
                      _cifraVinculada = op;
                      _titulo.text = limparTitulo(op.titulo);
                      _artista.text = op.artista;
                    });
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Título *',
                  controller: _titulo,
                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(label: 'Artista', controller: _artista),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Tempo de Duração (ex: 04:30)',
                  controller: _tempo,
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Link YouTube',
                  controller: _link,
                  readOnly: true,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Salvar',
                  loading: _loading,
                  onPressed: _salvar,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final tituloLimpo = _titulo.text.trim();
      final artistaLimpo = _artista.text.trim();
      final link = _link.text.trim();

      await ref.read(musicasRepoProvider).inserir({
        'titulo': tituloLimpo,
        'artista': artistaLimpo,
        'link_youtube': link,
        'tempo': _tempo.text.trim(),
      });

      final videoId = LetrasUtils.extrairVideoId(link);
      if (videoId != null && videoId.isNotEmpty) {
        final nomeCifra = _cifraVinculada != null
            ? limparTitulo(_cifraVinculada!.titulo)
            : tituloLimpo;
        final artistaCifra = _cifraVinculada != null
            ? _cifraVinculada!.artista
            : artistaLimpo;
        await CifraCacheRepository().confirmar(
          videoId: videoId,
          nomeCifra: nomeCifra,
          artistaCifra: artistaCifra,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Card de Status da Cifra e Tag Oficial ───────────────────────────────────
class _StatusCifraCard extends StatelessWidget {
  final bool inspecionando;
  final ResultadoCifraClub? cifraVinculada;
  final List<ResultadoCifraClub> opcoes;
  final VoidCallback onRevalidar;
  final ValueChanged<ResultadoCifraClub> onSelecionarOpcao;

  const _StatusCifraCard({
    required this.inspecionando,
    required this.cifraVinculada,
    required this.opcoes,
    required this.onRevalidar,
    required this.onSelecionarOpcao,
  });

  @override
  Widget build(BuildContext context) {
    if (inspecionando) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.acento.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.acento.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.acento,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Extraindo metadados oficiais do YouTube e validando cifra...',
                style: AppTextStyles.bodySmall(color: context.textoSecund),
              ),
            ),
          ],
        ),
      );
    }

    final encontrou = cifraVinculada != null;
    final cor = encontrou ? AppColors.sucesso : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                encontrou ? Icons.check_circle : Icons.info_outline,
                color: cor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  encontrou
                      ? 'Cifra localizada: ${cifraVinculada!.titulo} — ${cifraVinculada!.artista}'
                      : 'Cifra não localizada automaticamente. Ajuste Título/Artista e toque em Revalidar.',
                  style: AppTextStyles.bodySmall(color: context.textoPrimario),
                ),
              ),
              TextButton.icon(
                onPressed: onRevalidar,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.refresh, size: 15, color: AppColors.acento),
                label: Text(
                  'Revalidar',
                  style: AppTextStyles.label(color: AppColors.acento),
                ),
              ),
            ],
          ),
          if (opcoes.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: opcoes.map((op) {
                final selecionado = cifraVinculada?.artistaSlug == op.artistaSlug &&
                    cifraVinculada?.musicaSlug == op.musicaSlug;
                return ChoiceChip(
                  label: Text(
                    '${op.titulo} (${op.artista})',
                    style: AppTextStyles.bodySmall(
                      color: selecionado ? Colors.white : context.textoPrimario,
                      fontWeight:
                          selecionado ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: selecionado,
                  selectedColor: AppColors.acento,
                  checkmarkColor: Colors.white,
                  onSelected: (_) => onSelecionarOpcao(op),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Modal Editar Música ──────────────────────────────────────────────────────
class _ModalEditMusica extends ConsumerStatefulWidget {
  final Musica musica;
  const _ModalEditMusica({required this.musica});

  @override
  ConsumerState<_ModalEditMusica> createState() => _ModalEditMusicaState();
}

class _ModalEditMusicaState extends ConsumerState<_ModalEditMusica> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titulo;
  late TextEditingController _artista;
  late TextEditingController _link;
  late TextEditingController _tempo;
  bool _loading = false;
  bool _inspecionando = false;
  bool _oficialYoutube = false;
  ResultadoCifraClub? _cifraVinculada;
  List<ResultadoCifraClub> _opcoesCifra = const [];

  @override
  void initState() {
    super.initState();
    _titulo = TextEditingController(text: widget.musica.titulo);
    _artista = TextEditingController(text: widget.musica.artista);
    _link = TextEditingController(text: widget.musica.linkYoutube);
    _tempo = TextEditingController(text: widget.musica.tempo);
    _validarCifraAtual();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _artista.dispose();
    _link.dispose();
    _tempo.dispose();
    super.dispose();
  }

  Future<void> _validarCifraAtual() async {
    if (_titulo.text.trim().isEmpty) return;
    setState(() => _inspecionando = true);
    try {
      final hits = await consultarCifraClub(
        titulo: _titulo.text.trim(),
        artista: _artista.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _cifraVinculada = hits.isNotEmpty ? hits.first : null;
        _opcoesCifra = hits.take(4).toList();
      });
    } finally {
      if (mounted) setState(() => _inspecionando = false);
    }
  }

  Future<void> _extrairDoYoutube() async {
    final videoId = LetrasUtils.extrairVideoId(_link.text);
    if (videoId == null || videoId.isEmpty) {
      await _validarCifraAtual();
      return;
    }
    setState(() => _inspecionando = true);
    try {
      final info = await LetrasUtils.inspecionarVideoYoutube(
        videoId: videoId,
        tituloBruto: _titulo.text,
        canalBruto: _artista.text,
        duracaoBruta: _tempo.text,
      );
      if (!mounted) return;
      setState(() {
        if (info.titulo.isNotEmpty) _titulo.text = info.titulo;
        if (info.artista.isNotEmpty) _artista.text = info.artista;
        if (_tempo.text.trim().isEmpty && info.duracao.isNotEmpty) {
          _tempo.text = info.duracao;
        }
        _oficialYoutube = info.oficialYoutube;
        _cifraVinculada = info.cifraPrincipal;
        _opcoesCifra = info.opcoesCifra;
      });
    } finally {
      if (mounted) setState(() => _inspecionando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final temLinkYt = LetrasUtils.extrairVideoId(_link.text) != null;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            20 +
            MediaQuery.of(context).padding.bottom,
      ),
      child: LoadingOverlay(
        loading: _loading,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: context.bgBorda,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text('Editar Música', style: AppTextStyles.heading()),
                    ),
                    if (_oficialYoutube)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.acento.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.acento.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '🎵 Tag Oficial YT',
                          style: AppTextStyles.label(color: AppColors.acento),
                        ),
                      )
                    else if (temLinkYt)
                      TextButton.icon(
                        onPressed: _inspecionando ? null : _extrairDoYoutube,
                        icon: const Icon(Icons.auto_fix_high,
                            size: 16, color: AppColors.acento),
                        label: Text(
                          'Auto-limpar pelo YT',
                          style: AppTextStyles.label(color: AppColors.acento),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatusCifraCard(
                  inspecionando: _inspecionando,
                  cifraVinculada: _cifraVinculada,
                  opcoes: _opcoesCifra,
                  onRevalidar: _validarCifraAtual,
                  onSelecionarOpcao: (op) {
                    setState(() {
                      _cifraVinculada = op;
                      _titulo.text = limparTitulo(op.titulo);
                      _artista.text = op.artista;
                    });
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Título *',
                  controller: _titulo,
                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(label: 'Artista', controller: _artista),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Tempo de Duração (ex: 04:30)',
                  controller: _tempo,
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Link YouTube',
                  controller: _link,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Salvar Alterações',
                  loading: _loading,
                  onPressed: _salvar,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final tituloLimpo = _titulo.text.trim();
      final artistaLimpo = _artista.text.trim();
      final link = _link.text.trim();

      await ref.read(musicasRepoProvider).atualizar(widget.musica.id, {
        'titulo': tituloLimpo,
        'artista': artistaLimpo,
        'link_youtube': link,
        'tempo': _tempo.text.trim(),
      });

      final videoId = LetrasUtils.extrairVideoId(link);
      if (videoId != null && videoId.isNotEmpty) {
        final nomeCifra = _cifraVinculada != null
            ? limparTitulo(_cifraVinculada!.titulo)
            : tituloLimpo;
        final artistaCifra = _cifraVinculada != null
            ? _cifraVinculada!.artista
            : artistaLimpo;
        await CifraCacheRepository().confirmar(
          videoId: videoId,
          nomeCifra: nomeCifra,
          artistaCifra: artistaCifra,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Diálogo de Busca do YouTube ─────────────────────────────────────────────
class _YouTubeSearchDialog extends StatefulWidget {
  final String initialQuery;
  const _YouTubeSearchDialog({required this.initialQuery});

  @override
  State<_YouTubeSearchDialog> createState() => _YouTubeSearchDialogState();
}

class _YouTubeSearchDialogState extends State<_YouTubeSearchDialog> {
  late TextEditingController _busca;
  bool _loading = false;
  List<Map<String, String>> _resultados = [];
  yt_explode.YoutubeExplode? _yt;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _yt = yt_explode.YoutubeExplode(httpClient: yt_explode.YoutubeHttpClient(CorsClient()));
    }
    _busca = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) {
      _fazerBusca();
    }
  }

  @override
  void dispose() {
    _busca.dispose();
    _yt?.close();
    super.dispose();
  }

  Future<void> _fazerBusca() async {
    final queryText = _busca.text.trim();
    if (queryText.isEmpty) return;
    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        final queryParam = Uri.encodeComponent(queryText);
        final url = Uri.base.resolve('/api/youtube_search?q=$queryParam');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body) as List;
          setState(() {
            _resultados = data.map((v) => {
              'title': v['title']?.toString() ?? '',
              'url': v['url']?.toString() ?? '',
              'author': v['author']?.toString() ?? '',
              'duration': v['duration']?.toString() ?? '',
            }).toList();
          });
          return;
        } else {
          throw Exception('Falha ao consultar servidor (${response.statusCode})');
        }
      }

      if (_yt != null) {
        final searchList = await _yt!.search.search(queryText);
        setState(() {
          _resultados = searchList.map((v) => {
            'title': v.title,
            'url': 'https://www.youtube.com/watch?v=${v.id.value}',
            'author': v.author,
            'duration': v.duration?.toString().split('.').first ?? '',
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro ao buscar: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text('Buscar no YouTube', style: AppTextStyles.heading()),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _busca,
              style: AppTextStyles.body(color: context.textoPrimario),
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
                hintStyle: AppTextStyles.body(color: context.textoSecund),
                suffixIcon: IconButton(
                  icon: const Icon(PhosphorIconsBold.magnifyingGlass),
                  onPressed: _fazerBusca,
                ),
              ),
              onSubmitted: (_) => _fazerBusca(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.acento))
                  : _resultados.isEmpty
                      ? Center(child: Text('Nenhum resultado.', style: AppTextStyles.body(color: context.textoPrimario)))
                      : ListView.separated(
                          itemCount: _resultados.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: context.bgBorda),
                          itemBuilder: (context, i) {
                            final item = _resultados[i];
                            return ListTile(
                              dense: true,
                              title: Text(item['title'] ?? '', style: AppTextStyles.body(color: context.textoPrimario), maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${item['author']} • ${item['duration']}', style: AppTextStyles.bodySmall(color: context.textoSecund)),
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
