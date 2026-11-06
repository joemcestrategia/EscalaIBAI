class Funcao {
  final String id;
  final String ministerioPai;
  final String nomeFuncao;
  final DateTime createdAt;

  const Funcao({
    required this.id,
    required this.ministerioPai,
    required this.nomeFuncao,
    required this.createdAt,
  });

  factory Funcao.fromMap(Map<String, dynamic> map) => Funcao(
        id: map['id'] as String,
        ministerioPai: map['ministerio_pai'] as String,
        nomeFuncao: map['nome_funcao'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
