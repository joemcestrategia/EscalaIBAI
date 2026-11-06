import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://dsgqlylniqqjavxwlzku.supabase.co';
const String supabaseAnonKey = 'sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    print('--- Ministérios em cfg_ministerios ---');
    final resMins = await client.from('cfg_ministerios').select('nome');
    final mins = resMins as List;
    for (var m in mins) {
      print(m['nome']);
    }

    print('\n--- Membros e seus Ministérios/Funções ---');
    final resMem = await client.from('membros').select('nome, ministerio, funcao');
    final mems = resMem as List;
    for (var m in mems) {
      print('Membro: ${m['nome']} | Min: ${m['ministerio']} | Fun: ${m['funcao']}');
    }

  } catch (e) {
    print('Erro: $e');
  }
}
