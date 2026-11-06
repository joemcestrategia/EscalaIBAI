import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../models/cifra_cache.dart';
import '../repositories/cifra_cache_repository.dart';
import '../utils/titulo_normalizer.dart';
import '../utils/cors_client.dart';

/// Ponto único de configuração da fonte de cifra/letra.
/// Troque aqui para mudar em todo o app.
const String kFonteCifra = 'letras'; // 'letras' | 'cifraclub'

class LetrasUtils {
  // ─── Formatação para URL ─────────────────────────────────────────────────
  static String formatarParaUrl(String text) {
    var s = text.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[áàâãä]'), 'a');
    s = s.replaceAll(RegExp(r'[éèêë]'), 'e');
    s = s.replaceAll(RegExp(r'[íìîï]'), 'i');
    s = s.replaceAll(RegExp(r'[óòôõö]'), 'o');
    s = s.replaceAll(RegExp(r'[úùûü]'), 'u');
    s = s.replaceAll(RegExp(r'[ç]'), 'c');
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    s = s.replaceAll(RegExp(r'\s+'), '-');
    s = s.replaceAll(RegExp(r'-+'), '-');
    if (s.startsWith('-')) s = s.substring(1);
    if (s.endsWith('-')) s = s.substring(0, s.length - 1);
    return s;
  }

  // ─── Monta URL da cifra/letra ────────────────────────────────────────────
  static String montarUrl(String tipo, String titulo, String artista) {
    final t = formatarParaUrl(titulo);
    final a = formatarParaUrl(artista);
    if (tipo == 'letra') return 'https://www.cifraclub.com.br/$a/$t/letra/';
    return 'https://www.cifraclub.com.br/$a/$t/';
  }

  // ─── Verifica existência via HTTP HEAD ───────────────────────────────────
  static Future<String?> _urlExiste(String urlStr) async {
    if (urlStr.contains('.br//') || urlStr.endsWith('.br/')) return null; // Evita homepages
    if (kIsWeb) return urlStr;
    try {
      final uri = Uri.parse(urlStr);
      final request = http.Request('HEAD', uri)
        ..followRedirects = true // SEGUE O REDIRECT PARA PEGAR A URL FINAL COM OS NÚMEROS!
        ..maxRedirects = 3
        ..headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
      final response = await http.Client().send(request).timeout(const Duration(seconds: 8));
      final finalUrl = response.request?.url.toString() ?? urlStr;
      debugPrint('[LetrasUtils] HEAD finalizado → \$finalUrl');
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return finalUrl;
      }
      return null;
    } catch (e) {
      debugPrint('[LetrasUtils] HEAD falhou: $e');
      return null; 
    }
  }

  // ─── Pipeline de resolução ───────────────────────────────────────────────
  /// Executa o pipeline completo e retorna o melhor TituloArtista encontrado.
  /// [videoId] pode ser null se a música não veio do YouTube.
  static Future<ResolucaoCifra> resolver({
    required String titulo,
    required String artista,
    String? videoId,
    String tipo = kFonteCifra,
  }) async {
    final repo = CifraCacheRepository();

    // ── Camada 1: Cache compartilhado ───────────────────────────────────
    if (videoId != null && videoId.isNotEmpty) {
      final cached = await repo.getByVideoId(videoId);
      if (cached != null && cached.nomeCifra.isNotEmpty) {
        debugPrint('[Pipeline] Camada 1 (cache) → ${cached.nomeCifra}');
        final url = montarUrl(tipo, cached.nomeCifra, cached.artistaCifra);
        if (cached.confirmado) {
          return ResolucaoCifra(
            titulo: cached.nomeCifra,
            artista: cached.artistaCifra,
            url: url,
            origem: cached.origem,
            confirmado: true,
          );
        }
        // Não confirmado: usa como sugestão mas continua o pipeline
      }
    }

    // ── Camada 2: Metadados YouTube (via youtube_explode) ────────────────
    TituloArtista? extraido;
    if (videoId != null && videoId.isNotEmpty) {
      try {
        final ytClient = yt.YoutubeExplode(
            httpClient: yt.YoutubeHttpClient(CorsClient()));
        final video = await ytClient.videos
            .get(videoId)
            .timeout(kExternalTimeout);
        ytClient.close();
        extraido = extrairDoTituloYt(
          tituloYt: video.title,
          nomeCanal: video.author,
          descricao: video.description,
        );
        debugPrint('[Pipeline] Camada 2 (YouTube) → $extraido');
        if (extraido.valido) {
          final url = montarUrl(tipo, extraido.titulo, extraido.artista);
          final finalUrl = await _urlExiste(url);
          if (finalUrl != null) {
            await repo.upsert(CifraCache(
              videoId: videoId,
              nomeCifra: extraido.titulo,
              artistaCifra: extraido.artista,
              origem: extraido.origem,
              confirmado: false,
              updatedAt: DateTime.now(),
            ));
            return ResolucaoCifra(
              titulo: extraido.titulo,
              artista: extraido.artista,
              url: finalUrl,
              origem: extraido.origem,
              confirmado: false,
            );
          }
        }
      } catch (e) {
        debugPrint('[Pipeline] Camada 2 falhou: $e');
      }
    }

    // ── Camada 3: Normalização do título sujo ────────────────────────────
    final normalizado = extraido ??
        TituloArtista(titulo: limparTitulo(titulo), artista: artista, origem: 'titulo_limpo');
    final url3 = montarUrl(tipo, normalizado.titulo, normalizado.artista);
    debugPrint('[Pipeline] Camada 3 (normalização) → $url3');
    final finalUrl3 = await _urlExiste(url3);
    if (finalUrl3 != null) {
      if (videoId != null && videoId.isNotEmpty) {
        await repo.upsert(CifraCache(
          videoId: videoId,
          nomeCifra: normalizado.titulo,
          artistaCifra: normalizado.artista,
          origem: 'titulo_limpo',
          confirmado: false,
          updatedAt: DateTime.now(),
        ));
      }
      return ResolucaoCifra(
        titulo: normalizado.titulo,
        artista: normalizado.artista,
        url: finalUrl3,
        origem: 'titulo_limpo',
        confirmado: false,
      );
    } else {
      // Tenta inverter titulo e artista (caso a heuristica do Youtube tenha falhado)
      final url3Swapped = montarUrl(tipo, normalizado.artista, normalizado.titulo);
      debugPrint('[Pipeline] Camada 3 (swap) → $url3Swapped');
      final finalUrl3Swapped = await _urlExiste(url3Swapped);
      if (finalUrl3Swapped != null) {
        if (videoId != null && videoId.isNotEmpty) {
          await repo.upsert(CifraCache(
            videoId: videoId,
            nomeCifra: normalizado.artista, // invertido
            artistaCifra: normalizado.titulo, // invertido
            origem: 'titulo_limpo_swapped',
            confirmado: false,
            updatedAt: DateTime.now(),
          ));
        }
        return ResolucaoCifra(
          titulo: normalizado.artista, // invertido
          artista: normalizado.titulo, // invertido
          url: finalUrl3Swapped,
          origem: 'titulo_limpo_swapped',
          confirmado: false,
        );
      }
    }

    // ── Camada 4: Deezer API ─────────────────────────────────────────────
    final queryDeezer = '${normalizado.titulo} ${normalizado.artista}'.trim();
    debugPrint('[Pipeline] Camada 4 (Deezer) → query: $queryDeezer');
    final deezer = await consultarDeezer(queryDeezer);
    if (deezer != null) {
      final url4 = montarUrl(tipo, deezer.titulo, deezer.artista);
      final finalUrl4 = await _urlExiste(url4);
      if (finalUrl4 != null) {
        if (videoId != null && videoId.isNotEmpty) {
          await repo.upsert(CifraCache(
            videoId: videoId,
            nomeCifra: deezer.titulo,
            artistaCifra: deezer.artista,
            origem: 'catalogo_externo',
            confirmado: false,
            updatedAt: DateTime.now(),
          ));
        }
        return ResolucaoCifra(
          titulo: deezer.titulo,
          artista: deezer.artista,
          url: finalUrl4,
          origem: 'catalogo_externo',
          confirmado: false,
        );
      }
    }

    // ── Camada 5: Fuzzy local ────────────────────────────────────────────
    final cacheCompleto = await repo.getAll();
    final query5 = '${normalizado.titulo} ${normalizado.artista}';
    final sugestoes = sugestoesFuzzy(query5, cacheCompleto);
    debugPrint('[Pipeline] Camada 5 (fuzzy) → ${sugestoes.length} sugestões');
    if (sugestoes.isNotEmpty) {
      final melhor = sugestoes.first;
      final url5 = montarUrl(tipo, melhor.titulo, melhor.artista);
      return ResolucaoCifra(
        titulo: melhor.titulo,
        artista: melhor.artista,
        url: url5,
        origem: 'fuzzy',
        confirmado: false,
        sugestoes: sugestoes,
      );
    }

    // ── Camada 6: Fallback busca ─────────────────────────────────────────
    debugPrint('[Pipeline] Camada 6 (fallback busca)');
    return ResolucaoCifra(
      titulo: normalizado.titulo,
      artista: normalizado.artista,
      url: urlBuscaFallback(tipo, normalizado.titulo, normalizado.artista),
      origem: 'fallback',
      confirmado: false,
      isFallback: true,
    );
  }

  // ─── Abrir URL ───────────────────────────────────────────────────────────
  static Future<void> abrirUrlNavegadorExterno(String urlStr) async {
    final uri = Uri.parse(urlStr);
    final mode = LaunchMode.externalApplication;
    try {
      await launchUrl(uri, mode: mode);
    } catch (e) {
      debugPrint('[LetrasUtils] Erro ao abrir URL: $e');
    }
  }
}

// ─── Resultado do pipeline ─────────────────────────────────────────────────
class ResolucaoCifra {
  final String titulo;
  final String artista;
  final String url;
  final String origem;
  final bool confirmado;
  final bool isFallback;
  final List<TituloArtista> sugestoes;

  const ResolucaoCifra({
    required this.titulo,
    required this.artista,
    required this.url,
    required this.origem,
    this.confirmado = false,
    this.isFallback = false,
    this.sugestoes = const [],
  });
}
