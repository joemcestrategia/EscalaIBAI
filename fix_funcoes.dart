import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://dsgqlylniqqjavxwlzku.supabase.co';
const String supabaseAnonKey = 'sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    print('Limpando funções indevidas...');
    
    // 1. Membros do ministério Jejum não devem ter "Jejum" como função
    final res = await client
        .from('membros')
        .update({'funcao': ''})
        .eq('ministerio', 'Jejum')
        .eq('funcao', 'Jejum');
    
    print('Ajuste concluído para o ministério Jejum.');

    // 2. Verificar se há "Jejum" como função em outros ministérios (limpeza preventiva)
    // Buscamos todos os membros para fazer um tratamento de string se necessário
    final resTodos = await client.from('membros').select('id, funcao');
    final todos = resTodos as List;
    
    for (var m in todos) {
      String func = m['funcao'] ?? '';
      if (func.contains('Jejum')) {
        // Remove a palavra "Jejum" da lista de funções (caso seja uma lista separada por vírgula)
        String novaFunc = func.split(',')
            .map((e) => e.trim())
            .where((e) => e != 'Jejum')
            .join(', ');
        
        if (novaFunc != func) {
          await client.from('membros').update({'funcao': novaFunc}).eq('id', m['id']);
          print('Removida função Jejum do membro ID: ${m['id']}');
        }
      }
    }

    print('Todos os ajustes de funções foram concluídos.');

  } catch (e) {
    print('Erro: $e');
  }
}
