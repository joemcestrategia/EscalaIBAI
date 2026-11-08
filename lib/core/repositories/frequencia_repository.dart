import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/escala_item.dart';
import '../models/frequencia_registro.dart';
import '../models/membro.dart';
import 'escala_repository.dart';

class FrequenciaRepository {
  final _db = Supabase.instance.client;
  final _escalaRepo = EscalaRepository();

  bool _tabelaIndisponivel(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('pgrst205') ||
        msg.contains('42p01') ||
        msg.contains('frequencia_membros');
  }

  Future<({List<FrequenciaRegistro> registros, bool tabelaDisponivel})>
      getRegistrosPeriodo(String dataInicio, String dataFim) async {
    try {
      final data = await _db
          .from('frequencia_membros')
          .select()
          .gte('data', dataInicio)
          .lte('data', dataFim)
          .order('data', ascending: false)
          .order('created_at', ascending: false);
      final lista = (data as List)
          .map((e) => FrequenciaRegistro.fromMap(e as Map<String, dynamic>))
          .toList();
      return (registros: lista, tabelaDisponivel: true);
    } catch (e) {
      if (_tabelaIndisponivel(e)) {
        debugPrint(
          'Aviso: tabela frequencia_membros ainda não criada no Supabase ($e)',
        );
        return (registros: <FrequenciaRegistro>[], tabelaDisponivel: false);
      }
      rethrow;
    }
  }

  /// Registra ou atualiza presença/falta de um membro em um ou mais itens da mesma escala (culto).
  Future<void> registrarChamadaEscala({
    required List<EscalaItem> itensDoMembroNoCulto,
    required StatusFrequencia status,
    String motivo = '',
    String? membroId,
    String registradoPor = '',
  }) async {
    if (itensDoMembroNoCulto.isEmpty) return;

    final idsEscala = itensDoMembroNoCulto.map((e) => e.id).toList();
    final primeiro = itensDoMembroNoCulto.first;
    final funcoesDesc = itensDoMembroNoCulto
        .map((e) => e.funcao.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .join(', ');
    final descricao = primeiro.tema.trim().isNotEmpty
        ? '${primeiro.tema.trim()} ($funcoesDesc)'
        : (funcoesDesc.isNotEmpty ? funcoesDesc : 'Culto');

    // 1. Atualiza o status na tabela escala para refletir imediatamente nas telas da escala
    await _db
        .from('escala')
        .update({'status_convite': status.code})
        .inFilter('id', idsEscala);

    // 2. Sincroniza o registro detalhado na tabela frequencia_membros (vinculado ao primeiro item da escala do culto)
    try {
      // Remove vínculos duplicados caso o membro acumulasse funções com registros separados antes
      if (idsEscala.length > 1) {
        await _db
            .from('frequencia_membros')
            .delete()
            .inFilter('escala_id', idsEscala.skip(1).toList());
      }

      await _db.from('frequencia_membros').upsert(
        {
          'membro_id': membroId,
          'membro_nome': primeiro.nome,
          'ministerio': primeiro.ministerio,
          'escala_id': primeiro.id,
          'data': primeiro.data,
          'horario': primeiro.horario,
          'tipo_atividade': 'Culto',
          'descricao_atividade': descricao,
          'status': status.code,
          'motivo': motivo.trim(),
          'registrado_por': registradoPor,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'escala_id',
      );
    } catch (e) {
      if (!_tabelaIndisponivel(e)) {
        rethrow;
      }
      debugPrint(
        'Aviso: frequencia_membros ausente; status salvo apenas na tabela escala.',
      );
    }
  }

  /// Registra falta ou presença avulsa (ex: ensaio, reunião ou evento fora da escala).
  Future<void> registrarEventoAvulso({
    required List<Membro> membros,
    required String ministerio,
    required String data,
    String horario = '',
    required String tipoAtividade,
    String descricaoAtividade = '',
    required StatusFrequencia status,
    String motivo = '',
    String registradoPor = '',
  }) async {
    if (membros.isEmpty) return;

    final nowIso = DateTime.now().toIso8601String();
    final rows = membros
        .map((m) => {
              'membro_id': m.id.isNotEmpty ? m.id : null,
              'membro_nome': m.nome,
              'ministerio': ministerio.isNotEmpty ? ministerio : m.ministerio,
              'escala_id': null,
              'data': data,
              'horario': horario,
              'tipo_atividade': tipoAtividade,
              'descricao_atividade': descricaoAtividade.trim(),
              'status': status.code,
              'motivo': motivo.trim(),
              'registrado_por': registradoPor,
              'updated_at': nowIso,
            })
        .toList();

    await _db.from('frequencia_membros').insert(rows);
  }

  Future<void> atualizarRegistro({
    required FrequenciaRegistro registro,
    required StatusFrequencia novoStatus,
    required String novoMotivo,
  }) async {
    try {
      await _db.from('frequencia_membros').update({
        'status': novoStatus.code,
        'motivo': novoMotivo.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', registro.id);
    } catch (e) {
      if (!_tabelaIndisponivel(e)) rethrow;
    }

    if (registro.escalaId != null && registro.escalaId!.isNotEmpty) {
      await _atualizarStatusNaEscala(registro, novoStatus.code);
    }
  }

  Future<void> excluirRegistro(FrequenciaRegistro registro) async {
    try {
      await _db.from('frequencia_membros').delete().eq('id', registro.id);
    } catch (e) {
      if (!_tabelaIndisponivel(e)) rethrow;
    }

    if (registro.escalaId != null && registro.escalaId!.isNotEmpty) {
      await _atualizarStatusNaEscala(registro, '');
    }
  }

  Future<void> _atualizarStatusNaEscala(
    FrequenciaRegistro registro,
    String statusConvite,
  ) async {
    if (registro.data.isNotEmpty &&
        registro.ministerio.isNotEmpty &&
        registro.membroNome.isNotEmpty) {
      var query = _db
          .from('escala')
          .update({'status_convite': statusConvite})
          .eq('data', registro.data)
          .eq('ministerio', registro.ministerio)
          .eq('nome', registro.membroNome);
      if (registro.horario.isNotEmpty) {
        query = query.eq('horario', registro.horario);
      }
      await query;
      return;
    }

    if (registro.escalaId != null && registro.escalaId!.isNotEmpty) {
      await _db
          .from('escala')
          .update({'status_convite': statusConvite})
          .eq('id', registro.escalaId!);
    }
  }

  /// Gera o relatório consolidado de faltas e porcentagem de comparecimento
  /// considerando escalas já realizadas até o momento atual e registros avulsos.
  Future<RelatorioFrequenciaResult> gerarRelatorio({
    required List<Membro> todosMembros,
    required DateTime inicio,
    required DateTime fim,
    String? ministerioFiltro,
    DateTime? referenciaAgora,
  }) async {
    final agora = referenciaAgora ?? DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final fimEfetivo = fim.isAfter(hoje) ? hoje : fim;

    final fmt = DateFormat('yyyy-MM-dd');
    final inicioStr = fmt.format(inicio);
    final fimStr = fmt.format(fimEfetivo);

    final results = await Future.wait<dynamic>([
      _escalaRepo.getPorPeriodo(inicioStr, fimStr),
      getRegistrosPeriodo(inicioStr, fimStr),
    ]);

    final escalasPeriodo = results[0] as List<EscalaItem>;
    final freqRes = results[1]
        as ({List<FrequenciaRegistro> registros, bool tabelaDisponivel});

    return computarRelatorio(
      todosMembros: todosMembros,
      escalasPeriodo: escalasPeriodo,
      registrosFreq: freqRes.registros,
      tabelaFrequenciaDisponivel: freqRes.tabelaDisponivel,
      inicio: inicio,
      fim: fimEfetivo,
      agora: agora,
      ministerioFiltro: ministerioFiltro,
    );
  }

  /// Cálculo puro e determinístico do relatório de faltas e % de comparecimento.
  static RelatorioFrequenciaResult computarRelatorio({
    required List<Membro> todosMembros,
    required List<EscalaItem> escalasPeriodo,
    required List<FrequenciaRegistro> registrosFreq,
    required bool tabelaFrequenciaDisponivel,
    required DateTime inicio,
    required DateTime fim,
    DateTime? agora,
    String? ministerioFiltro,
  }) {
    final refAgora = agora ?? DateTime.now();
    final hoje = DateTime(refAgora.year, refAgora.month, refAgora.day);
    final fimEfetivo = fim.isAfter(hoje) ? hoje : fim;

    final fmt = DateFormat('yyyy-MM-dd');
    final inicioStr = fmt.format(inicio);
    final fimStr = fmt.format(fimEfetivo);
    final hojeStr = fmt.format(hoje);

    // Indexar registros de frequência vinculados a escala_id
    final freqPorEscalaId = <String, FrequenciaRegistro>{};
    for (final r in registrosFreq) {
      if (r.escalaId != null && r.escalaId!.isNotEmpty) {
        freqPorEscalaId[r.escalaId!] = r;
      }
    }

    // 1. Filtrar escalas válidas dentro do intervalo já realizadas até agora
    final escalasRealizadas = escalasPeriodo.where((item) {
      final nome = item.nome.trim();
      if (nome.isEmpty || nome == '[FALTA]') return false;
      if (item.ministerio == 'Jejum') return false;
      if (ministerioFiltro != null &&
          ministerioFiltro.isNotEmpty &&
          item.ministerio != ministerioFiltro) {
        return false;
      }
      if (item.data.compareTo(inicioStr) < 0 || item.data.compareTo(fimStr) > 0) {
        return false;
      }

      if (item.data.compareTo(hojeStr) < 0) return true;
      if (item.data.compareTo(hojeStr) > 0) return false;

      // Se é hoje, entra se o líder já registrou presença/falta OU se o horário do culto já chegou
      final jaChamado = item.statusConvite == 'PRESENTE' ||
          item.statusConvite == 'FALTA' ||
          item.statusConvite == 'FALTA_JUSTIFICADA' ||
          freqPorEscalaId.containsKey(item.id);
      if (jaChamado) return true;

      final hParts = item.horario.split(':');
      final hora = hParts.isNotEmpty ? int.tryParse(hParts[0]) ?? 0 : 0;
      final min = hParts.length > 1 ? int.tryParse(hParts[1]) ?? 0 : 0;
      final dtCulto = DateTime(hoje.year, hoje.month, hoje.day, hora, min);
      return !dtCulto.isAfter(refAgora);
    }).toList();

    // 2. Consolidar escalas do mesmo membro no mesmo culto (evita contar 2x acúmulo de função)
    final gruposCulto = <String, List<EscalaItem>>{};
    for (final item in escalasRealizadas) {
      final chave =
          '${item.nome.trim().toLowerCase()}|${item.data}|${item.horario}|${item.ministerio}';
      gruposCulto.putIfAbsent(chave, () => []).add(item);
    }

    final historicoPorMembro = <String, List<ItemHistoricoFrequencia>>{};

    for (final grupo in gruposCulto.values) {
      final primeiro = grupo.first;
      final nomeKey = primeiro.nome.trim().toLowerCase();

      FrequenciaRegistro? regEncontrado;
      for (final item in grupo) {
        final r = freqPorEscalaId[item.id];
        if (r != null) {
          regEncontrado = r;
          break;
        }
      }

      StatusFrequencia statusFinal = StatusFrequencia.presente;
      bool confirmadoExplicitamente = false;
      String motivo = '';

      if (regEncontrado != null) {
        statusFinal = regEncontrado.status;
        confirmadoExplicitamente = true;
        motivo = regEncontrado.motivo;
      } else {
        // Fallback para registros legados salvos apenas em escala.status_convite
        if (grupo.any((e) => e.statusConvite == 'FALTA')) {
          statusFinal = StatusFrequencia.falta;
          confirmadoExplicitamente = true;
        } else if (grupo.any((e) => e.statusConvite == 'FALTA_JUSTIFICADA')) {
          statusFinal = StatusFrequencia.faltaJustificada;
          confirmadoExplicitamente = true;
        } else if (grupo.any((e) => e.statusConvite == 'PRESENTE')) {
          statusFinal = StatusFrequencia.presente;
          confirmadoExplicitamente = true;
        }
      }

      final funcoes = grupo
          .map((e) => e.funcao.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .join(', ');
      final desc = primeiro.tema.trim().isNotEmpty
          ? (funcoes.isNotEmpty ? '${primeiro.tema} • $funcoes' : primeiro.tema)
          : (funcoes.isNotEmpty ? funcoes : 'Culto');

      historicoPorMembro.putIfAbsent(nomeKey, () => []).add(
            ItemHistoricoFrequencia(
              registroId: regEncontrado?.id,
              escalaIds: grupo.map((e) => e.id).toList(),
              membroNome: primeiro.nome,
              ministerio: primeiro.ministerio,
              data: primeiro.data,
              horario: primeiro.horario,
              tipoAtividade: 'Culto',
              descricao: desc,
              status: statusFinal,
              confirmadoExplicitamente: confirmadoExplicitamente,
              motivo: motivo,
            ),
          );
    }

    // 3. Somar registros avulsos (ensaios, reuniões, etc.) onde escala_id é nulo
    final registrosAvulsos = registrosFreq.where((r) {
      if (r.escalaId != null && r.escalaId!.isNotEmpty) return false;
      if (ministerioFiltro != null &&
          ministerioFiltro.isNotEmpty &&
          r.ministerio != ministerioFiltro) {
        return false;
      }
      return r.data.compareTo(inicioStr) >= 0 && r.data.compareTo(fimStr) <= 0;
    }).toList();

    for (final r in registrosAvulsos) {
      final nomeKey = r.membroNome.trim().toLowerCase();
      historicoPorMembro.putIfAbsent(nomeKey, () => []).add(
            ItemHistoricoFrequencia(
              registroId: r.id,
              escalaIds: const [],
              membroNome: r.membroNome,
              ministerio: r.ministerio,
              data: r.data,
              horario: r.horario,
              tipoAtividade: r.tipoAtividade,
              descricao: r.descricaoAtividade.isNotEmpty
                  ? r.descricaoAtividade
                  : r.tipoAtividade,
              status: r.status,
              confirmadoExplicitamente: true,
              motivo: r.motivo,
            ),
          );
    }

    // 4. Consolidar por membro cadastrado (e eventual histórico de nome fora do cadastro)
    final membrosAlvo = ministerioFiltro == null || ministerioFiltro.isEmpty
        ? todosMembros
        : todosMembros
            .where((m) => m.ministerio == ministerioFiltro)
            .toList();

    final nomesProcessados = <String>{};
    final resumos = <ResumoFrequenciaMembro>[];

    void adicionarResumo(Membro membro) {
      final key = membro.nome.trim().toLowerCase();
      nomesProcessados.add(key);

      final hist = List<ItemHistoricoFrequencia>.from(
        historicoPorMembro[key] ?? [],
      )..sort((a, b) {
          final cmp = b.data.compareTo(a.data);
          return cmp != 0 ? cmp : b.horario.compareTo(a.horario);
        });

      final total = hist.length;
      final faltasNaoJust =
          hist.where((h) => h.status == StatusFrequencia.falta).length;
      final faltasJust = hist
          .where((h) => h.status == StatusFrequencia.faltaJustificada)
          .length;
      final presencas = total - faltasNaoJust - faltasJust;

      resumos.add(
        ResumoFrequenciaMembro(
          membro: membro,
          totalCompromissos: total,
          presencas: presencas,
          faltasNaoJustificadas: faltasNaoJust,
          faltasJustificadas: faltasJust,
          historico: hist,
        ),
      );
    }

    for (final m in membrosAlvo) {
      adicionarResumo(m);
    }

    for (final entry in historicoPorMembro.entries) {
      if (nomesProcessados.contains(entry.key) || entry.value.isEmpty) continue;
      final primeiro = entry.value.first;
      adicionarResumo(
        Membro(
          id: '',
          nome: primeiro.membroNome,
          ministerio: primeiro.ministerio,
          funcao: '',
          diasIndisponiveis: '',
          escalaTrabaho: '',
          email: '',
          createdAt: DateTime.now(),
        ),
      );
    }

    int totalCompromissosGeral = 0;
    int totalPresencasGeral = 0;
    int totalFaltasNaoJustGeral = 0;
    int totalFaltasJustGeral = 0;

    for (final r in resumos) {
      totalCompromissosGeral += r.totalCompromissos;
      totalPresencasGeral += r.presencas;
      totalFaltasNaoJustGeral += r.faltasNaoJustificadas;
      totalFaltasJustGeral += r.faltasJustificadas;
    }

    // Lista cronológica de todas as faltas e eventos avulsos para gestão rápida
    final todasFaltasERegistros = registrosFreq.where((r) {
      if (ministerioFiltro != null &&
          ministerioFiltro.isNotEmpty &&
          r.ministerio != ministerioFiltro) {
        return false;
      }
      if (r.data.compareTo(inicioStr) < 0 || r.data.compareTo(fimStr) > 0) {
        return false;
      }
      return r.status.isFalta || r.escalaId == null;
    }).toList();

    return RelatorioFrequenciaResult(
      resumos: resumos,
      registrosAvulsosEFaltas: todasFaltasERegistros,
      tabelaFrequenciaDisponivel: tabelaFrequenciaDisponivel,
      totalCompromissosGeral: totalCompromissosGeral,
      totalPresencasGeral: totalPresencasGeral,
      totalFaltasNaoJustificadasGeral: totalFaltasNaoJustGeral,
      totalFaltasJustificadasGeral: totalFaltasJustGeral,
    );
  }
}
