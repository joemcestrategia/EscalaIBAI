class Ausencia {
  final String id;
  final String nome;
  final String data;
  final String motivo;
  final DateTime createdAt;

  const Ausencia({
    required this.id,
    required this.nome,
    required this.data,
    required this.motivo,
    required this.createdAt,
  });

  factory Ausencia.fromMap(Map<String, dynamic> map) => Ausencia(
        id: map['id'] as String,
        nome: map['nome'] as String,
        data: map['data'] as String,
        motivo: map['motivo'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
