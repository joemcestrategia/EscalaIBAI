class Compatibilidade {
  final String id;
  final String ministerio;
  final String funcao1;
  final String funcao2;
  final String status;
  final DateTime createdAt;

  const Compatibilidade({
    required this.id,
    required this.ministerio,
    required this.funcao1,
    required this.funcao2,
    required this.status,
    required this.createdAt,
  });

  factory Compatibilidade.fromMap(Map<String, dynamic> map) => Compatibilidade(
        id: map['id'] as String,
        ministerio: map['ministerio'] as String,
        funcao1: map['funcao1'] as String,
        funcao2: map['funcao2'] as String,
        status: map['status'] as String? ?? 'pendente',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'ministerio': ministerio,
        'funcao1': funcao1,
        'funcao2': funcao2,
        'status': status,
      };

  Compatibilidade copyWith({
    String? status,
  }) =>
      Compatibilidade(
        id: id,
        ministerio: ministerio,
        funcao1: funcao1,
        funcao2: funcao2,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
