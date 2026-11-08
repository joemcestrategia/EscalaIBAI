import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/escala_item.dart';

class EscalaRepository {
  final _db = Supabase.instance.client;

  Future<List<EscalaItem>> getByMes(int ano, int mes) async {
    final agora = DateTime.now();
    final limite7DiasAtras = agora.subtract(const Duration(days: 7));
    final limite7DiasAtrasStr =
        '${limite7DiasAtras.year}-${limite7DiasAtras.month.toString().padLeft(2, '0')}-${limite7DiasAtras.day.toString().padLeft(2, '0')}';

    final mesStr = mes.toString().padLeft(2, '0');
    final inicioMesStr = '$ano-$mesStr-01';
    final fimMesStr = mes == 12
        ? '${ano + 1}-01-01'
        : '$ano-${(mes + 1).toString().padLeft(2, '0')}-01';

    // Se o mês selecionado é completamente anterior a 7 dias atrás, não carrega
    if (fimMesStr.compareTo(limite7DiasAtrasStr) <= 0) {
      return [];
    }

    // A data inicial respeita o teto de no máximo 7 dias anteriores a hoje
    final gte = inicioMesStr.compareTo(limite7DiasAtrasStr) < 0
        ? limite7DiasAtrasStr
        : inicioMesStr;

    final data = await _db
        .from('escala')
        .select()
        .gte('data', gte)
        .lt('data', fimMesStr)
        .order('data')
        .order('horario');
    return (data as List)
        .map((e) => EscalaItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Stream<List<EscalaItem>> getByMesStream(int ano, int mes) {
    late StreamController<List<EscalaItem>> controller;
    RealtimeChannel? channel;

    controller = StreamController<List<EscalaItem>>(
      onListen: () async {
        try {
          final dados = await getByMes(ano, mes);
          if (!controller.isClosed) {
            controller.add(dados);
          }
        } catch (e, st) {
          if (!controller.isClosed) {
            controller.addError(e, st);
          }
        }

        channel = _db
            .channel('public:escala:$ano-$mes')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'escala',
              callback: (payload) async {
                try {
                  // Otimização: só recarrega se a alteração pertencer ao mês e ano atualmente exibidos
                  final mesStr = mes.toString().padLeft(2, '0');
                  final prefixoMes = '$ano-$mesStr';
                  final dataNova = payload.newRecord['data'] as String?;
                  final dataAntiga = payload.oldRecord['data'] as String?;
                  final afetaMes = (dataNova != null && dataNova.startsWith(prefixoMes)) ||
                                   (dataAntiga != null && dataAntiga.startsWith(prefixoMes));
                  if (!afetaMes) return;

                  final atualizado = await getByMes(ano, mes);
                  if (!controller.isClosed) {
                    controller.add(atualizado);
                  }
                } catch (_) {}
              },
            );
        channel!.subscribe();
      },
      onCancel: () {
        channel?.unsubscribe();
        controller.close();
      },
    );

    return controller.stream;
  }

  Future<List<EscalaItem>> getByData(String data) async {
    final res =
        await _db.from('escala').select().eq('data', data).order('horario');
    return (res as List)
        .map((e) => EscalaItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Consulta escalas de um período histórico completo (sem limite de 7 dias atrás),
  /// utilizado pelo módulo de Frequência, Faltas e Relatório de Comparecimento.
  Future<List<EscalaItem>> getPorPeriodo(
    String dataInicio,
    String dataFim,
  ) async {
    final res = await _db
        .from('escala')
        .select()
        .gte('data', dataInicio)
        .lte('data', dataFim)
        .order('data', ascending: false)
        .order('horario', ascending: true);
    return (res as List)
        .map((e) => EscalaItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EscalaItem>> getProximos({List<String>? ministerios}) async {
    final agora = DateTime.now();
    final ontemStr = agora.subtract(const Duration(days: 1)).toIso8601String().split('T')[0];
    final limiteStr = agora.add(const Duration(days: 5)).toIso8601String().split('T')[0];
    
    var q = _db
        .from('escala')
        .select()
        .gte('data', ontemStr)
        .lte('data', limiteStr)
        .neq('ministerio', 'Jejum');
        
    if (ministerios != null && ministerios.isNotEmpty) {
      q = q.filter('ministerio', 'in', ministerios);
    }

    final res = await q
        .order('data', ascending: true)
        .order('horario', ascending: true)
        .limit(100);
        
    return (res as List)
        .map((e) => EscalaItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }


  Future<bool> temEscalaRegistrada({
    required int ano,
    required int mes,
    String? ministerio,
  }) async {
    final mesStr = mes.toString().padLeft(2, '0');
    var q = _db
        .from('escala')
        .select('id')
        .gte('data', '$ano-$mesStr-01')
        .lte('data', '$ano-$mesStr-31');
    if (ministerio != null && ministerio.isNotEmpty) {
      q = q.eq('ministerio', ministerio);
    }
    final res = await q.limit(1);
    return (res as List).isNotEmpty;
  }

  Future<void> inserir(Map<String, dynamic> dados) async {
    await _db.from('escala').insert(dados);
  }

  Future<void> atualizar(String id, Map<String, dynamic> dados) async {
    await _db.from('escala').update(dados).eq('id', id);
  }

  Future<List<EscalaItem>> getJejumDoDia() async {
    final hojeStr = DateTime.now().toIso8601String().split('T')[0];
    final res = await _db
        .from('escala')
        .select()
        .eq('data', hojeStr)
        .eq('ministerio', 'Jejum');
    return (res as List)
        .map((e) => EscalaItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EscalaItem>> getProximosJejuns() async {
    final agora = DateTime.now();
    final hojeStr = agora.toIso8601String().split('T')[0];
    final limiteStr = agora.add(const Duration(days: 5)).toIso8601String().split('T')[0];

    final res = await _db
        .from('escala')
        .select()
        .gte('data', hojeStr)
        .lte('data', limiteStr)
        .eq('ministerio', 'Jejum')
        .order('data', ascending: true)
        .limit(100);
        
    return (res as List)
        .map((e) => EscalaItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }


  Future<List<EscalaItem>> getByMembro(String nome) async {
    final agora = DateTime.now();
    final limite7DiasAtras = agora.subtract(const Duration(days: 7));
    final limiteStr =
        '${limite7DiasAtras.year}-${limite7DiasAtras.month.toString().padLeft(2, '0')}-${limite7DiasAtras.day.toString().padLeft(2, '0')}';

    final res = await _db
        .from('escala')
        .select()
        .eq('nome', nome)
        .gte('data', limiteStr)
        .order('data', ascending: true)
        .order('horario');
    return (res as List)
        .map((e) => EscalaItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> excluir(String id) async {
    await _db.from('escala').delete().eq('id', id);
  }

  Future<void> excluirPorMes(int ano, int mes, {String? ministerio}) async {
    final mesStr = mes.toString().padLeft(2, '0');
    var q = _db
        .from('escala')
        .delete()
        .gte('data', '$ano-$mesStr-01')
        .lte('data', '$ano-$mesStr-31');
    if (ministerio != null && ministerio.isNotEmpty) {
      q = q.eq('ministerio', ministerio);
    }
    await q;
  }

  Future<int> contarPorMes(int ano, int mes) async {
    final mesStr = mes.toString().padLeft(2, '0');
    final data = await _db
        .from('escala')
        .select()
        .gte('data', '$ano-$mesStr-01')
        .lte('data', '$ano-$mesStr-31')
        .neq('nome', '[FALTA]');
    return (data as List).length;
  }

  Future<int> contarFaltasPorMes(int ano, int mes) async {
    final mesStr = mes.toString().padLeft(2, '0');
    final data = await _db
        .from('escala')
        .select()
        .gte('data', '$ano-$mesStr-01')
        .lte('data', '$ano-$mesStr-31')
        .eq('nome', '[FALTA]');
    return (data as List).length;
  }

  Future<int> contarCultosPorMes(int ano, int mes) async {
    final mesStr = mes.toString().padLeft(2, '0');
    final data = await _db
        .from('escala')
        .select('data, horario')
        .gte('data', '$ano-$mesStr-01')
        .lte('data', '$ano-$mesStr-31');
    final set = <String>{};
    for (final e in data as List) {
      set.add('${e['data']}_${e['horario']}');
    }
    return set.length;
  }

  Future<void> gerarEscalaAuto({
    required int mes,
    required int ano,
    String? alvoMinisterio,
    bool gerarJejum = false,
  }) async {
    // 1. Buscar dados em paralelo
    final results = await Future.wait<dynamic>([
      _db.from('membros').select(),
      _db.from('cfg_regras').select(),
      _db.from('agenda_igreja').select(),
      _db.from('ausencias').select(),
      _db.from('cfg_compatibilidades').select(),
      _db.from('cfg_jejum').select().limit(1).maybeSingle(),
    ]);

    final membros = results[0] as List;
    final regras = results[1] as List;
    final agenda = results[2] as List;
    final ausencias = results[3] as List;
    final compatibilidadesBase = results[4] as List;
    final cfgJejumData = results[5] as Map<String, dynamic>?;

    final qtdJejum = cfgJejumData != null ? (cfgJejumData['qtd_membros'] as int) : 1;
    
    // Lista mutável para adicionarmos novos pendentes em memória e evitar múltiplos inserts iguais
    final compatibilidades = List<Map<String, dynamic>>.from(compatibilidadesBase);

    // 2. Deletar escala existente do mês
    await excluirPorMes(ano, mes, ministerio: alvoMinisterio);
    if (gerarJejum) {
      await excluirPorMes(ano, mes, ministerio: 'Jejum');
    }

    // 3. Gerar novas escalas
    const diasSemana = [
      'Domingo',
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado'
    ];
    final Map<String, int> uso = {};
    final Map<String, int> usoJejum = {};
    for (final m in membros) {
      uso[m['nome'] as String] = 0;
      usoJejum[m['nome'] as String] = 0;
    }

    final primeiroDia = DateTime(ano, mes, 1);
    final ultimoDia = DateTime(ano, mes + 1, 0);
    final List<Map<String, dynamic>> novasLinhas = [];

    for (var dia = primeiroDia;
        !dia.isAfter(ultimoDia);
        dia = dia.add(const Duration(days: 1))) {
      final diaNome = diasSemana[dia.weekday % 7];
      final dataStr =
          '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';

      final regrasDia = regras.where((r) {
        if (r['dia_semana'] != diaNome) return false;
        if (alvoMinisterio != null &&
            alvoMinisterio.isNotEmpty &&
            r['ministerio'] != alvoMinisterio) {
          return false;
        }
        return true;
      }).toList();

      final horas = regrasDia
          .map((r) => (r['horario'] as String).substring(0, 5))
          .toSet();

      for (final hora in horas) {
        final evento = agenda.firstWhere(
          (c) =>
              c['dia_semana'] == dia.weekday % 7 &&
              (c['horario'] as String).startsWith(hora),
          orElse: () => {'titulo': 'Geral'},
        );
        final tema = evento['titulo'] as String? ?? 'Geral';

        final regrasHora = regrasDia
            .where((r) => (r['horario'] as String).startsWith(hora))
            .toList();

        for (final regra in regrasHora) {
          final funcAlvo = regra['funcao'] as String;
          final minAlvo = regra['ministerio'] as String;
          final qtd = regra['qtd'] as int;

          bool estaDisponivel(Map membro, DateTime data) {
            if (membro['escala_trabalho'] != 'Herculano A') return true;
            final ref = DateTime(2025, 12, 31);
            final diff = data.difference(ref).inDays;
            return ((diff % 8) + 8) % 8 < 4;
          }

          var pool = membros.where((m) {
            if (m['ministerio'] != minAlvo) return false;
            if (!(m['funcao'] ?? '')
                .toString()
                .toLowerCase()
                .contains(funcAlvo.toLowerCase())) {
              return false;
            }
            if ((m['dias_indisponiveis'] ?? '').toString().contains(diaNome)) {
              return false;
            }
            if (!estaDisponivel(m, dia)) return false;
            final temAusencia = ausencias.any((a) =>
                a['nome'] == m['nome'] &&
                (a['data'] as String).startsWith(dataStr));
            if (temAusencia) return false;

            // --- LÓGICA DE ACÚMULO DE FUNÇÕES ---
            final jaEscaladosNoDia = novasLinhas.where((nl) => 
                nl['data'] == dataStr && 
                nl['nome'] == m['nome']
            ).toList();

            for (var esc in jaEscaladosNoDia) {
              final funcAgendada = esc['funcao'] as String;
              final par = [funcAgendada.trim(), funcAlvo.trim()]..sort();
              final f1 = par[0];
              final f2 = par[1];

              final comp = compatibilidades.where((c) => 
                  c['ministerio'] == minAlvo && 
                  c['funcao1'] == f1 && 
                  c['funcao2'] == f2
              ).firstOrNull;

              if (comp == null) {
                return false; // Bloqueia o acúmulo
              } else {
                if (comp['status'] != 'aprovado') {
                  return false; // Rejeitado ou Pendente -> bloqueia
                }
              }
            }
            // ------------------------------------

            return true;
          }).toList();

          pool.shuffle(); // Embaralha primeiro para desempate constante no sort
          pool.sort((a, b) {
            final ua = uso[a['nome']] ?? 0;
            final ub = uso[b['nome']] ?? 0;
            return ua.compareTo(ub);
          });

          final selecionados = pool.take(qtd).toList();
          for (final p in selecionados) {
            uso[p['nome'] as String] = (uso[p['nome'] as String] ?? 0) + 1;
            novasLinhas.add({
              'data': dataStr,
              'dia_semana': diaNome,
              'horario': '$hora:00',
              'ministerio': minAlvo,
              'nome': p['nome'],
              'funcao': funcAlvo,
              'tema': tema,
              'status_convite': '',
            });
          }

          int vagasSobrantes = qtd - selecionados.length;
          
          if (vagasSobrantes > 0) {
            // Tenta buscar membros com a mesma função, ignorando restrições de ausência ou dias indisponíveis,
            // desde que não estejam já escalados no MESMO horário.
            var poolFallback = membros.where((m) {
              if (m['ministerio'] != minAlvo) return false;
              if (!(m['funcao'] ?? '').toString().toLowerCase().contains(funcAlvo.toLowerCase())) return false;
              if (selecionados.any((s) => s['nome'] == m['nome'])) return false;
              
              bool jaEscaladoNestaHora = novasLinhas.any((nl) => 
                  nl['data'] == dataStr && 
                  nl['horario'] == '$hora:00' && 
                  nl['nome'] == m['nome']);
              if (jaEscaladoNestaHora) return false;
              
              return true;
            }).toList();

            poolFallback.shuffle();
            poolFallback.sort((a, b) {
              final ua = uso[a['nome']] ?? 0;
              final ub = uso[b['nome']] ?? 0;
              return ua.compareTo(ub);
            });

            final selecFallback = poolFallback.take(vagasSobrantes).toList();
            for (final p in selecFallback) {
              uso[p['nome'] as String] = (uso[p['nome'] as String] ?? 0) + 1;
              novasLinhas.add({
                'data': dataStr,
                'dia_semana': diaNome,
                'horario': '$hora:00',
                'ministerio': minAlvo,
                'nome': p['nome'],
                'funcao': funcAlvo,
                'tema': tema,
                'status_convite': '',
              });
            }
            vagasSobrantes -= selecFallback.length;
          }

          // Se mesmo assim sobrarem vagas (ninguém na igreja tem essa função), aí sim colocamos [FALTA]
          for (int i = 0; i < vagasSobrantes; i++) {
            novasLinhas.add({
              'data': dataStr,
              'dia_semana': diaNome,
              'horario': '$hora:00',
              'ministerio': minAlvo,
              'nome': '[FALTA]',
              'funcao': funcAlvo,
              'tema': tema,
              'status_convite': '',
            });
          }
        }
      }
      // --- GERAÇÃO DA ESCALA DE JEJUM ---
      if (gerarJejum) {
        var poolJejum = membros.where((m) {
        if ((m['dias_indisponiveis'] ?? '').toString().contains(diaNome)) {
          return false;
        }
        final temAusencia = ausencias.any((a) =>
            a['nome'] == m['nome'] &&
            (a['data'] as String).startsWith(dataStr));
        if (temAusencia) return false;
        return true;
      }).toList();

      poolJejum.sort((a, b) {
        final ua = usoJejum[a['nome']] ?? 0;
        final ub = usoJejum[b['nome']] ?? 0;
        if (ua != ub) return ua - ub;
        return DateTime.now().millisecondsSinceEpoch % 2 == 0 ? 1 : -1;
      });

      final selecionadosJejum = poolJejum.take(qtdJejum).toList();
      for (final p in selecionadosJejum) {
        usoJejum[p['nome'] as String] = (usoJejum[p['nome'] as String] ?? 0) + 1;
        novasLinhas.add({
          'data': dataStr,
          'dia_semana': diaNome,
          'horario': '00:00:00',
          'ministerio': 'Jejum',
          'nome': p['nome'],
          'funcao': 'Jejum',
          'tema': 'Jejum Diário',
          'status_convite': '',
        });
      }
      }
    }

    // 4. Inserir em lotes de 500
    for (var i = 0; i < novasLinhas.length; i += 500) {
      final lote = novasLinhas.skip(i).take(500).toList();
      await _db.from('escala').insert(lote);
    }
  }
}
