import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://dsgqlylniqqjavxwlzku.supabase.co';
const String supabaseAnonKey = 'sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  final hojeStr = DateTime.now().toIso8601String().split('T')[0];

  try {
    print('Verificando escalas a partir de: $hojeStr');
    
    final res = await client
        .from('escala')
        .select('id, data, ministerio, nome')
        .gte('data', hojeStr)
        .order('data');
    
    final escalas = res as List;
    print('Encontradas ${escalas.length} escalas futuras.');

    if (escalas.isNotEmpty) {
      print('Exemplos de escalas encontradas:');
      for (var i = 0; i < (escalas.length > 5 ? 5 : escalas.length); i++) {
        print('${escalas[i]['data']} - ${escalas[i]['ministerio']} - ${escalas[i]['nome']}');
      }
    } else {
      print('AVISO: Nenhuma escala encontrada para hoje ou futuro!');
    }

  } catch (e) {
    print('Erro: $e');
  }
}
