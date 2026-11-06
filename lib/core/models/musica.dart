class Musica {
  final String id;
  final String titulo;
  final String artista;
  final String linkYoutube;
  final String tempo;
  final DateTime createdAt;

  const Musica({
    required this.id,
    required this.titulo,
    required this.artista,
    required this.linkYoutube,
    this.tempo = '',
    required this.createdAt,
  });

  factory Musica.fromMap(Map<String, dynamic> map) => Musica(
        id: map['id'] as String,
        titulo: map['titulo'] as String,
        artista: map['artista'] as String? ?? '',
        linkYoutube: map['link_youtube'] as String? ?? '',
        tempo: map['tempo'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'titulo': titulo,
        'artista': artista,
        'link_youtube': linkYoutube,
        'tempo': tempo,
      };
}
