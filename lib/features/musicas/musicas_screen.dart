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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Músicas', style: AppTextStyles.heading()),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.acento,
          labelColor: AppColors.acento,
          unselectedLabelColor: context.textoSecund,
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
            ? FloatingActionButton(
                onPressed: () => _addMusica(context),
                child: const Icon(PhosphorIconsBold.plus),
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
          color: AppColors.acento,
          backgroundColor: context.bgCard,
          onRefresh: () async => ref.invalidate(musicasProvider),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: busca,
                  style: AppTextStyles.body(),
                  decoration: InputDecoration(
                    hintText: 'Buscar músicas...',
                    prefixIcon: Icon(PhosphorIconsBold.magnifyingGlass,
                        color: context.textoSecund, size: 18),
                    suffixIcon: busca.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: context.textoSecund, size: 18),
                            onPressed: () => busca.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filtrada.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) => _MusicaTile(
                    musica: filtrada[i],
                    onEdit: () async {
                      final ok = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _ModalEditMusica(musica: filtrada[i]),
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
    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: AppColors.acento,
            foregroundColor: Colors.white,
            icon: PhosphorIconsBold.pencil,
            label: 'Editar',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.perigo,
            foregroundColor: Colors.white,
            icon: PhosphorIconsBold.trash,
            label: 'Excluir',
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.acento.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(PhosphorIconsBold.musicNote,
              color: AppColors.acento, size: 18),
        ),
        title: Text(musica.titulo, style: AppTextStyles.body()),
        subtitle: Text('${musica.artista}${musica.tempo.isNotEmpty ? ' • ${musica.tempo}' : ''}', style: AppTextStyles.bodySmall()),
        onTap: () {
          String? videoId;
          if (musica.linkYoutube.isNotEmpty) {
            final uri = Uri.tryParse(musica.linkYoutube);
            if (uri != null) {
              if (uri.queryParameters.containsKey('v')) videoId = uri.queryParameters['v'];
              else if (uri.host == 'youtu.be') videoId = uri.pathSegments.firstOrNull;
            }
          }
          CifraBottomSheet.mostrar(
            context,
            titulo: musica.titulo,
            artista: musica.artista,
            videoId: videoId,
            linkYoutube: musica.linkYoutube.isNotEmpty ? musica.linkYoutube : null,
          );
        },
        trailing: IconButton(
          icon: Icon(
            PhosphorIconsBold.youtubeLogo,
            color: musica.linkYoutube.isNotEmpty ? AppColors.perigo : context.textoSecund,
            size: 22,
          ),
          onPressed: () async {
            if (musica.linkYoutube.isNotEmpty) {
              final uri = Uri.parse(musica.linkYoutube);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            } else {
              final query = Uri.encodeComponent('${musica.titulo} ${musica.artista}');
              final uri = Uri.parse('https://www.youtube.com/results?search_query=$query');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            }
          },
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Atuais e Futuros'),
                    selected: _filtro == 'futuros',
                    onSelected: (val) => setState(() => _filtro = 'futuros'),
                    selectedColor: AppColors.acento.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: _filtro == 'futuros' ? AppColors.acento : context.textoSecund,
                      fontWeight: _filtro == 'futuros' ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Passados'),
                    selected: _filtro == 'passados',
                    onSelected: (val) => setState(() => _filtro = 'passados'),
                    selectedColor: AppColors.acento.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: _filtro == 'passados' ? AppColors.acento : context.textoSecund,
                      fontWeight: _filtro == 'passados' ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.acento,
                backgroundColor: context.bgCard,
                onRefresh: () async => ref.invalidate(repertoriosProvider),
                child: listaFiltrada.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(PhosphorIconsBold.musicNotes, color: AppColors.textoMuted, size: 48),
                            const SizedBox(height: 12),
                            Text('Nenhum repertório $_filtro encontrado.',
                                style: const TextStyle(color: AppColors.textoMuted)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: listaFiltrada.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final rep = listaFiltrada[i];
                          String tituloCulto = 'Repertório Sem Título';
                          final d = DateTime.parse(rep.dataCulto);
                          final w = d.weekday == 7 ? 0 : d.weekday;
                          
                          try {
                            final match = agenda.firstWhere((ag) => ag.diaSemana == w && ag.horario == rep.horaCulto);
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(PhosphorIconsBold.musicNotes,
              color: AppColors.acentoAzul, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTextStyles.body(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('$dataFmt às ${rep.horaCulto}', style: AppTextStyles.monoSmall(color: context.textoSecund)),
                const SizedBox(height: 4),
                Text('${rep.listaMusicas.length} música(s)',
                    style: AppTextStyles.label(color: AppColors.acento)),
              ],
            ),
          ),
          const Icon(PhosphorIconsBold.caretRight,
              color: AppColors.textoMuted, size: 16),
        ]),
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

  const _ModalAddMusica({
    required this.initialTitle,
    required this.initialLink,
    required this.initialArtist,
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

  @override
  void initState() {
    super.initState();
    _titulo = TextEditingController(text: widget.initialTitle);
    _artista = TextEditingController(text: widget.initialArtist);
    _link = TextEditingController(text: widget.initialLink);
    _tempo = TextEditingController(text: '');
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20 + MediaQuery.of(context).padding.bottom,
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
                Text('Adicionar Música', style: AppTextStyles.heading()),
                const SizedBox(height: 20),
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
      await ref.read(musicasRepoProvider).inserir({
        'titulo': _titulo.text.trim(),
        'artista': _artista.text.trim(),
        'link_youtube': _link.text.trim(),
        'tempo': _tempo.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  @override
  void initState() {
    super.initState();
    _titulo = TextEditingController(text: widget.musica.titulo);
    _artista = TextEditingController(text: widget.musica.artista);
    _link = TextEditingController(text: widget.musica.linkYoutube);
    _tempo = TextEditingController(text: widget.musica.tempo);
  }

  @override
  void dispose() {
    _titulo.dispose();
    _artista.dispose();
    _link.dispose();
    _tempo.dispose();
    super.dispose();
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20 + MediaQuery.of(context).padding.bottom,
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
                Text('Editar Música', style: AppTextStyles.heading()),
                const SizedBox(height: 20),
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
                  // O link pode ser alterado, mas o foco principal é o título
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
      await ref.read(musicasRepoProvider).atualizar(widget.musica.id, {
        'titulo': _titulo.text.trim(),
        'artista': _artista.text.trim(),
        'link_youtube': _link.text.trim(),
        'tempo': _tempo.text.trim(),
      });
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
  late final yt_explode.YoutubeExplode _yt;

  @override
  void initState() {
    super.initState();
    _yt = yt_explode.YoutubeExplode(httpClient: yt_explode.YoutubeHttpClient(CorsClient()));
    _busca = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) {
      _fazerBusca();
    }
  }

  @override
  void dispose() {
    _busca.dispose();
    _yt.close();
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
        }
      }

      final searchList = await _yt.search.search(queryText);
      setState(() {
        _resultados = searchList.map((v) => {
          'title': v.title,
          'url': 'https://www.youtube.com/watch?v=${v.id.value}',
          'author': v.author,
          'duration': v.duration?.toString().split('.').first ?? '',
        }).toList();
      });
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
