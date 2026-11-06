import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/regra.dart';

class RegrasRepository {
  final _db = Supabase.instance.client;

  Future<List<Regra>> getAll() async {
    final data = await _db
        .from('cfg_regras')
        .select()
        .order('dia_semana')
        .order('horario');
    return (data as List)
        .map((e) => Regra.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> inserir(Regra regra) async {
    await _db.from('cfg_regras').insert(regra.toMap());
  }

  Future<void> excluir(String id) async {
    await _db.from('cfg_regras').delete().eq('id', id);
  }
  Future<void> atualizar(String id, Map<String, dynamic> dados) async {
    await _db.from('cfg_regras').update(dados).eq('id', id);
  }
}
