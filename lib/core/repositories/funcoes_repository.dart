import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/funcao.dart';

class FuncoesRepository {
  final _db = Supabase.instance.client;

  Future<List<Funcao>> getByMinisterio(String ministerio) async {
    final data = await _db
        .from('cfg_funcoes')
        .select()
        .eq('ministerio_pai', ministerio)
        .order('nome_funcao');
    return (data as List)
        .map((e) => Funcao.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Funcao>> getAll() async {
    final data = await _db.from('cfg_funcoes').select().order('nome_funcao');
    return (data as List)
        .map((e) => Funcao.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> inserir(
      {required String ministerioPai, required String nomeFuncao}) async {
    await _db.from('cfg_funcoes').insert({
      'ministerio_pai': ministerioPai,
      'nome_funcao': nomeFuncao,
    });
  }

  Future<void> excluir(String id) async {
    await _db.from('cfg_funcoes').delete().eq('id', id);
  }
}
