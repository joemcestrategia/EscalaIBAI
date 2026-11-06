class CifraCache {
  final String videoId;
  final String nomeCifra;
  final String artistaCifra;
  final String origem; // 'descricao_youtube' | 'titulo_limpo' | 'catalogo_externo' | 'fuzzy' | 'manual'
  final bool confirmado;
  final DateTime updatedAt;

  const CifraCache({
    required this.videoId,
    required this.nomeCifra,
    required this.artistaCifra,
    required this.origem,
    required this.confirmado,
    required this.updatedAt,
  });

  factory CifraCache.fromMap(Map<String, dynamic> m) => CifraCache(
        videoId: m['video_id'] as String,
        nomeCifra: m['nome_cifra'] as String? ?? '',
        artistaCifra: m['artista_cifra'] as String? ?? '',
        origem: m['origem'] as String? ?? 'titulo_limpo',
        confirmado: m['confirmado'] as bool? ?? false,
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'video_id': videoId,
        'nome_cifra': nomeCifra,
        'artista_cifra': artistaCifra,
        'origem': origem,
        'confirmado': confirmado,
        'updated_at': updatedAt.toIso8601String(),
      };

  CifraCache copyWith({
    String? nomeCifra,
    String? artistaCifra,
    String? origem,
    bool? confirmado,
  }) =>
      CifraCache(
        videoId: videoId,
        nomeCifra: nomeCifra ?? this.nomeCifra,
        artistaCifra: artistaCifra ?? this.artistaCifra,
        origem: origem ?? this.origem,
        confirmado: confirmado ?? this.confirmado,
        updatedAt: DateTime.now(),
      );
}
