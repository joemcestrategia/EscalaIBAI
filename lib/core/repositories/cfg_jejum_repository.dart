import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cfg_jejum.dart';

class CfgJejumRepository {
  final _db = Supabase.instance.client;

  Future<CfgJejum> get() async {
    final data = await _db.from('cfg_jejum').select().limit(1).maybeSingle();
    if (data == null) {
      // Tenta criar um padrão caso não exista
      final res = await _db.from('cfg_jejum').insert({'qtd_membros': 1}).select().single();
      return CfgJejum.fromMap(res);
    }
    return CfgJejum.fromMap(data);
  }

  Future<void> atualizar(int novaQtd) async {
    final config = await get();
    await _db.from('cfg_jejum').update({'qtd_membros': novaQtd}).eq('id', config.id);
  }
}
