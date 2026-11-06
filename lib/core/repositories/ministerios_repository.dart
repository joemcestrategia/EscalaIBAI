import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ministerio.dart';

class MinisteriosRepository {
  final _db = Supabase.instance.client;

  Future<List<Ministerio>> getAll() async {
    final data = await _db.from('cfg_ministerios').select().order('nome');
    return (data as List).map((e) => Ministerio.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> inserir(Ministerio ministerio) async {
    await _db.from('cfg_ministerios').insert(ministerio.toMap());
  }

  Future<void> atualizarIcone(String nome, String icone) async {
    await _db.from('cfg_ministerios').update({'icone': icone}).eq('nome', nome);
  }

  Future<void> excluir(String nome) async {
    await _db.from('cfg_ministerios').delete().eq('nome', nome);
  }
}
