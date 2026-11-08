import 'membro.dart';

enum StatusFrequencia {
  presente,
  falta,
  faltaJustificada;

  String get code {
    switch (this) {
      case StatusFrequencia.presente:
        return 'PRESENTE';
      case StatusFrequencia.falta:
        return 'FALTA';
      case StatusFrequencia.faltaJustificada:
        return 'FALTA_JUSTIFICADA';
    }
  }

  String get label {
    switch (this) {
      case StatusFrequencia.presente:
        return 'Presente';
      case StatusFrequencia.falta:
        return 'Falta';
      case StatusFrequencia.faltaJustificada:
        return 'Falta Justificada';
    }
  }

  bool get isFalta =>
      this == StatusFrequencia.falta ||
      this == StatusFrequencia.faltaJustificada;

  static StatusFrequencia fromCode(String? code) {
    switch ((code ?? '').trim().toUpperCase()) {
      case 'FALTA':
        return StatusFrequencia.falta;
      case 'FALTA_JUSTIFICADA':
        return StatusFrequencia.faltaJustificada;
      case 'PRESENTE':
      default:
        return StatusFrequencia.presente;
    }
  }
}

enum PeriodoFrequencia {
  esteMes,
  mesAnterior,
  ultimos3Meses,
  esteAno,
  tudo;

  String get label {
    switch (this) {
      case PeriodoFrequencia.esteMes:
        return 'Este mês';
      case PeriodoFrequencia.mesAnterior:
        return 'Mês anterior';
      case PeriodoFrequencia.ultimos3Meses:
        return 'Últimos 3 meses';
      case PeriodoFrequencia.esteAno:
        return 'Este ano';
      case PeriodoFrequencia.tudo:
        return 'Todo período';
    }
  }

  ({DateTime inicio, DateTime fim}) intervalo(DateTime referencia) {
    final hoje = DateTime(referencia.year, referencia.month, referencia.day);
    switch (this) {
      case PeriodoFrequencia.esteMes:
        return (
          inicio: DateTime(hoje.year, hoje.month, 1),
          fim: hoje,
        );
      case PeriodoFrequencia.mesAnterior:
        final inicioAnt = DateTime(hoje.year, hoje.month - 1, 1);
        final fimAnt = DateTime(hoje.year, hoje.month, 0);
        return (inicio: inicioAnt, fim: fimAnt);
      case PeriodoFrequencia.ultimos3Meses:
        return (
          inicio: DateTime(hoje.year, hoje.month - 2, 1),
          fim: hoje,
        );
      case PeriodoFrequencia.esteAno:
        return (
          inicio: DateTime(hoje.year, 1, 1),
          fim: hoje,
        );
      case PeriodoFrequencia.tudo:
        return (
          inicio: DateTime(2024, 1, 1),
          fim: hoje,
        );
    }
  }
}

class FrequenciaRegistro {
  final String id;
  final String? membroId;
  final String membroNome;
  final String ministerio;
  final String? escalaId;
  final String data; // YYYY-MM-DD
  final String horario;
  final String tipoAtividade;
  final String descricaoAtividade;
  final StatusFrequencia status;
  final String motivo;
  final String registradoPor;
  final DateTime createdAt;

  const FrequenciaRegistro({
    required this.id,
    this.membroId,
    required this.membroNome,
    required this.ministerio,
    this.escalaId,
    required this.data,
    required this.horario,
    required this.tipoAtividade,
    required this.descricaoAtividade,
    required this.status,
    required this.motivo,
    required this.registradoPor,
    required this.createdAt,
  });

  factory FrequenciaRegistro.fromMap(Map<String, dynamic> map) {
    return FrequenciaRegistro(
      id: map['id']?.toString() ?? '',
      membroId: map['membro_id']?.toString(),
      membroNome: map['membro_nome'] as String? ?? '',
      ministerio: map['ministerio'] as String? ?? '',
      escalaId: map['escala_id']?.toString(),
      data: map['data'] as String? ?? '',
      horario: map['horario'] as String? ?? '',
      tipoAtividade: map['tipo_atividade'] as String? ?? 'Culto',
      descricaoAtividade: map['descricao_atividade'] as String? ?? '',
      status: StatusFrequencia.fromCode(map['status'] as String?),
      motivo: map['motivo'] as String? ?? '',
      registradoPor: map['registrado_por'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class ItemHistoricoFrequencia {
  final String? registroId;
  final List<String> escalaIds;
  final String membroNome;
  final String ministerio;
  final String data;
  final String horario;
  final String tipoAtividade;
  final String descricao;
  final StatusFrequencia status;
  final bool confirmadoExplicitamente;
  final String motivo;

  const ItemHistoricoFrequencia({
    this.registroId,
    this.escalaIds = const [],
    required this.membroNome,
    required this.ministerio,
    required this.data,
    required this.horario,
    required this.tipoAtividade,
    required this.descricao,
    required this.status,
    required this.confirmadoExplicitamente,
    required this.motivo,
  });
}

class ResumoFrequenciaMembro {
  final Membro membro;
  final int totalCompromissos;
  final int presencas;
  final int faltasNaoJustificadas;
  final int faltasJustificadas;
  final List<ItemHistoricoFrequencia> historico;

  const ResumoFrequenciaMembro({
    required this.membro,
    required this.totalCompromissos,
    required this.presencas,
    required this.faltasNaoJustificadas,
    required this.faltasJustificadas,
    required this.historico,
  });

  int get totalFaltas => faltasNaoJustificadas + faltasJustificadas;

  bool get semRegistros => totalCompromissos == 0;

  double get percentualComparecimento {
    if (totalCompromissos <= 0) return 100.0;
    return (presencas / totalCompromissos) * 100.0;
  }
}

class RelatorioFrequenciaResult {
  final List<ResumoFrequenciaMembro> resumos;
  final List<FrequenciaRegistro> registrosAvulsosEFaltas;
  final bool tabelaFrequenciaDisponivel;
  final int totalCompromissosGeral;
  final int totalPresencasGeral;
  final int totalFaltasNaoJustificadasGeral;
  final int totalFaltasJustificadasGeral;

  const RelatorioFrequenciaResult({
    required this.resumos,
    required this.registrosAvulsosEFaltas,
    required this.tabelaFrequenciaDisponivel,
    required this.totalCompromissosGeral,
    required this.totalPresencasGeral,
    required this.totalFaltasNaoJustificadasGeral,
    required this.totalFaltasJustificadasGeral,
  });

  int get totalFaltasGeral =>
      totalFaltasNaoJustificadasGeral + totalFaltasJustificadasGeral;

  double get mediaComparecimentoGeral {
    if (totalCompromissosGeral <= 0) return 100.0;
    return (totalPresencasGeral / totalCompromissosGeral) * 100.0;
  }
}

