import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ausencia.dart';

class AusenciasRepository {
  final _db = Supabase.instance.client;

  Future<List<Ausencia>> getAll() async {
    final data =
        await _db.from('ausencias').select().order('data', ascending: false);
    return (data as List)
        .map((e) => Ausencia.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> inserir({required String nome, required String motivo}) async {
    await _db.from('ausencias').insert({
      'nome': nome,
      'data': DateTime.now().toIso8601String().split('T')[0],
      'motivo': motivo,
    });
  }

  Future<void> excluir(String id) async {
    await _db.from('ausencias').delete().eq('id', id);
  }
}
