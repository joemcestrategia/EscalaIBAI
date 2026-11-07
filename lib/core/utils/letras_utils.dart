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

class InspecaoVideoYoutube {
  final String titulo;
  final String artista;
  final String duracao;
  final bool oficialYoutube;
  final ResultadoCifraClub? cifraPrincipal;
  final List<ResultadoCifraClub> opcoesCifra;

  const InspecaoVideoYoutube({
    required this.titulo,
    required this.artista,
    this.duracao = '',
    this.oficialYoutube = false,
    this.cifraPrincipal,
    this.opcoesCifra = const [],
  });
}

class LetrasUtils {
  // ─── Extração de VideoId e Formatação de Duração ─────────────────────────
  static String? extrairVideoId(String url) {
    if (url.trim().isEmpty) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (uri.queryParameters.containsKey('v')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
    }
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    final shortsIdx = uri.pathSegments.indexOf('shorts');
    if (shortsIdx != -1 && uri.pathSegments.length > shortsIdx + 1) {
      return uri.pathSegments[shortsIdx + 1];
    }
    return null;
  }

  static String formatarDuracao(String raw) {
    final t = raw.trim().split('.').first;
    if (t.isEmpty) return '';
    final partes = t.split(':');
    if (partes.length == 3) {
      final h = int.tryParse(partes[0]) ?? 0;
      final m = (int.tryParse(partes[1]) ?? 0).toString().padLeft(2, '0');
      final s = (int.tryParse(partes[2]) ?? 0).toString().padLeft(2, '0');
      if (h > 0) return '${h.toString().padLeft(2, '0')}:$m:$s';
      return '$m:$s';
    }
    if (partes.length == 2) {
      final m = (int.tryParse(partes[0]) ?? 0).toString().padLeft(2, '0');
      final s = (int.tryParse(partes[1]) ?? 0).toString().padLeft(2, '0');
      return '$m:$s';
    }
    return t;
  }

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

  /// Resolve a URL real no CifraClub (respeitando slugs especiais como "coral-kemuel" ou "a-ele-gloria"),
  /// caindo no montarUrl padrão caso offline.
  static Future<String> montarUrlInteligente(
    String tipo,
    String titulo,
    String artista,
  ) async {
    final hits = await consultarCifraClub(titulo: titulo, artista: artista);
    if (hits.isNotEmpty) {
      return hits.first.montarUrl(tipo);
    }
    return montarUrl(tipo, titulo, artista);
  }

  // ─── Verifica existência via HTTP HEAD ───────────────────────────────────
  static Future<String?> _urlExiste(String urlStr) async {
    if (urlStr.contains('.br//') || urlStr.endsWith('.br/')) return null;
    if (kIsWeb) return urlStr;
    try {
      final uri = Uri.parse(urlStr);
      final request = http.Request('HEAD', uri)
        ..followRedirects = true
        ..maxRedirects = 3
        ..headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
      final response = await http
          .Client()
          .send(request)
          .timeout(const Duration(seconds: 8));
      final finalUrl = response.request?.url.toString() ?? urlStr;
      debugPrint('[LetrasUtils] HEAD finalizado → $finalUrl');
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return finalUrl;
      }
      return null;
    } catch (e) {
      debugPrint('[LetrasUtils] HEAD falhou: $e');
      return null;
    }
  }

  // ─── Inspeção completa no Cadastro/Edição de Música ──────────────────────
  /// Extrai metadados oficiais do YouTube (`video.musicData` / Content ID) e já pré-localiza a cifra no CifraClub.
  static Future<InspecaoVideoYoutube> inspecionarVideoYoutube({
    String? videoId,
    required String tituloBruto,
    required String canalBruto,
    String duracaoBruta = '',
  }) async {
    TituloArtista extraido = extrairDoTituloYt(
      tituloYt: tituloBruto,
      nomeCanal: canalBruto,
    );
    String duracao = formatarDuracao(duracaoBruta);

    if (videoId != null && videoId.isNotEmpty) {
      yt.YoutubeExplode? ytClient;
      try {
        ytClient = yt.YoutubeExplode(
          httpClient: yt.YoutubeHttpClient(CorsClient()),
        );
        final video =
            await ytClient.videos.get(videoId).timeout(kExternalTimeout);

        if (duracao.isEmpty && video.duration != null) {
          duracao = formatarDuracao(video.duration.toString());
        }

        // 1. Prioridade máxima: Tag Oficial de Música do YouTube (Content ID / musicData)
        final oficiais = extrairDeMusicDataYt(video.musicData);
        if (oficiais.isNotEmpty) {
          extraido = oficiais.first;
        } else {
          // 2. Canal Topic / Descrição / Título do vídeo
          extraido = extrairDoTituloYt(
            tituloYt: video.title,
            nomeCanal: video.author,
            descricao: video.description,
          );
        }
      } catch (e) {
        debugPrint('[LetrasUtils] inspecionarVideoYoutube falhou no YT: $e');
      } finally {
        ytClient?.close();
      }
    }

    // 3. Pré-valida no índice oficial do CifraClub
    var opcoes = await consultarCifraClub(
      titulo: extraido.titulo,
      artista: extraido.artista,
    );

    // Se a heurística inverteu artista/música em vídeo não-oficial, tenta invertido
    if (opcoes.isEmpty &&
        !extraido.oficialYoutube &&
        extraido.artista.isNotEmpty) {
      opcoes = await consultarCifraClub(
        titulo: extraido.artista,
        artista: extraido.titulo,
      );
      if (opcoes.isNotEmpty) {
        extraido = TituloArtista(
          titulo: limparTitulo(opcoes.first.titulo),
          artista: opcoes.first.artista,
          origem: 'cifraclub_busca',
        );
      }
    }

    // Se ainda não achou e não veio da tag oficial, tenta Deezer para descobrir o nome limpo
    if (opcoes.isEmpty && !extraido.oficialYoutube) {
      final deezer =
          await consultarDeezer('${extraido.titulo} ${extraido.artista}'.trim());
      if (deezer != null) {
        extraido = deezer;
        opcoes = await consultarCifraClub(
          titulo: deezer.titulo,
          artista: deezer.artista,
        );
      }
    }

    final principal = opcoes.isNotEmpty ? opcoes.first : null;
    final tituloFinal = extraido.oficialYoutube
        ? extraido.titulo
        : (principal != null ? limparTitulo(principal.titulo) : extraido.titulo);
    final artistaFinal = extraido.oficialYoutube && extraido.artista.isNotEmpty
        ? extraido.artista
        : (principal != null ? principal.artista : extraido.artista);

    return InspecaoVideoYoutube(
      titulo: tituloFinal,
      artista: artistaFinal,
      duracao: duracao,
      oficialYoutube: extraido.oficialYoutube,
      cifraPrincipal: principal,
      opcoesCifra: opcoes.take(4).toList(),
    );
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
        if (cached.confirmado) {
          final url = await montarUrlInteligente(
            tipo,
            cached.nomeCifra,
            cached.artistaCifra,
          );
          return ResolucaoCifra(
            titulo: cached.nomeCifra,
            artista: cached.artistaCifra,
            url: url,
            origem: cached.origem,
            confirmado: true,
          );
        }
      }
    }

    // ── Camada 2: Tag Oficial `musicData` e Metadados YouTube ────────────
    TituloArtista? extraido;
    if (videoId != null && videoId.isNotEmpty) {
      yt.YoutubeExplode? ytClient;
      try {
        ytClient = yt.YoutubeExplode(
          httpClient: yt.YoutubeHttpClient(CorsClient()),
        );
        final video =
            await ytClient.videos.get(videoId).timeout(kExternalTimeout);

        // 2a. Tag Oficial de Música do YouTube (Content ID / musicData)
        final faixasOficiais = extrairDeMusicDataYt(video.musicData);
        if (faixasOficiais.isNotEmpty) {
          extraido = faixasOficiais.first;
          debugPrint(
            '[Pipeline] Camada 2a (Tag Oficial musicData) → $extraido',
          );

          final hitsCifra = await consultarCifraClub(
            titulo: extraido.titulo,
            artista: extraido.artista,
          );

          // Se for medley com múltiplas faixas no Content ID, monta sugestões das demais faixas
          final sugestoesMedley = <TituloArtista>[];
          if (faixasOficiais.length > 1) {
            for (final f in faixasOficiais) {
              final fHits = await consultarCifraClub(
                titulo: f.titulo,
                artista: f.artista,
              );
              if (fHits.isNotEmpty) {
                sugestoesMedley.add(
                  fHits.first.toTituloArtista(
                    origem: 'descricao_youtube',
                    oficialYoutube: true,
                  ),
                );
              } else {
                sugestoesMedley.add(f);
              }
            }
          }

          if (hitsCifra.isNotEmpty) {
            final top = hitsCifra.first;
            await repo.upsert(CifraCache(
              videoId: videoId,
              nomeCifra: extraido.titulo,
              artistaCifra:
                  extraido.artista.isNotEmpty ? extraido.artista : top.artista,
              origem: 'descricao_youtube',
              confirmado: false,
              updatedAt: DateTime.now(),
            ));
            return ResolucaoCifra(
              titulo: top.titulo,
              artista: top.artista,
              url: top.montarUrl(tipo),
              origem: 'descricao_youtube',
              oficialYoutube: true,
              sugestoes: sugestoesMedley.length > 1 ? sugestoesMedley : const [],
            );
          }

          // Fallback HTTP HEAD caso o Solr oscile
          final urlDireta = montarUrl(tipo, extraido.titulo, extraido.artista);
          final finalUrl = await _urlExiste(urlDireta);
          if (finalUrl != null) {
            await repo.upsert(CifraCache(
              videoId: videoId,
              nomeCifra: extraido.titulo,
              artistaCifra: extraido.artista,
              origem: 'descricao_youtube',
              confirmado: false,
              updatedAt: DateTime.now(),
            ));
            return ResolucaoCifra(
              titulo: extraido.titulo,
              artista: extraido.artista,
              url: finalUrl,
              origem: 'descricao_youtube',
              oficialYoutube: true,
            );
          }
        } else {
          // 2b. Sem musicData: extrai de Canal Topic / Descrição / Título do YouTube
          extraido = extrairDoTituloYt(
            tituloYt: video.title,
            nomeCanal: video.author,
            descricao: video.description,
          );
          debugPrint('[Pipeline] Camada 2b (YouTube título/desc) → $extraido');
          if (extraido.valido) {
            final hitsCifra = await consultarCifraClub(
              titulo: extraido.titulo,
              artista: extraido.artista,
            );
            if (hitsCifra.isNotEmpty) {
              final top = hitsCifra.first;
              await repo.upsert(CifraCache(
                videoId: videoId,
                nomeCifra: limparTitulo(top.titulo),
                artistaCifra: top.artista,
                origem: extraido.origem,
                confirmado: false,
                updatedAt: DateTime.now(),
              ));
              return ResolucaoCifra(
                titulo: top.titulo,
                artista: top.artista,
                url: top.montarUrl(tipo),
                origem: extraido.origem,
                oficialYoutube: extraido.oficialYoutube,
              );
            }

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
                oficialYoutube: extraido.oficialYoutube,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[Pipeline] Camada 2 falhou: $e');
      } finally {
        ytClient?.close();
      }
    }

    // ── Camada 3: Busca direta no CifraClub + Normalização do título ─────
    final normalizado = extraido ??
        TituloArtista(
          titulo: limparTitulo(titulo),
          artista: limparArtista(artista),
          origem: 'titulo_limpo',
        );

    final hitsCamada3 = await consultarCifraClub(
      titulo: normalizado.titulo,
      artista: normalizado.artista,
    );
    if (hitsCamada3.isNotEmpty) {
      final top = hitsCamada3.first;
      debugPrint('[Pipeline] Camada 3 (CifraClub direto) → ${top.titulo}');
      if (videoId != null && videoId.isNotEmpty) {
        await repo.upsert(CifraCache(
          videoId: videoId,
          nomeCifra: limparTitulo(top.titulo),
          artistaCifra: top.artista,
          origem: 'titulo_limpo',
          confirmado: false,
          updatedAt: DateTime.now(),
        ));
      }
      return ResolucaoCifra(
        titulo: top.titulo,
        artista: top.artista,
        url: top.montarUrl(tipo),
        origem: 'titulo_limpo',
        oficialYoutube: normalizado.oficialYoutube,
      );
    }

    // Tenta invertido no CifraClub (caso artista e música estejam trocados)
    if (normalizado.artista.isNotEmpty) {
      final hitsSwapped = await consultarCifraClub(
        titulo: normalizado.artista,
        artista: normalizado.titulo,
      );
      if (hitsSwapped.isNotEmpty) {
        final top = hitsSwapped.first;
        debugPrint('[Pipeline] Camada 3 (CifraClub swap) → ${top.titulo}');
        if (videoId != null && videoId.isNotEmpty) {
          await repo.upsert(CifraCache(
            videoId: videoId,
            nomeCifra: limparTitulo(top.titulo),
            artistaCifra: top.artista,
            origem: 'titulo_limpo_swapped',
            confirmado: false,
            updatedAt: DateTime.now(),
          ));
        }
        return ResolucaoCifra(
          titulo: top.titulo,
          artista: top.artista,
          url: top.montarUrl(tipo),
          origem: 'titulo_limpo_swapped',
        );
      }
    }

    final url3 = montarUrl(tipo, normalizado.titulo, normalizado.artista);
    debugPrint('[Pipeline] Camada 3 (HEAD fallback) → $url3');
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
      );
    }

    // ── Camada 4: Deezer API → CifraClub ─────────────────────────────────
    final queryDeezer = '${normalizado.titulo} ${normalizado.artista}'.trim();
    debugPrint('[Pipeline] Camada 4 (Deezer) → query: $queryDeezer');
    final deezer = await consultarDeezer(queryDeezer);
    if (deezer != null) {
      final hitsDeezer = await consultarCifraClub(
        titulo: deezer.titulo,
        artista: deezer.artista,
      );
      if (hitsDeezer.isNotEmpty) {
        final top = hitsDeezer.first;
        if (videoId != null && videoId.isNotEmpty) {
          await repo.upsert(CifraCache(
            videoId: videoId,
            nomeCifra: limparTitulo(top.titulo),
            artistaCifra: top.artista,
            origem: 'catalogo_externo',
            confirmado: false,
            updatedAt: DateTime.now(),
          ));
        }
        return ResolucaoCifra(
          titulo: top.titulo,
          artista: top.artista,
          url: top.montarUrl(tipo),
          origem: 'catalogo_externo',
        );
      }

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
      final url5 = await montarUrlInteligente(
        tipo,
        melhor.titulo,
        melhor.artista,
      );
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
    const mode = LaunchMode.externalApplication;
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
  final bool oficialYoutube;
  final bool isFallback;
  final List<TituloArtista> sugestoes;

  const ResolucaoCifra({
    required this.titulo,
    required this.artista,
    required this.url,
    required this.origem,
    this.confirmado = false,
    this.oficialYoutube = false,
    this.isFallback = false,
    this.sugestoes = const [],
  });
}
