class Membro {
  final String id;
  final String nome;
  final String? nascimento;
  final String ministerio;
  final String funcao;
  final String diasIndisponiveis;
  final String escalaTrabaho;
  final String email;
  final DateTime createdAt;

  const Membro({
    required this.id,
    required this.nome,
    this.nascimento,
    required this.ministerio,
    required this.funcao,
    required this.diasIndisponiveis,
    required this.escalaTrabaho,
    required this.email,
    required this.createdAt,
  });

  factory Membro.fromMap(Map<String, dynamic> map) => Membro(
        id: map['id']?.toString() ?? '',
        nome: map['nome'] as String? ?? 'Sem Nome',
        nascimento: map['nascimento'] as String?,
        ministerio: map['ministerio'] as String? ?? '',
        funcao: map['funcao'] as String? ?? '',
        diasIndisponiveis: map['dias_indisponiveis'] as String? ?? '',
        escalaTrabaho: map['escala_trabalho'] as String? ?? '',
        email: map['email'] as String? ?? '',
        createdAt: map['created_at'] != null 
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'nascimento': nascimento,
        'ministerio': ministerio,
        'funcao': funcao,
        'dias_indisponiveis': diasIndisponiveis,
        'escala_trabalho': escalaTrabaho,
        'email': email,
      };

  Membro copyWith({
    String? nome,
    String? nascimento,
    String? ministerio,
    String? funcao,
    String? diasIndisponiveis,
    String? escalaTrabaho,
    String? email,
  }) =>
      Membro(
        id: id,
        nome: nome ?? this.nome,
        nascimento: nascimento ?? this.nascimento,
        ministerio: ministerio ?? this.ministerio,
        funcao: funcao ?? this.funcao,
        diasIndisponiveis: diasIndisponiveis ?? this.diasIndisponiveis,
        escalaTrabaho: escalaTrabaho ?? this.escalaTrabaho,
        email: email ?? this.email,
        createdAt: createdAt,
      );

  List<String> get funcoes => funcao.isEmpty
      ? []
      : funcao
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

  List<String> get diasIndisponiveisList => diasIndisponiveis.isEmpty
      ? []
      : diasIndisponiveis
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
}
