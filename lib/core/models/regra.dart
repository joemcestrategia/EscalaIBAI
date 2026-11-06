class Regra {
  final String id;
  final String diaSemana;
  final String horario;
  final String ministerio;
  final String funcao;
  final int qtd;
  final DateTime createdAt;

  const Regra({
    required this.id,
    required this.diaSemana,
    required this.horario,
    required this.ministerio,
    required this.funcao,
    required this.qtd,
    required this.createdAt,
  });

  factory Regra.fromMap(Map<String, dynamic> map) => Regra(
        id: map['id'] as String,
        diaSemana: map['dia_semana'] as String,
        horario: (map['horario'] as String).substring(0, 5),
        ministerio: map['ministerio'] as String,
        funcao: map['funcao'] as String,
        qtd: map['qtd'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'dia_semana': diaSemana,
        'horario': horario,
        'ministerio': ministerio,
        'funcao': funcao,
        'qtd': qtd,
      };
}
