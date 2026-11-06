import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://dsgqlylniqqjavxwlzku.supabase.co';
const String supabaseAnonKey = 'sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    print('Cadastrando o ministério Jejum nas configurações oficiais...');
    
    await client.from('cfg_ministerios').upsert({
      'nome': 'Jejum'
    });
    
    print('Sucesso! O ministério Jejum agora é oficial.');

  } catch (e) {
    print('Erro: $e');
  }
}
