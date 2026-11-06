import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/compatibilidade.dart';

class CompatibilidadesRepository {
  final _db = Supabase.instance.client;

  Future<List<Compatibilidade>> getAll() async {
    final data = await _db.from('cfg_compatibilidades').select().order('created_at');
    return (data as List).map((e) => Compatibilidade.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> inserirSeNaoExiste({
    required String ministerio,
    required String funcao1,
    required String funcao2,
  }) async {
    await inserirComStatus(
      ministerio: ministerio,
      funcao1: funcao1,
      funcao2: funcao2,
      status: 'pendente',
    );
  }

  Future<void> inserirComStatus({
    required String ministerio,
    required String funcao1,
    required String funcao2,
    required String status,
  }) async {
    // Ordenar alfabeticamente para evitar salvar (A, B) e (B, A)
    final lista = [funcao1.trim(), funcao2.trim()]..sort();
    final f1 = lista[0];
    final f2 = lista[1];

    if (f1.isEmpty || f2.isEmpty || f1 == f2) return;

    try {
      await _db.from('cfg_compatibilidades').insert({
        'ministerio': ministerio,
        'funcao1': f1,
        'funcao2': f2,
        'status': status,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Ignora duplicidade
      } else {
        rethrow;
      }
    }
  }

  Future<void> atualizarStatus(String id, String novoStatus) async {
    await _db.from('cfg_compatibilidades').update({'status': novoStatus}).eq('id', id);
  }

  Future<void> excluir(String id) async {
    await _db.from('cfg_compatibilidades').delete().eq('id', id);
  }
}
