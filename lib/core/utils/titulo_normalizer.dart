import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/cifra_cache.dart';
import 'cors_client.dart';

// ─── Configuração global do pipeline ───────────────────────────────────────
/// Limiar de similaridade fuzzy (0.0–1.0). Acima disso a sugestão é válida.
const double kFuzzyLimiar = 0.68;

/// Máximo de sugestões fuzzy a exibir
const int kMaxSugestoes = 3;

/// Timeout para chamadas externas (Deezer, CifraClub, youtube_explode)
const Duration kExternalTimeout = Duration(seconds: 6);

/// Fonte de cifra usada em toda a app. Trocar aqui muda tudo.
/// Valores: 'letras' | 'cifraclub'
const String kFonteCifra = 'letras';

// ─── Padrões de limpeza de título ──────────────────────────────────────────
final _padroesTitulo = [
  // Conteúdo entre parênteses e colchetes: (Ao Vivo), [Clipe Oficial], etc.
  RegExp(r'\([^)]*\)', caseSensitive: false),
  RegExp(r'\[[^\]]*\]', caseSensitive: false),
  // Feat / Part / Ft (sem remover a preposição "com" de títulos legítimos como "Com Muito Louvor")
  RegExp(r'\b(feat|ft|part)\.?\s+[^|,\n\-]+', caseSensitive: false),
  RegExp(r'\bc/\s+[^|,\n\-]+', caseSensitive: false),
  // Sufixos pós-pipe
  RegExp(r'\|.*$'),
  // Termos típicos de vídeos musicais soltos no final ou após traço
  RegExp(
    r'\s*[-–—]?\s*\b(clipe oficial|v[íi]deo oficial|official (music )?video|lyric video|live session|ao vivo|en vivo|playback|legendado|ac[úu]stico|acoustic|reimagined)\b.*$',
    caseSensitive: false,
  ),
  // Emojis e símbolos não-ASCII
  RegExp(r'[^\x00-\x7Fà-ÿÀ-Ÿ/+ ]'),
];

final _separadores = RegExp(r'\s*[-–—]\s*');

const _canaisGravadoras = [
  'mk music',
  'mk divulgacoes',
  'musile',
  'todah',
  'onimusic',
  'oni music',
  'sony music',
  'central gospel',
  'graca music',
  'universal music',
  'gospel hits',
  'louve',
  'adoracao',
  'cortes',
];

// ─── Data classes ──────────────────────────────────────────────────────────
class TituloArtista {
  final String titulo;
  final String artista;
  final String origem;
  final bool oficialYoutube;
  final String? artistaSlug;
  final String? musicaSlug;

  const TituloArtista({
    required this.titulo,
    required this.artista,
    required this.origem,
    this.oficialYoutube = false,
    this.artistaSlug,
    this.musicaSlug,
  });

  bool get valido => titulo.isNotEmpty;

  String? montarUrlExata(String tipo) {
    if (artistaSlug == null ||
        artistaSlug!.isEmpty ||
        musicaSlug == null ||
        musicaSlug!.isEmpty) {
      return null;
    }
    if (tipo == 'letra') {
      return 'https://www.cifraclub.com.br/$artistaSlug/$musicaSlug/letra/';
    }
    return 'https://www.cifraclub.com.br/$artistaSlug/$musicaSlug/';
  }

  @override
  String toString() =>
      '"$titulo" — "$artista" (origem: $origem, oficialYt: $oficialYoutube)';
}

/// Resultado retornado diretamente pelo índice de busca do CifraClub
class ResultadoCifraClub {
  final String titulo;
  final String artista;
  final String artistaSlug;
  final String musicaSlug;
  final double score;

  const ResultadoCifraClub({
    required this.titulo,
    required this.artista,
    required this.artistaSlug,
    required this.musicaSlug,
    this.score = 0,
  });

  String montarUrl(String tipo) {
    if (tipo == 'letra') {
      return 'https://www.cifraclub.com.br/$artistaSlug/$musicaSlug/letra/';
    }
    return 'https://www.cifraclub.com.br/$artistaSlug/$musicaSlug/';
  }

  TituloArtista toTituloArtista({
    String origem = 'cifraclub_busca',
    bool oficialYoutube = false,
  }) =>
      TituloArtista(
        titulo: titulo,
        artista: artista,
        origem: origem,
        oficialYoutube: oficialYoutube,
        artistaSlug: artistaSlug,
        musicaSlug: musicaSlug,
      );
}

// ─── Normalização base ──────────────────────────────────────────────────────
/// Remove acentos, converte para minúsculas, remove pontuação extra
String normalizarTexto(String s) {
  s = s.toLowerCase().trim();
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiioooooouuuucn';
  for (int i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }
  s = s
      .replaceAll(RegExp(r"[^\w\s]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return s;
}

/// Limpa o título do YouTube ou MusicData removendo sufixos, emojis, feat., etc.
String limparTitulo(String titulo) {
  var s = titulo;
  for (final p in _padroesTitulo) {
    s = s.replaceAll(p, '');
  }
  s = s.replaceAll(RegExp(r'^[\s\-–—:|]+|[\s\-–—:|]+$'), '');
  return s.trim().replaceAll(RegExp(r'\s{2,}'), ' ');
}

/// Limpa nome de artista vindo do YouTube ou Content ID (remove VEVO, Topic, Oficial, feats)
String limparArtista(String artista) {
  var s = artista.trim();
  if (s.startsWith('@')) s = s.substring(1);
  // Se vier múltiplos artistas separados por vírgula ou ";" no Content ID, usa o principal
  if (s.contains(',')) s = s.split(',').first.trim();
  if (s.contains(';')) s = s.split(';').first.trim();
  s = s.replaceAll(RegExp(r'\s*-\s*[Tt]opic$'), '');
  s = s.replaceAll(RegExp(r'VEVO$', caseSensitive: false), '');
  s = s.replaceAll(
      RegExp(r'\s+\b(oficial|official)\b$', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'\b(feat|ft|part)\.?\s+.*$', caseSensitive: false), '');
  return s.trim().replaceAll(RegExp(r'\s{2,}'), ' ');
}

/// Detecta se o canal é uma gravadora/distribuidora e não o próprio cantor
bool isCanalGravadora(String nomeCanal) {
  final norm = normalizarTexto(nomeCanal);
  return _canaisGravadoras.any((g) => norm.contains(g));
}

// ─── Camada 2: Extração Oficial (Content ID / MusicData) e Título do YouTube ─
/// Detecta se o canal é do tipo "Artista - Topic"
bool isCanalTopic(String nomeCanal) =>
    nomeCanal.toLowerCase().endsWith(' - topic') ||
    nomeCanal.toLowerCase().endsWith('- topic');

/// Extrai nome do artista de um canal Topic
String artistaDeCanal(String nomeCanal) => limparArtista(nomeCanal);

/// Extrai lista de músicas oficiais da tag estruturada `video.musicData` (Content ID do YouTube)
List<TituloArtista> extrairDeMusicDataYt(
  Iterable<({String? song, String? artist, String? album, Uri? image})>
      musicData,
) {
  final encontrados = <TituloArtista>[];
  final vistos = <String>{};

  for (final md in musicData) {
    final rawSong = md.song?.trim() ?? '';
    if (rawSong.isEmpty) continue;

    final titulo = limparTitulo(rawSong);
    final artista = limparArtista(md.artist ?? '');
    if (titulo.isEmpty) continue;

    final chave = '${normalizarTexto(titulo)}|${normalizarTexto(artista)}';
    if (vistos.add(chave)) {
      debugPrint(
          '[Normalizer] Tag Oficial YouTube (musicData) → "$titulo" / "$artista"');
      encontrados.add(TituloArtista(
        titulo: titulo,
        artista: artista,
        origem: 'descricao_youtube',
        oficialYoutube: true,
      ));
    }
  }

  return encontrados;
}

/// Camada 2 (fallback quando não há musicData): Extrai título e artista do título/canal/descrição
TituloArtista extrairDoTituloYt({
  required String tituloYt,
  required String nomeCanal,
  String? descricao,
}) {
  // 2a. Canal "Topic" → artista = nome do canal, título = título bruto
  if (isCanalTopic(nomeCanal)) {
    final artista = artistaDeCanal(nomeCanal);
    final titulo = limparTitulo(tituloYt);
    debugPrint('[Normalizer] Canal Topic → "$titulo" / "$artista"');
    return TituloArtista(
      titulo: titulo,
      artista: artista,
      origem: 'descricao_youtube',
      oficialYoutube: true,
    );
  }

  // 2b. Descrição auto-gerada ("Provided to YouTube by...")
  if (descricao != null) {
    final match = RegExp(
      r'^Provided to YouTube by[^\n]+\n\n([^\n·]+)\s*·\s*([^\n]+)',
      multiLine: true,
    ).firstMatch(descricao);
    if (match != null) {
      final titulo = limparTitulo(match.group(1)?.trim() ?? '');
      final artista = limparArtista(match.group(2)?.trim() ?? '');
      if (titulo.isNotEmpty) {
        debugPrint('[Normalizer] Provided to YouTube → "$titulo" / "$artista"');
        return TituloArtista(
          titulo: titulo,
          artista: artista,
          origem: 'descricao_youtube',
          oficialYoutube: true,
        );
      }
    }
  }

  // 2c. Separador por pipe "|" quando não tem hífen (ex: "LUGAR SECRETO | GABRIELA ROCHA")
  if (!tituloYt.contains(' - ') && tituloYt.contains('|')) {
    final partesPipe = tituloYt.split('|');
    if (partesPipe.length >= 2) {
      final p0 = limparTitulo(partesPipe[0]);
      final p1 = limparArtista(limparTitulo(partesPipe[1]));
      if (p0.isNotEmpty && p1.isNotEmpty) {
        final canalNorm = normalizarTexto(limparArtista(nomeCanal));
        final p0Norm = normalizarTexto(p0);
        if (!isCanalGravadora(nomeCanal) &&
            canalNorm.isNotEmpty &&
            (canalNorm.contains(p0Norm) || p0Norm.contains(canalNorm))) {
          return TituloArtista(titulo: p1, artista: p0, origem: 'titulo_limpo');
        }
        return TituloArtista(titulo: p0, artista: p1, origem: 'titulo_limpo');
      }
    }
  }

  // 2d. Separador " - " ou "–"
  final partes = tituloYt.split(_separadores);
  if (partes.length >= 2) {
    final p0 = limparTitulo(partes[0]).trim();
    final p1 = limparTitulo(partes.sublist(1).join(' - ')).trim();

    if (p0.isNotEmpty && p1.isNotEmpty) {
      final canalLimpo = limparArtista(nomeCanal);
      final canalNorm = normalizarTexto(canalLimpo);
      final p0norm = normalizarTexto(p0);
      final p1norm = normalizarTexto(p1);

      if (!isCanalGravadora(nomeCanal) && canalNorm.isNotEmpty) {
        if (canalNorm.contains(p0norm) || p0norm.contains(canalNorm)) {
          debugPrint(
              '[Normalizer] Separador com canal (p0=artista) → "$p1" / "$p0"');
          return TituloArtista(
            titulo: p1,
            artista: limparArtista(p0),
            origem: 'titulo_limpo',
          );
        }
        if (canalNorm.contains(p1norm) || p1norm.contains(canalNorm)) {
          debugPrint(
              '[Normalizer] Separador com canal (p1=artista) → "$p0" / "$p1"');
          return TituloArtista(
            titulo: p0,
            artista: limparArtista(p1),
            origem: 'titulo_limpo',
          );
        }
      }

      debugPrint('[Normalizer] Separador padrão → "$p0" / "$p1"');
      return TituloArtista(
        titulo: p0,
        artista: limparArtista(p1),
        origem: 'titulo_limpo',
      );
    }
  }

  // Fallback: usa o título limpo e o canal (exceto se for gravadora)
  final titulo = limparTitulo(tituloYt).trim();
  final artista = isCanalGravadora(nomeCanal) ? '' : limparArtista(nomeCanal);
  debugPrint('[Normalizer] Fallback sem separador → "$titulo" / "$artista"');
  return TituloArtista(titulo: titulo, artista: artista, origem: 'titulo_limpo');
}

// ─── Busca Oficial no Índice do CifraClub (Solr Suggest API) ───────────────
bool _tituloCompativel(String tituloBuscado, String tituloDoc) {
  final tBusca = normalizarTexto(limparTitulo(tituloBuscado));
  final tDoc = normalizarTexto(limparTitulo(tituloDoc));
  if (tBusca.isEmpty || tDoc.isEmpty) return false;
  if (tBusca == tDoc) return true;
  if (tBusca.length >= 4 && tDoc.contains(tBusca)) return true;
  if (tDoc.length >= 4 && tBusca.contains(tDoc)) return true;
  if (similaridade(tBusca, tDoc) >= 0.52) return true;

  // Verifica se todas as palavras relevantes (>= 3 letras) batem (ex: "A Ele a Glória" vs "A Ele Glória")
  final palavrasBusca =
      tBusca.split(' ').where((w) => w.length >= 3).toList();
  if (palavrasBusca.isNotEmpty &&
      palavrasBusca.every((w) => tDoc.contains(w))) {
    return true;
  }
  return false;
}

Future<List<ResultadoCifraClub>> _buscarSolrCifraClub(
  String query, {
  required String tituloReferencia,
  String artistaReferencia = '',
  double limiarMinimoSimilaridade = 0.0,
}) async {
  if (query.trim().isEmpty) return [];
  final client = CorsClient();
  try {
    final q = Uri.encodeComponent(query.trim());
    final uri = Uri.parse('https://solr.sscdn.co/cc/h2/?q=$q');
    final res = await client
        .get(uri, headers: {'User-Agent': 'Mozilla/5.0'})
        .timeout(kExternalTimeout);
    if (res.statusCode != 200) return [];

    final raw = utf8.decode(res.bodyBytes);
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return [];

    final json =
        jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
    final docs = (json['response']?['docs'] as List?) ?? [];

    final resultados = <ResultadoCifraClub>[];
    final artRefNorm = normalizarTexto(limparArtista(artistaReferencia));
    final titRefNorm = normalizarTexto(limparTitulo(tituloReferencia));

    for (final doc in docs) {
      if (doc is! Map) continue;
      if (doc['t']?.toString() != '2') continue; // t == "2" = Música/Cifra

      final m = (doc['m'] as String?)?.trim() ?? '';
      final a = (doc['a'] as String?)?.trim() ?? '';
      final d = (doc['d'] as String?)?.trim() ?? '';
      final u = (doc['u'] as String?)?.trim() ?? '';
      if (m.isEmpty || d.isEmpty || u.isEmpty) continue;

      if (!_tituloCompativel(tituloReferencia, m)) continue;

      final simTit =
          similaridade(titRefNorm, normalizarTexto(limparTitulo(m)));
      if (simTit < limiarMinimoSimilaridade &&
          !normalizarTexto(m).contains(titRefNorm)) {
        continue;
      }

      double bonusArtista = 0;
      if (artRefNorm.isNotEmpty) {
        final aNorm = normalizarTexto(a);
        if (aNorm.contains(artRefNorm) || artRefNorm.contains(aNorm)) {
          bonusArtista = 0.4;
        } else {
          bonusArtista = similaridade(artRefNorm, aNorm) * 0.3;
        }
      }

      resultados.add(ResultadoCifraClub(
        titulo: m,
        artista: a,
        artistaSlug: d,
        musicaSlug: u,
        score: simTit + bonusArtista,
      ));
    }

    resultados.sort((a, b) => b.score.compareTo(a.score));
    return resultados;
  } catch (e) {
    debugPrint('[Normalizer] CifraClub Solr falhou silenciosamente: $e');
    return [];
  } finally {
    client.close();
  }
}

/// Consulta diretamente o catálogo do CifraClub retornando as cifras reais existentes e seus slugs exatos.
Future<List<ResultadoCifraClub>> consultarCifraClub({
  required String titulo,
  String artista = '',
}) async {
  final titLimpo = limparTitulo(titulo);
  final artLimpo = limparArtista(artista);
  if (titLimpo.isEmpty) return [];

  // 1. Tenta com Título + Artista
  if (artLimpo.isNotEmpty) {
    final comArtista = await _buscarSolrCifraClub(
      '$titLimpo $artLimpo',
      tituloReferencia: titLimpo,
      artistaReferencia: artLimpo,
    );
    if (comArtista.isNotEmpty) {
      debugPrint(
        '[Normalizer] CifraClub (título+artista) → "${comArtista.first.titulo}" / "${comArtista.first.artista}" (${comArtista.first.artistaSlug}/${comArtista.first.musicaSlug})',
      );
      return comArtista;
    }
  }

  // 2. Fallback para covers / artistas diferentes: busca apenas pelo título da música
  final soTitulo = await _buscarSolrCifraClub(
    titLimpo,
    tituloReferencia: titLimpo,
    artistaReferencia: artLimpo,
    limiarMinimoSimilaridade: 0.55,
  );
  if (soTitulo.isNotEmpty) {
    debugPrint(
      '[Normalizer] CifraClub (só título) → "${soTitulo.first.titulo}" / "${soTitulo.first.artista}" (${soTitulo.first.artistaSlug}/${soTitulo.first.musicaSlug})',
    );
  }
  return soTitulo;
}

// ─── Camada 4: Deezer API (gratuita, sem chave) ─────────────────────────────
/// Consulta Deezer e retorna o melhor resultado. Retorna null se nada encontrado.
Future<TituloArtista?> consultarDeezer(String query) async {
  final client = CorsClient();
  try {
    final q = Uri.encodeComponent(query);
    final uri =
        Uri.parse('https://api.deezer.com/search?q=$q&limit=1&output=json');
    final res = await client
        .get(uri, headers: {'User-Agent': 'EscalaIBAI/1.0'})
        .timeout(kExternalTimeout);
    if (res.statusCode != 200) return null;
    final data =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final hits = data['data'] as List?;
    if (hits == null || hits.isEmpty) return null;
    final top = hits[0] as Map<String, dynamic>;
    final titulo = limparTitulo((top['title'] as String?)?.trim() ?? '');
    final artista = limparArtista(
        ((top['artist'] as Map?)?['name'] as String?)?.trim() ?? '');
    if (titulo.isEmpty) return null;
    debugPrint('[Normalizer] Deezer → "$titulo" / "$artista"');
    return TituloArtista(
      titulo: titulo,
      artista: artista,
      origem: 'catalogo_externo',
    );
  } catch (e) {
    debugPrint('[Normalizer] Deezer falhou silenciosamente: $e');
    return null;
  } finally {
    client.close();
  }
}

// ─── Camada 5: Fuzzy local (trigramas) ─────────────────────────────────────
/// Gera conjunto de trigramas de uma string normalizada
Set<String> _trigramas(String s) {
  final n = normalizarTexto(s);
  if (n.length < 3) return {n};
  final set = <String>{};
  for (int i = 0; i <= n.length - 3; i++) {
    set.add(n.substring(i, i + 3));
  }
  return set;
}

/// Coeficiente de Dice com trigramas (0.0–1.0)
double similaridade(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final ta = _trigramas(a);
  final tb = _trigramas(b);
  final intersecao = ta.intersection(tb).length;
  return (2 * intersecao) / (ta.length + tb.length);
}

/// Camada 5: Compara query com o cache acumulado e retorna sugestões acima do limiar
List<TituloArtista> sugestoesFuzzy(String query, List<CifraCache> cache) {
  if (query.isEmpty || cache.isEmpty) return [];

  final scored = cache
      .map((c) {
        final s = similaridade(query, '${c.nomeCifra} ${c.artistaCifra}');
        return (cache: c, score: s);
      })
      .where((e) => e.score >= kFuzzyLimiar)
      .toList();

  scored.sort((a, b) => b.score.compareTo(a.score));

  return scored
      .take(kMaxSugestoes)
      .map((e) => TituloArtista(
            titulo: e.cache.nomeCifra,
            artista: e.cache.artistaCifra,
            origem: 'fuzzy',
          ))
      .toList();
}

// ─── URL de busca fallback ─────────────────────────────────────────────────
String urlBuscaFallback(String tipo, String titulo, String artista) {
  final query = Uri.encodeComponent('$titulo $artista'.trim());
  return 'https://www.cifraclub.com.br/?q=$query';
}
