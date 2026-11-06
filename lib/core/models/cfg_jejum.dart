class CfgJejum {
  final String id;
  final int qtdMembros;
  final DateTime createdAt;

  const CfgJejum({
    required this.id,
    required this.qtdMembros,
    required this.createdAt,
  });

  factory CfgJejum.fromMap(Map<String, dynamic> map) => CfgJejum(
        id: map['id'] as String,
        qtdMembros: map['qtd_membros'] as int? ?? 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'qtd_membros': qtdMembros,
      };
}
