import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/membro.dart';

class MembrosRepository {
  final _db = Supabase.instance.client;

  Future<List<Membro>> getAll() async {
    final res = await _db.from('membros').select();
    final lista = (res as List)
        .map((e) => Membro.fromMap(e as Map<String, dynamic>))
        .toList();
    lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return lista;
  }

  Future<List<Membro>> getByMinisterio(String ministerio) async {
    final data = await _db
        .from('membros')
        .select()
        .eq('ministerio', ministerio)
        .order('nome');
    return (data as List)
        .map((e) => Membro.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> inserir(Map<String, dynamic> dados) async {
    await _db.from('membros').insert(dados);
    await _registrarParesFuncoes(dados);
  }

  Future<void> atualizar(String id, Map<String, dynamic> dados) async {
    // 1. Pega o nome antigo antes de atualizar
    final res = await _db.from('membros').select('nome').eq('id', id).maybeSingle();
    final nomeAntigo = res != null ? res['nome'] as String? : null;

    // 2. Atualiza o cadastro do membro
    await _db.from('membros').update(dados).eq('id', id);

    // 3. Se o nome mudou, atualiza o histórico de escalas para não perder o vínculo
    if (nomeAntigo != null && dados.containsKey('nome')) {
      final nomeNovo = dados['nome'] as String;
      if (nomeAntigo != nomeNovo) {
        try {
          await _db.from('escala').update({'nome': nomeNovo}).eq('nome', nomeAntigo);
        } catch (e) {
          // Ignora se der erro (ex: não tem escala pra ele ainda)
        }
      }
    }

    await _registrarParesFuncoes(dados);
  }

  Future<void> excluir(String id) async {
    await _db.from('membros').delete().eq('id', id);
  }

  Future<int> restaurarMembrosDasEscalas() async {
    // 1. Busca todos os nomes únicos das escalas
    final resEscalas = await _db.from('escala').select('nome, ministerio, funcao');
    if (resEscalas == null || (resEscalas as List).isEmpty) return 0;

    final registros = resEscalas as List;
    final nomesExistentes = await getAll();
    final setNomes = nomesExistentes.map((m) => m.nome.toLowerCase().trim()).toSet();

    int restaurados = 0;
    final mapaNovos = <String, Map<String, dynamic>>{};

    for (var reg in registros) {
      final nome = (reg['nome'] as String? ?? '').trim();
      if (nome.isEmpty || nome == '[FALTA]' || setNomes.contains(nome.toLowerCase())) continue;

      // Se ainda não processamos este nome nesta rodada
      if (!mapaNovos.containsKey(nome.toLowerCase())) {
        mapaNovos[nome.toLowerCase()] = {
          'nome': nome,
          'ministerio': reg['ministerio'] ?? '',
          'funcao': reg['funcao'] ?? '',
          'dias_indisponiveis': '',
          'escala_trabalho': 'Sem restrição',
        };
      }
    }

    if (mapaNovos.isNotEmpty) {
      final listaParaInserir = mapaNovos.values.toList();
      await _db.from('membros').insert(listaParaInserir);
      restaurados = listaParaInserir.length;
    }

    return restaurados;
  }

  Future<void> _registrarParesFuncoes(Map<String, dynamic> dados) async {
    try {
      final ministerio = dados['ministerio'] as String?;
      final funcaoStr = dados['funcao'] as String?;

      if (ministerio == null || ministerio.isEmpty) return;
      if (funcaoStr == null || funcaoStr.isEmpty) return;

      final funcoes = funcaoStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (funcoes.length < 2) return;

      // Gera todos os pares possíveis
      for (int i = 0; i < funcoes.length; i++) {
        for (int j = i + 1; j < funcoes.length; j++) {
          final par = [funcoes[i], funcoes[j]]..sort();
          final f1 = par[0];
          final f2 = par[1];

          if (f1 == f2) continue;

          try {
            await _db.from('cfg_compatibilidades').insert({
              'ministerio': ministerio,
              'funcao1': f1,
              'funcao2': f2,
              'status': 'pendente',
            });
          } on PostgrestException catch (e) {
            // Se der erro 23505 (unique_violation), significa que o par já existe, ignoramos.
            if (e.code != '23505') {
              // Erro ao registrar par de função
            }
          }
        }
      }
    } catch (e) {
      // Erro em _registrarParesFuncoes
    }
  }
}
