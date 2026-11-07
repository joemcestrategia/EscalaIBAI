import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../../core/repositories/cifra_cache_repository.dart';
import '../../core/utils/letras_utils.dart';
import '../../core/utils/titulo_normalizer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/musicas/cifra_webview_screen.dart';

/// Widget principal para abrir cifra/letra de uma música.
/// Aceita [videoId] para aproveitar o pipeline completo.
/// Se [videoId] for null, usa apenas camadas 3-6.
class CifraBottomSheet extends StatefulWidget {
  final String titulo;
  final String artista;
  final String? videoId;
  /// Link direto do YouTube (ex: https://www.youtube.com/watch?v=XXXX)
  final String? linkYoutube;

  const CifraBottomSheet({
    super.key,
    required this.titulo,
    required this.artista,
    this.videoId,
    this.linkYoutube,
  });

  /// Atalho para abrir o bottom sheet de qualquer tela
  static Future<void> mostrar(
    BuildContext context, {
    required String titulo,
    required String artista,
    String? videoId,
    String? linkYoutube,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CifraBottomSheet(
        titulo: titulo,
        artista: artista,
        videoId: videoId,
        linkYoutube: linkYoutube,
      ),
    );
  }

  @override
  State<CifraBottomSheet> createState() => _CifraBottomSheetState();
}

class _CifraBottomSheetState extends State<CifraBottomSheet> {
  // Tipo escolhido: 'letra' | 'cifra'
  String _tipo = 'letra';

  // Estado do pipeline
  bool _loading = false;
  ResolucaoCifra? _resolucao;

  // Campo de edição manual
  late TextEditingController _ctrlTitulo;
  late TextEditingController _ctrlArtista;
  bool _editando = false;

  @override
  void initState() {
    super.initState();
    _ctrlTitulo = TextEditingController(text: widget.titulo);
    _ctrlArtista = TextEditingController(text: widget.artista);
  }

  @override
  void dispose() {
    _ctrlTitulo.dispose();
    _ctrlArtista.dispose();
    super.dispose();
  }

  // ─── Pipeline ─────────────────────────────────────────────────────────
  Future<void> _resolver({String? tituloManual, String? artistaManual}) async {
    setState(() {
      _loading = true;
      _editando = false;
    });
    try {
      final resolucao = await LetrasUtils.resolver(
        titulo: tituloManual ?? widget.titulo,
        artista: artistaManual ?? widget.artista,
        videoId: widget.videoId,
        tipo: _tipo,
      );
      setState(() => _resolucao = resolucao);

      // Se confirmado, abre direto e fecha o sheet
      if (resolucao.confirmado && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CifraWebViewScreen(
              url: resolucao.url,
              title: resolucao.titulo,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[CifraBottomSheet] Erro: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirYoutube() async {
    final link = widget.linkYoutube;
    Uri uri;
    if (link != null && link.isNotEmpty) {
      uri = Uri.parse(link);
    } else {
      // Fallback: busca no YouTube pelo nome da música
      final q = Uri.encodeComponent('${widget.titulo} ${widget.artista}');
      uri = Uri.parse('https://www.youtube.com/results?search_query=$q');
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[CifraBottomSheet] Erro ao abrir YouTube: $e');
    }
  }

  Future<void> _abrirUrl(String url) async {
    Navigator.of(context, rootNavigator: true).pop();
    
    if (kIsWeb) {
      // No Flutter Web, WebView usa iframe e sofre bloqueios de CORS/X-Frame-Options
      // Por isso, abrimos em uma nova aba do navegador
      await LetrasUtils.abrirUrlNavegadorExterno(url);
    } else {
      // No Mobile (Android/iOS), a WebView nativa funciona perfeitamente
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CifraWebViewScreen(
            url: url,
            title: widget.titulo,
          ),
        ),
      );
    }
  }

  Future<void> _confirmarNome(String titulo, String artista) async {
    if (widget.videoId == null || widget.videoId!.isEmpty) return;
    setState(() => _loading = true);
    try {
      await CifraCacheRepository().confirmar(
        videoId: widget.videoId!,
        nomeCifra: titulo,
        artistaCifra: artista,
      );
      final urlFinal =
          await LetrasUtils.montarUrlInteligente(_tipo, titulo, artista);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Nome confirmado para todos!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context, rootNavigator: true).pop();
        if (kIsWeb) {
          await LetrasUtils.abrirUrlNavegadorExterno(urlFinal);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CifraWebViewScreen(
                url: urlFinal,
                title: titulo,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[CifraBottomSheet] Erro ao confirmar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: context.bgBorda,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Título da música
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.titulo,
                  style: AppTextStyles.heading(color: context.textoPrimario),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.artista,
                  style: AppTextStyles.body(color: context.textoSecund),
                ),
              ),
              const SizedBox(height: 16),

              // ── Botão Ouvir no YouTube ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _abrirYoutube,
                    icon: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.perigo,
                      size: 22,
                    ),
                    label: Text(
                      'Ouvir no YouTube',
                      style: AppTextStyles.button(color: context.textoPrimario),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.perigo.withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),

              Divider(
                color: context.bgBorda,
                height: 28,
                indent: 20,
                endIndent: 20,
              ),

              // Seletor Letra / Cifra
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _TipoChip(
                      label: 'Letra',
                      icon: Icons.music_note_rounded,
                      selecionado: _tipo == 'letra',
                      onTap: () => setState(() {
                        _tipo = 'letra';
                        _resolucao = null;
                      }),
                    ),
                    const SizedBox(width: 10),
                    _TipoChip(
                      label: 'Cifra',
                      icon: Icons.library_music_rounded,
                      selecionado: _tipo == 'cifra',
                      onTap: () => setState(() {
                        _tipo = 'cifra';
                        _resolucao = null;
                      }),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _editando = !_editando),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: context.textoSecund,
                      ),
                      label: Text(
                        'Corrigir nome',
                        style: AppTextStyles.bodySmall(
                          color: context.textoSecund,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Campo de edição manual
              if (_editando) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _ctrlTitulo,
                        style: AppTextStyles.body(color: context.textoPrimario),
                        decoration: const InputDecoration(
                          labelText: 'Nome da música',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ctrlArtista,
                        style: AppTextStyles.body(color: context.textoPrimario),
                        decoration: const InputDecoration(
                          labelText: 'Artista',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _resolver(
                                tituloManual: _ctrlTitulo.text.trim(),
                                artistaManual: _ctrlArtista.text.trim(),
                              ),
                              child: const Text('Buscar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (widget.videoId != null)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _confirmarNome(
                                  _ctrlTitulo.text.trim(),
                                  _ctrlArtista.text.trim(),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.sucesso,
                                ),
                                child: const Text('Confirmar'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Botão principal de busca
              if (_resolucao == null && !_loading && !_editando)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _resolver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.acento,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text(
                        _tipo == 'letra' ? 'Buscar Letra' : 'Buscar Cifra',
                      ),
                    ),
                  ),
                ),

              // Loading
              if (_loading)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.corPrimaria,
                    ),
                  ),
                ),

              // Resultado do pipeline
              if (_resolucao != null && !_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ResultadoWidget(
                    resolucao: _resolucao!,
                    tipo: _tipo,
                    onAbrir: _abrirUrl,
                    onSugestaoTap: (s) async {
                      _ctrlTitulo.text = s.titulo;
                      _ctrlArtista.text = s.artista;
                      final url = s.montarUrlExata(_tipo) ??
                          await LetrasUtils.montarUrlInteligente(
                            _tipo,
                            s.titulo,
                            s.artista,
                          );
                      await _abrirUrl(url);
                    },
                  ),
                ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widget de resultado ───────────────────────────────────────────────────
class _ResultadoWidget extends StatelessWidget {
  final ResolucaoCifra resolucao;
  final String tipo;
  final void Function(String url) onAbrir;
  final void Function(TituloArtista s) onSugestaoTap;

  const _ResultadoWidget({
    required this.resolucao,
    required this.tipo,
    required this.onAbrir,
    required this.onSugestaoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (resolucao.isFallback) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Não encontramos automaticamente. Abra a busca no site:',
            style: AppTextStyles.bodySmall(color: AppColors.alerta),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onAbrir(resolucao.url),
              icon: const Icon(Icons.search, color: Colors.white),
              label: Text(
                'Buscar ${tipo == "letra" ? "Letra" : "Cifra"} no site',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alerta,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (resolucao.sugestoes.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resolucao.oficialYoutube
                ? 'Músicas oficiais detectadas neste vídeo:'
                : 'Você quis dizer...?',
            style: AppTextStyles.bodySmall(
              color: context.textoSecund,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...resolucao.sugestoes.map((s) => _SugestaoTile(
                sugestao: s,
                tipo: tipo,
                onTap: () => onSugestaoTap(s),
              )),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.sucesso,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                resolucao.titulo,
                style: AppTextStyles.subheading(color: context.textoPrimario),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          resolucao.artista,
          style: AppTextStyles.bodySmall(color: context.textoSecund),
        ),
        if (resolucao.oficialYoutube) ...[
          const SizedBox(height: 6),
          Text(
            'Identificada pela tag oficial do YouTube',
            style: AppTextStyles.label(color: context.corPrimaria),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => onAbrir(resolucao.url),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.acento,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: Text(
              'Abrir ${tipo == "letra" ? "Letra" : "Cifra"}',
            ),
          ),
        ),
      ],
    );
  }
}

class _SugestaoTile extends StatelessWidget {
  final TituloArtista sugestao;
  final String tipo;
  final VoidCallback onTap;

  const _SugestaoTile({
    required this.sugestao,
    required this.tipo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.bgSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.bgBorda),
      ),
      child: ListTile(
        leading: Icon(Icons.queue_music_rounded, color: context.corPrimaria),
        title: Text(
          sugestao.titulo,
          style: AppTextStyles.body(
            color: context.textoPrimario,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          sugestao.artista,
          style: AppTextStyles.bodySmall(color: context.textoSecund),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: context.textoMuted,
          size: 15,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ─── Chip de seleção de tipo ────────────────────────────────────────────────
class _TipoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selecionado;
  final VoidCallback onTap;

  const _TipoChip({
    required this.label,
    required this.icon,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selecionado ? AppColors.acento : context.bgSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionado ? AppColors.acento : context.bgBorda,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selecionado ? Colors.white : context.textoSecund,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall(
                color: selecionado ? Colors.white : context.textoPrimario,
                fontWeight: selecionado ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
