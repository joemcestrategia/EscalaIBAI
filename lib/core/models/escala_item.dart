class EscalaItem {
  final String id;
  final String data;
  final String diaSemana;
  final String horario;
  final String ministerio;
  final String nome;
  final String funcao;
  final String tema;
  final String statusConvite;
  final String tituloMensagem;
  final String textoBiblico;
  final DateTime createdAt;

  const EscalaItem({
    required this.id,
    required this.data,
    required this.diaSemana,
    required this.horario,
    required this.ministerio,
    required this.nome,
    required this.funcao,
    required this.tema,
    required this.statusConvite,
    required this.tituloMensagem,
    required this.textoBiblico,
    required this.createdAt,
  });

  factory EscalaItem.fromMap(Map<String, dynamic> map) => EscalaItem(
        id: map['id'] as String,
        data: map['data'] as String,
        diaSemana: map['dia_semana'] as String? ?? '',
        horario: ((map['horario'] as String?) ?? '').length >= 5
            ? (map['horario'] as String).substring(0, 5)
            : (map['horario'] as String? ?? ''),
        ministerio: map['ministerio'] as String? ?? '',
        nome: map['nome'] as String? ?? '',
        funcao: map['funcao'] as String? ?? '',
        tema: map['tema'] as String? ?? '',
        statusConvite: map['status_convite'] as String? ?? '',
        tituloMensagem: map['titulo_mensagem'] as String? ?? '',
        textoBiblico: map['texto_biblico'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'data': data,
        'dia_semana': diaSemana,
        'horario': horario,
        'ministerio': ministerio,
        'nome': nome,
        'funcao': funcao,
        'tema': tema,
        'status_convite': statusConvite,
        'titulo_mensagem': tituloMensagem,
        'texto_biblico': textoBiblico,
      };

  EscalaItem copyWith({
    String? statusConvite,
    String? tituloMensagem,
    String? textoBiblico,
  }) =>
      EscalaItem(
        id: id,
        data: data,
        diaSemana: diaSemana,
        horario: horario,
        ministerio: ministerio,
        nome: nome,
        funcao: funcao,
        tema: tema,
        statusConvite: statusConvite ?? this.statusConvite,
        tituloMensagem: tituloMensagem ?? this.tituloMensagem,
        textoBiblico: textoBiblico ?? this.textoBiblico,
        createdAt: createdAt,
      );
}
