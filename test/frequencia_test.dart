import 'package:test/test.dart';
import 'package:escala_ibai/core/models/escala_item.dart';
import 'package:escala_ibai/core/models/frequencia_registro.dart';
import 'package:escala_ibai/core/models/membro.dart';
import 'package:escala_ibai/core/repositories/frequencia_repository.dart';

Membro _membro(String id, String nome, String min) => Membro(
      id: id,
      nome: nome,
      ministerio: min,
      funcao: 'Voz',
      diasIndisponiveis: '',
      escalaTrabaho: '',
      email: '',
      createdAt: DateTime(2025, 1, 1),
    );

EscalaItem _escala({
  required String id,
  required String data,
  required String horario,
  required String ministerio,
  required String nome,
  String funcao = 'Voz',
  String statusConvite = '',
}) =>
    EscalaItem(
      id: id,
      data: data,
      diaSemana: 'Domingo',
      horario: horario,
      ministerio: ministerio,
      nome: nome,
      funcao: funcao,
      tema: 'Culto',
      statusConvite: statusConvite,
      tituloMensagem: '',
      textoBiblico: '',
      createdAt: DateTime(2025, 1, 1),
    );

FrequenciaRegistro _registro({
  required String id,
  required String nome,
  required String ministerio,
  String? escalaId,
  required String data,
  String horario = '19:30',
  String tipoAtividade = 'Ensaio',
  required StatusFrequencia status,
  String motivo = '',
}) =>
    FrequenciaRegistro(
      id: id,
      membroNome: nome,
      ministerio: ministerio,
      escalaId: escalaId,
      data: data,
      horario: horario,
      tipoAtividade: tipoAtividade,
      descricaoAtividade: tipoAtividade,
      status: status,
      motivo: motivo,
      registradoPor: 'Líder',
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  group('PeriodoFrequencia', () {
    test('intervalo esteMes e mesAnterior respeita limites corretos', () {
      final ref = DateTime(2026, 3, 15, 14, 30);
      final esteMes = PeriodoFrequencia.esteMes.intervalo(ref);
      expect(esteMes.inicio, DateTime(2026, 3, 1));
      expect(esteMes.fim, DateTime(2026, 3, 15));

      final mesAnt = PeriodoFrequencia.mesAnterior.intervalo(ref);
      expect(mesAnt.inicio, DateTime(2026, 2, 1));
      expect(mesAnt.fim, DateTime(2026, 2, 28));
    });
  });

  group('FrequenciaRepository.computarRelatorio', () {
    test('consolida acúmulo de funções no mesmo culto sem duplicar', () {
      final agora = DateTime(2026, 5, 10, 20, 0);
      final membros = [
        _membro('m1', 'João Silva', 'Louvor'),
      ];
      final escalas = [
        // Mesmo culto (data + horario + ministerio), 2 funções para João
        _escala(
          id: 'e1',
          data: '2026-05-03',
          horario: '18:00',
          ministerio: 'Louvor',
          nome: 'João Silva',
          funcao: 'Violão',
        ),
        _escala(
          id: 'e2',
          data: '2026-05-03',
          horario: '18:00',
          ministerio: 'Louvor',
          nome: 'João Silva',
          funcao: 'Voz',
        ),
        // Outro culto com falta na tabela frequencia_membros
        _escala(
          id: 'e3',
          data: '2026-05-10',
          horario: '10:00',
          ministerio: 'Louvor',
          nome: 'João Silva',
          funcao: 'Voz',
        ),
      ];
      final registros = [
        _registro(
          id: 'r1',
          nome: 'João Silva',
          ministerio: 'Louvor',
          escalaId: 'e3',
          data: '2026-05-10',
          horario: '10:00',
          tipoAtividade: 'Culto',
          status: StatusFrequencia.falta,
        ),
      ];

      final res = FrequenciaRepository.computarRelatorio(
        todosMembros: membros,
        escalasPeriodo: escalas,
        registrosFreq: registros,
        tabelaFrequenciaDisponivel: true,
        inicio: DateTime(2026, 5, 1),
        fim: DateTime(2026, 5, 31),
        agora: agora,
      );

      expect(res.resumos.length, 1);
      final joao = res.resumos.first;
      expect(joao.totalCompromissos, 2); // Não 3!
      expect(joao.presencas, 1);
      expect(joao.faltasNaoJustificadas, 1);
      expect(joao.faltasJustificadas, 0);
      expect(joao.percentualComparecimento, closeTo(50.0, 0.01));
    });

    test('ignora escalas futuras, Jejum e [FALTA], mas inclui hoje após horário ou chamado', () {
      // Agora = 10/05 às 15:00
      final agora = DateTime(2026, 5, 10, 15, 0);
      final membros = [
        _membro('m1', 'Maria Souza', 'Mídia'),
        _membro('m2', 'Pedro Lima', 'Mídia'),
      ];
      final escalas = [
        // Culto de hoje manhã (10:00 <= 15:00 -> entra)
        _escala(
          id: 'e1',
          data: '2026-05-10',
          horario: '10:00',
          ministerio: 'Mídia',
          nome: 'Maria Souza',
        ),
        // Culto de hoje à noite (19:00 > 15:00, sem chamada -> NÃO entra)
        _escala(
          id: 'e2',
          data: '2026-05-10',
          horario: '19:00',
          ministerio: 'Mídia',
          nome: 'Maria Souza',
        ),
        // Culto de hoje à noite já marcado como falta justificada -> ENTRA
        _escala(
          id: 'e3',
          data: '2026-05-10',
          horario: '19:00',
          ministerio: 'Mídia',
          nome: 'Pedro Lima',
          statusConvite: 'FALTA_JUSTIFICADA',
        ),
        // Escala de dia futuro -> NÃO entra
        _escala(
          id: 'e4',
          data: '2026-05-17',
          horario: '18:00',
          ministerio: 'Mídia',
          nome: 'Maria Souza',
        ),
        // Jejum e vaga aberta -> NÃO entram
        _escala(
          id: 'e5',
          data: '2026-05-05',
          horario: '00:00',
          ministerio: 'Jejum',
          nome: 'Maria Souza',
        ),
        _escala(
          id: 'e6',
          data: '2026-05-03',
          horario: '18:00',
          ministerio: 'Mídia',
          nome: '[FALTA]',
        ),
      ];

      final res = FrequenciaRepository.computarRelatorio(
        todosMembros: membros,
        escalasPeriodo: escalas,
        registrosFreq: const [],
        tabelaFrequenciaDisponivel: true,
        inicio: DateTime(2026, 5, 1),
        fim: DateTime(2026, 5, 31),
        agora: agora,
      );

      final maria = res.resumos.firstWhere((r) => r.membro.nome == 'Maria Souza');
      final pedro = res.resumos.firstWhere((r) => r.membro.nome == 'Pedro Lima');

      expect(maria.totalCompromissos, 1);
      expect(maria.presencas, 1);
      expect(maria.percentualComparecimento, 100.0);

      expect(pedro.totalCompromissos, 1);
      expect(pedro.presencas, 0);
      expect(pedro.faltasJustificadas, 1);
      expect(pedro.faltasNaoJustificadas, 0);
      expect(pedro.percentualComparecimento, 0.0);
    });

    test('soma eventos avulsos e diferencia falta justificada de não justificada', () {
      final agora = DateTime(2026, 5, 20, 12, 0);
      final membros = [
        _membro('m1', 'Ana Costa', 'Louvor'),
        _membro('m2', 'Lucas Reis', 'Diaconato'),
      ];
      final escalas = [
        _escala(
          id: 'e1',
          data: '2026-05-03',
          horario: '18:00',
          ministerio: 'Louvor',
          nome: 'Ana Costa',
          statusConvite: 'PRESENTE',
        ),
        _escala(
          id: 'e2',
          data: '2026-05-10',
          horario: '18:00',
          ministerio: 'Louvor',
          nome: 'Ana Costa',
        ),
      ];
      final registros = [
        // Falta justificada em ensaio (avulso)
        _registro(
          id: 'r1',
          nome: 'Ana Costa',
          ministerio: 'Louvor',
          escalaId: null,
          data: '2026-05-08',
          tipoAtividade: 'Ensaio',
          status: StatusFrequencia.faltaJustificada,
          motivo: 'Trabalho',
        ),
        // Presença em reunião (avulso)
        _registro(
          id: 'r2',
          nome: 'Ana Costa',
          ministerio: 'Louvor',
          escalaId: null,
          data: '2026-05-12',
          tipoAtividade: 'Reunião',
          status: StatusFrequencia.presente,
        ),
      ];

      final res = FrequenciaRepository.computarRelatorio(
        todosMembros: membros,
        escalasPeriodo: escalas,
        registrosFreq: registros,
        tabelaFrequenciaDisponivel: true,
        inicio: DateTime(2026, 5, 1),
        fim: DateTime(2026, 5, 31),
        agora: agora,
        ministerioFiltro: 'Louvor',
      );

      // Filtro de ministério exclui Diaconato
      expect(res.resumos.length, 1);
      final ana = res.resumos.first;
      // 2 cultos + 1 ensaio + 1 reunião = 4 compromissos; 3 presenças; 1 falta justificada
      expect(ana.totalCompromissos, 4);
      expect(ana.presencas, 3);
      expect(ana.faltasJustificadas, 1);
      expect(ana.faltasNaoJustificadas, 0);
      expect(ana.totalFaltas, 1);
      expect(ana.percentualComparecimento, closeTo(75.0, 0.01));
    });
  });
}

