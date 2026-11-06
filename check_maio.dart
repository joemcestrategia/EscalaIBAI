import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://dsgqlylniqqjavxwlzku.supabase.co';
const String supabaseAnonKey = 'sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    print('Buscando escalas de MAIO de 2026...');
    
    final res = await client
        .from('escala')
        .select('data, ministerio, nome')
        .gte('data', '2026-05-01')
        .lte('data', '2026-05-30')
        .order('data');
    
    final escalas = res as List;
    if (escalas.isEmpty) {
      print('CONFIRMADO: Não existem escalas cadastradas entre 01/05 e 30/05.');
    } else {
      print('Encontradas ${escalas.length} escalas em Maio antes do dia 31.');
      for (var e in escalas) {
        print('${e['data']} - ${e['ministerio']}');
      }
    }

  } catch (e) {
    print('Erro: $e');
  }
}
