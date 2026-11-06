import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agenda_item.dart';

class AgendaRepository {
  final _db = Supabase.instance.client;

  Future<List<AgendaItem>> getAll() async {
    final data = await _db
        .from('agenda_igreja')
        .select()
        .order('tipo')
        .order('horario');
    return (data as List)
        .map((e) => AgendaItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> inserir(AgendaItem item) async {
    await _db.from('agenda_igreja').insert(item.toMap());
  }

  Future<void> atualizar(String id, Map<String, dynamic> dados) async {
    await _db.from('agenda_igreja').update(dados).eq('id', id);
  }

  Future<void> excluir(String id) async {
    await _db.from('agenda_igreja').delete().eq('id', id);
  }
}
