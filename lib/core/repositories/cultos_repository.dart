import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/culto.dart';

class CultosRepository {
  final _db = Supabase.instance.client;

  Future<List<Culto>> getAll() async {
    final data = await _db
        .from('cfg_cultos')
        .select()
        .order('dia_semana')
        .order('horario');
    return (data as List)
        .map((e) => Culto.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> inserir({
    required String diaSemana,
    required String horario,
    String tema = 'Geral',
  }) async {
    await _db.from('cfg_cultos').insert({
      'dia_semana': diaSemana,
      'horario': horario,
      'tema': tema,
    });
  }

  Future<void> atualizar(String id, Map<String, dynamic> dados) async {
    await _db.from('cfg_cultos').update(dados).eq('id', id);
  }

  Future<void> excluir(String id) async {
    await _db.from('cfg_cultos').delete().eq('id', id);
  }
}
