import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/cifra_bottom_sheet.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/modal_selecionar_musica.dart';


class ModalSetlistRapido extends ConsumerStatefulWidget {
  final String dataCulto;
  final String horaCulto;

  const ModalSetlistRapido({
    super.key,
    required this.dataCulto,
    required this.horaCulto,
  });

  @override
  ConsumerState<ModalSetlistRapido> createState() => _ModalSetlistRapidoState();
}

class _ModalSetlistRapidoState extends ConsumerState<ModalSetlistRapido> {
  List<Map<String, dynamic>> _lista = [];
  bool _loading = true;
  int _contadorId = 0;

  /// Extrai o videoId de uma URL YouTube
  static String? _extrairVideoId(String url) {
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    // https://www.youtube.com/watch?v=XXXX
    if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v'];
    // https://youtu.be/XXXX
    if (uri.host == 'youtu.be') return uri.pathSegments.firstOrNull;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _carregarRepertorio();
  }

  Future<void> _carregarRepertorio() async {
    try {
      final rep = await ref
          .read(repertoriosRepoProvider)
          .getByDataHora(widget.dataCulto, widget.horaCulto);
      
      // Carrega o catálogo para cruzar o tempo (caso o setlist foi salvo antes do campo existir)
      final catalogo = await ref.read(musicasRepoProvider).getAll();
      final catalogoMap = <String, String>{};
      for (final m in catalogo) {
        catalogoMap[m.titulo.toLowerCase()] = m.tempo;
      }
      
      if (rep != null) {
        setState(() {
          _lista = rep.listaMusicas.map((e) {
            final map = Map<String, dynamic>.from(e);
            map['id_interno'] = 'id_${_contadorId++}';
            // Recupera o tempo do catálogo se não estiver no setlist salvo
            if ((map['tempo'] == null || map['tempo'].toString().isEmpty)) {
              final titulo = (map['titulo'] ?? '').toString().toLowerCase();
              if (catalogoMap.containsKey(titulo)) {
                map['tempo'] = catalogoMap[titulo];
              }
            }
            return map;
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('[ModalSetlistRapido] Erro ao carregar: $e');
    } finally {
      setState(() => _loading = false);
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
          color: context.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: LoadingOverlay(
          loading: _loading,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.bgBorda,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Músicas do Culto',
                            style: AppTextStyles.heading(
                              color: context.textoPrimario,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.dataCulto} às ${widget.horaCulto}${_calcularTempoTotal()}',
                            style: AppTextStyles.bodySmall(
                              color: context.textoSecund,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _addMusica(context),
                      icon: const Icon(PhosphorIconsBold.plus, size: 16),
                      label: const Text('Adicionar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.bgBorda),
              Expanded(
                child: _lista.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma música adicionada ao culto.',
                          style: AppTextStyles.body(color: context.textoSecund),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        onReorder: (o, n) {
                          setState(() {
                            final item = _lista.removeAt(o);
                            _lista.insert(n > o ? n - 1 : n, item);
                          });
                        },
                        itemCount: _lista.length,
                        itemBuilder: (_, i) => ListTile(
                          key: ValueKey(_lista[i]['id_interno'] ?? 'id_$i'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.acentoSuave,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: AppTextStyles.mono(
                                color: context.acentoTexto,
                              ),
                            ),
                          ),
                          title: Text(
                            _lista[i]['titulo'] ?? '',
                            style: AppTextStyles.body(
                              color: context.textoPrimario,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            _lista[i]['artista'] ?? '',
                            style: AppTextStyles.bodySmall(
                              color: context.textoSecund,
                            ),
                          ),
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
                              if (_lista[i]['tempo'] != null &&
                                  _lista[i]['tempo'].toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.bgSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _lista[i]['tempo'].toString(),
                                    style: AppTextStyles.monoSmall(
                                      color: context.textoSecund,
                                    ),
                                  ),
                                ),
                              IconButton(
                                icon: Icon(
                                  PhosphorIconsBold.trash,
                                  color: AppColors.perigo.withValues(alpha: 0.8),
                                  size: 18,
                                ),
                                onPressed: () =>
                                    setState(() => _lista.removeAt(i)),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              SafeArea(
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: AppButton(
                    label: 'Salvar Músicas',
                    loading: _loading,
                    onPressed: _salvar,
                    width: double.infinity,
                  ),
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
    
    if (sel != null) {
      setState(() {
        final map = Map<String, dynamic>.from(sel);
        map['id_interno'] = 'id_${_contadorId++}';
        _lista.add(map);
      });
    }
  }

  Future<void> _salvar() async {
    setState(() => _loading = true);
    try {
      await ref.read(repertoriosRepoProvider).upsert(
            data: widget.dataCulto,
            hora: widget.horaCulto,
            listaMusicas: _lista,
          );
      ref.invalidate(repertoriosProvider);
      if (mounted) {
        AppSnackbar.show(context, 'Músicas salvas!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
