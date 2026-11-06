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
    try {
      await CifraCacheRepository().confirmar(
        videoId: widget.videoId!,
        nomeCifra: titulo,
        artistaCifra: artista,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Nome confirmado para todos!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context, rootNavigator: true).pop();
        final urlFinal = LetrasUtils.montarUrl(_tipo, titulo, artista);
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
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Título da música
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.titulo,
                style: AppTextStyles.subheading(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.artista,
                style: AppTextStyles.bodySmall(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 12),

            // ── Botão Ouvir no YouTube ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _abrirYoutube,
                  icon: const Icon(Icons.play_circle_outline,
                      color: Color(0xFFFF0000), size: 20),
                  label: const Text(
                    'Ouvir no YouTube',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF0000)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

            const Divider(
                color: Colors.white12, height: 24, indent: 20, endIndent: 20),

            // Seletor Letra / Cifra
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _TipoChip(
                    label: 'Letra',
                    icon: Icons.music_note,
                    selecionado: _tipo == 'letra',
                    onTap: () => setState(() {
                      _tipo = 'letra';
                      _resolucao = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _TipoChip(
                    label: 'Cifra',
                    icon: Icons.library_music,
                    selecionado: _tipo == 'cifra',
                    onTap: () => setState(() {
                      _tipo = 'cifra';
                      _resolucao = null;
                    }),
                  ),
                  const Spacer(),
                  // Botão "Corrigir nome"
                  TextButton.icon(
                    onPressed: () => setState(() => _editando = !_editando),
                    icon: const Icon(Icons.edit, size: 14, color: Colors.white54),
                    label: Text(
                      'Corrigir nome',
                      style: AppTextStyles.label(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),

            // Campo de edição manual
            if (_editando) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _ctrlTitulo,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nome da música',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.acento)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ctrlArtista,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Artista',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.acento)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _resolver(
                              tituloManual: _ctrlTitulo.text.trim(),
                              artistaManual: _ctrlArtista.text.trim(),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.acento,
                              side: const BorderSide(color: AppColors.acento),
                            ),
                            child: const Text('🔍 Buscar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.videoId != null)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _confirmarNome(
                                _ctrlTitulo.text.trim(),
                                _ctrlArtista.text.trim(),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                              ),
                              child: const Text('✅ Confirmar',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _tipo == 'letra' ? 'Buscar Letra' : 'Buscar Cifra',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

            // Loading
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.acento)),
              ),

            // Resultado do pipeline
            if (_resolucao != null && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ResultadoWidget(
                  resolucao: _resolucao!,
                  tipo: _tipo,
                  onAbrir: _abrirUrl,
                  onSugestaoTap: (s) {
                    _ctrlTitulo.text = s.titulo;
                    _ctrlArtista.text = s.artista;
                    final url = LetrasUtils.montarUrl(_tipo, s.titulo, s.artista);
                    _abrirUrl(url);
                  },
                ),
              ),

            const SizedBox(height: 8),
          ],
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
      // Fallback: só mostra opção de busca manual
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠️ Não encontramos automaticamente. Abra a busca no site:',
            style: TextStyle(color: Colors.orange, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onAbrir(resolucao.url),
              icon: const Icon(Icons.search, color: Colors.white),
              label: Text(
                  'Buscar ${tipo == "letra" ? "Letra" : "Cifra"} no site',
                  style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ),
        ],
      );
    }

    // Sugestões fuzzy
    if (resolucao.sugestoes.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Você quis dizer...?',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          ...resolucao.sugestoes.map((s) => _SugestaoTile(
                sugestao: s,
                tipo: tipo,
                onTap: () => onSugestaoTap(s),
              )),
        ],
      );
    }

    // Encontrou URL direto
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '✅ ${resolucao.titulo}',
          style: AppTextStyles.subheading(color: Colors.greenAccent),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(resolucao.artista,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => onAbrir(resolucao.url),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.acento,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Abrir ${tipo == "letra" ? "Letra" : "Cifra"}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
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
    return Card(
      color: const Color(0xFF2A2A3E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.queue_music, color: AppColors.acento),
        title: Text(sugestao.titulo,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(sugestao.artista,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios,
            color: Colors.white38, size: 14),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selecionado ? AppColors.acento : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selecionado ? AppColors.acento : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: selecionado ? Colors.white : Colors.white54),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: selecionado ? Colors.white : Colors.white54,
                    fontSize: 13,
                    fontWeight: selecionado ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
