class Repertorio {
  final String id;
  final String dataCulto;
  final String horaCulto;
  final List<Map<String, dynamic>> listaMusicas;
  final DateTime createdAt;

  const Repertorio({
    required this.id,
    required this.dataCulto,
    required this.horaCulto,
    required this.listaMusicas,
    required this.createdAt,
  });

  factory Repertorio.fromMap(Map<String, dynamic> map) {
    final raw = map['lista_musicas'];
    List<Map<String, dynamic>> lista = [];
    if (raw is List) {
      lista = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return Repertorio(
      id: map['id'] as String,
      dataCulto: map['data_culto'] as String,
      horaCulto: ((map['hora_culto'] as String?) ?? '').length >= 5
          ? (map['hora_culto'] as String).substring(0, 5)
          : (map['hora_culto'] as String? ?? ''),
      listaMusicas: lista,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
