import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://dsgqlylniqqjavxwlzku.supabase.co';
const String supabaseAnonKey = 'sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    print('--- Funções na tabela de Membros ---');
    final resMembros = await client.from('membros').select('nome, ministerio, funcao');
    final membros = resMembros as List;
    final funcoesMembros = <String>{};
    for (var m in membros) {
      if (m['funcao'] != null && m['funcao'].toString().isNotEmpty) {
        funcoesMembros.add('${m['ministerio']}: ${m['funcao']}');
      }
    }
    funcoesMembros.toList().sort();
    for (var f in funcoesMembros) {
      print(f);
    }

    print('\n--- Funções na tabela de Configurações (cfg_funcoes) ---');
    final resCfg = await client.from('cfg_funcoes').select('ministerio_pai, nome_funcao');
    final cfgs = resCfg as List;
    for (var c in cfgs) {
      print('${c['ministerio_pai']}: ${c['nome_funcao']}');
    }

  } catch (e) {
    print('Erro: $e');
  }
}
