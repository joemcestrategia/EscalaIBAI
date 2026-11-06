import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/cifra_cache.dart';

// ─── Configuração global do pipeline ───────────────────────────────────────
/// Limiar de similaridade fuzzy (0.0–1.0). Acima disso a sugestão é válida.
const double kFuzzyLimiar = 0.68;

/// Máximo de sugestões fuzzy a exibir
const int kMaxSugestoes = 3;

/// Timeout para chamadas externas (Deezer, youtube_explode)
const Duration kExternalTimeout = Duration(seconds: 6);

/// Fonte de cifra usada em toda a app. Trocar aqui muda tudo.
/// Valores: 'letras' | 'cifraclub'
const String kFonteCifra = 'letras';

// ─── Padrões de limpeza de título ──────────────────────────────────────────
final _padroesTitulo = [
  // Conteúdo entre parênteses e colchetes
  RegExp(r'\([^)]*\)', caseSensitive: false),
  RegExp(r'\[[^\]]*\]', caseSensitive: false),
  // Feat / Part / Com
  RegExp(r'\bfeat\.?\s+[^|,\n]+', caseSensitive: false),
  RegExp(r'\bpart\.?\s+[^|,\n]+', caseSensitive: false),
  RegExp(r'\bcom\s+[^|,\n]+', caseSensitive: false),
  // Sufixos pós-pipe ou pós-traço no final
  RegExp(r'\|.*$'),
  // Emojis e símbolos não-ASCII
  RegExp(r'[^\x00-\x7Fà-ÿÀ-Ÿ ]'),
];

final _separadores = RegExp(r'\s*[-–—]\s*');

// ─── Data class para resultado de extração ─────────────────────────────────
class TituloArtista {
  final String titulo;
  final String artista;
  final String origem;

  const TituloArtista({
    required this.titulo,
    required this.artista,
    required this.origem,
  });

  bool get valido => titulo.isNotEmpty;

  @override
  String toString() => '"$titulo" — "$artista" (origem: $origem)';
}

// ─── Normalização base ──────────────────────────────────────────────────────
/// Remove acentos, converte para minúsculas, remove pontuação extra
String normalizarTexto(String s) {
  s = s.toLowerCase().trim();
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to   = 'aaaaaeeeeiiiioooooouuuucn';
  for (int i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }
  s = s.replaceAll(RegExp(r"[^\w\s]"), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// Limpa o título do YouTube removendo sufixos, emojis, feat., etc.
String limparTitulo(String titulo) {
  var s = titulo;
  for (final p in _padroesTitulo) {
    s = s.replaceAll(p, '');
  }
  return s.trim().replaceAll(RegExp(r'\s{2,}'), ' ');
}

// ─── Camada 2: Extração de título/artista do título do YouTube ──────────────
/// Detecta se o canal é do tipo "Artista - Topic"
bool isCanalTopic(String nomeCanal) =>
    nomeCanal.toLowerCase().endsWith(' - topic') ||
    nomeCanal.toLowerCase().endsWith('- topic');

/// Extrai nome do artista de um canal Topic
String artistaDeCanal(String nomeCanal) =>
    nomeCanal.replaceAll(RegExp(r'\s*-\s*[Tt]opic$'), '').trim();

/// Camada 2: Extrai título e artista do título sujo do YouTube
/// Formato comum: "Música - Artista | Sufixo" ou "Artista - Música"
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
    return TituloArtista(titulo: titulo, artista: artista, origem: 'descricao_youtube');
  }

  // 2b. Descrição auto-gerada ("Provided to YouTube by...")
  if (descricao != null) {
    final match = RegExp(
      r'^Provided to YouTube by[^\n]+\n\n([^\n·]+)\s*·\s*([^\n]+)',
      multiLine: true,
    ).firstMatch(descricao);
    if (match != null) {
      final titulo = match.group(1)?.trim() ?? '';
      final artista = match.group(2)?.trim() ?? '';
      if (titulo.isNotEmpty) {
        debugPrint('[Normalizer] Provided to YouTube → "$titulo" / "$artista"');
        return TituloArtista(titulo: titulo, artista: artista, origem: 'descricao_youtube');
      }
    }
  }

  // 2c. Separador " - " ou "–"
  final partes = tituloYt.split(_separadores);
  if (partes.length >= 2) {
    // Heurística: se a parte 0 parece nome de artista (curto), é artista
    // Se a parte 0 tem mais palavras, provavelmente é o título
    final p0 = limparTitulo(partes[0]).trim();
    final p1 = limparTitulo(partes.sublist(1).join(' - ')).trim();

    if (p0.isNotEmpty && p1.isNotEmpty) {
      // Verifica se o canal bate com p0 (artista antes do traço)
      final canalNorm = normalizarTexto(nomeCanal);
      final p0norm = normalizarTexto(p0);
      if (canalNorm.contains(p0norm) || p0norm.contains(canalNorm)) {
        debugPrint('[Normalizer] Separador com canal → "$p1" / "$p0"');
        return TituloArtista(titulo: p1, artista: p0, origem: 'titulo_limpo');
      }
      // Caso contrário, tenta p1 como título (mais comum no gospel BR)
      debugPrint('[Normalizer] Separador padrão → "$p0" / "$p1"');
      return TituloArtista(titulo: p0, artista: p1, origem: 'titulo_limpo');
    }
  }

  // Fallback: usa o título limpo sem artista
  final titulo = limparTitulo(tituloYt).trim();
  debugPrint('[Normalizer] Fallback sem separador → "$titulo"');
  return TituloArtista(titulo: titulo, artista: nomeCanal, origem: 'titulo_limpo');
}

// ─── Camada 4: Deezer API (gratuita, sem chave) ─────────────────────────────
/// Consulta Deezer e retorna o melhor resultado. Retorna null se nada encontrado.
Future<TituloArtista?> consultarDeezer(String query) async {
  try {
    final q = Uri.encodeComponent(query);
    final uri = Uri.parse('https://api.deezer.com/search?q=$q&limit=1&output=json');
    final res = await http.get(uri, headers: {'User-Agent': 'EscalaIBAI/1.0'})
        .timeout(kExternalTimeout);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final hits = data['data'] as List?;
    if (hits == null || hits.isEmpty) return null;
    final top = hits[0] as Map<String, dynamic>;
    final titulo = (top['title'] as String?)?.trim() ?? '';
    final artista = ((top['artist'] as Map?)?['name'] as String?)?.trim() ?? '';
    if (titulo.isEmpty) return null;
    debugPrint('[Normalizer] Deezer → "$titulo" / "$artista"');
    return TituloArtista(titulo: titulo, artista: artista, origem: 'catalogo_externo');
  } catch (e) {
    debugPrint('[Normalizer] Deezer falhou silenciosamente: $e');
    return null;
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

  final scored = cache.map((c) {
    final s = similaridade(query, '${c.nomeCifra} ${c.artistaCifra}');
    return (cache: c, score: s);
  }).where((e) => e.score >= kFuzzyLimiar).toList();

  scored.sort((a, b) => b.score.compareTo(a.score));

  return scored.take(kMaxSugestoes).map((e) => TituloArtista(
    titulo: e.cache.nomeCifra,
    artista: e.cache.artistaCifra,
    origem: 'fuzzy',
  )).toList();
}

// ─── URL de busca fallback ─────────────────────────────────────────────────
String urlBuscaFallback(String tipo, String titulo, String artista) {
  final query = Uri.encodeComponent('$titulo $artista');
  return 'https://www.cifraclub.com.br/?q=$query';
}
