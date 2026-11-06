class Culto {
  final String id;
  final String diaSemana;
  final String horario;
  final String tema;
  final DateTime createdAt;

  const Culto({
    required this.id,
    required this.diaSemana,
    required this.horario,
    required this.tema,
    required this.createdAt,
  });

  factory Culto.fromMap(Map<String, dynamic> map) => Culto(
        id: map['id'] as String,
        diaSemana: map['dia_semana'] as String,
        horario: (map['horario'] as String).substring(0, 5),
        tema: map['tema'] as String? ?? 'Geral',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'dia_semana': diaSemana,
        'horario': horario,
        'tema': tema,
      };
}
