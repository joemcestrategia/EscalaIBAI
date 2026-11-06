import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/musica.dart';

class MusicasRepository {
  final _db = Supabase.instance.client;

  Future<List<Musica>> getAll() async {
    final data = await _db.from('musicas').select();
    final lista = (data as List)
        .map((e) => Musica.fromMap(e as Map<String, dynamic>))
        .toList();
    
    lista.sort((a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));
    return lista;
  }

  Future<void> inserir(Map<String, dynamic> dados) async {
    await _db.from('musicas').insert(dados);
  }

  Future<void> atualizar(String id, Map<String, dynamic> dados) async {
    await _db.from('musicas').update(dados).eq('id', id);
  }

  Future<void> excluir(String id) async {
    await _db.from('musicas').delete().eq('id', id);
  }
}
