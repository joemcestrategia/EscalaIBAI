enum TipoAgenda { culto, evento, reuniao }

enum TipoRecorrencia { semanal, mensalPosicao, unico }

class AgendaItem {
  final String id;
  final TipoAgenda tipo;
  final String titulo;
  final DateTime? dataEspecifica;
  final String horario;
  final int? diaSemana; // 0 = Domingo, ..., 6 = Sábado
  final TipoRecorrencia recorrenciaTipo;
  final int? recorrenciaValor; // 1 = Primeiro, 2 = Segundo, -1 = Último

  AgendaItem({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.dataEspecifica,
    required this.horario,
    this.diaSemana,
    required this.recorrenciaTipo,
    this.recorrenciaValor,
  });

  factory AgendaItem.fromMap(Map<String, dynamic> map) {
    return AgendaItem(
      id: map['id'],
      tipo: TipoAgenda.values.firstWhere((e) => e.name == map['tipo']),
      titulo: map['titulo'],
      dataEspecifica: map['data_especifica'] != null 
          ? DateTime.parse(map['data_especifica']) 
          : null,
      horario: map['horario'].toString().substring(0, 5),
      diaSemana: map['dia_semana'],
      recorrenciaTipo: TipoRecorrencia.values.firstWhere((e) => e.name == map['recorrencia_tipo']),
      recorrenciaValor: map['recorrencia_valor'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo.name,
      'titulo': titulo,
      'data_especifica': dataEspecifica?.toIso8601String().split('T')[0],
      'horario': horario,
      'dia_semana': diaSemana,
      'recorrencia_tipo': recorrenciaTipo.name,
      'recorrencia_valor': recorrenciaValor,
    };
  }

  List<DateTime> calcularProximasDatas(int quantidade) {
    if (recorrenciaTipo == TipoRecorrencia.unico) {
      return dataEspecifica != null ? [dataEspecifica!] : [];
    }

    final datas = <DateTime>[];
    var dataBusca = DateTime.now();

    while (datas.length < quantidade) {
      if (recorrenciaTipo == TipoRecorrencia.semanal) {
        if (dataBusca.weekday % 7 == diaSemana) {
          datas.add(DateTime(dataBusca.year, dataBusca.month, dataBusca.day));
        }
      } else if (recorrenciaTipo == TipoRecorrencia.mensalPosicao) {
        // Ex: Segundo Domingo do mês
        if (dataBusca.weekday % 7 == diaSemana) {
          final posicao = ((dataBusca.day - 1) ~/ 7) + 1;
          
          if (recorrenciaValor == -1) {
            // Último
            final ultimoDiaMes = DateTime(dataBusca.year, dataBusca.month + 1, 0).day;
            if (dataBusca.day + 7 > ultimoDiaMes) {
              datas.add(DateTime(dataBusca.year, dataBusca.month, dataBusca.day));
            }
          } else if (posicao == recorrenciaValor) {
            datas.add(DateTime(dataBusca.year, dataBusca.month, dataBusca.day));
          }
        }
      }
      dataBusca = dataBusca.add(const Duration(days: 1));
      
      // Limite de segurança para não rodar infinito
      if (dataBusca.year > DateTime.now().year + 2) break;
    }

    return datas;
  }
}
