import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://dsgqlylniqqjavxwlzku.supabase.co';
const String supabaseAnonKey = 'sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q';

void main() async {
  print('Iniciando restauração de membros...');
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    // 1. Buscar nomes das escalas
    print('Buscando dados das escalas...');
    final resEscalas = await client.from('escala').select('nome, ministerio, funcao');
    final registros = resEscalas as List;
    print('Encontrados ${registros.length} registros de escala.');

    // 2. Buscar membros existentes
    print('Verificando membros atuais...');
    final resMembros = await client.from('membros').select('nome');
    final listaMembros = resMembros as List;
    final setNomes = listaMembros.map((m) => (m['nome'] as String).toLowerCase().trim()).toSet();
    print('Existem ${setNomes.length} membros cadastrados.');

    // 3. Filtrar novos membros
    final mapaNovos = <String, Map<String, dynamic>>{};
    for (var reg in registros) {
      final nome = (reg['nome'] as String? ?? '').trim();
      if (nome.isEmpty || nome == '[FALTA]' || setNomes.contains(nome.toLowerCase())) continue;

      if (!mapaNovos.containsKey(nome.toLowerCase())) {
        mapaNovos[nome.toLowerCase()] = {
          'nome': nome,
          'ministerio': reg['ministerio'] ?? '',
          'funcao': reg['funcao'] ?? '',
          'dias_indisponiveis': '',
          'escala_trabalho': 'Sem restrição',
        };
      }
    }

    // 4. Inserir novos membros
    if (mapaNovos.isNotEmpty) {
      final listaParaInserir = mapaNovos.values.toList();
      print('Inserindo ${listaParaInserir.length} novos membros...');
      await client.from('membros').insert(listaParaInserir);
      print('Sucesso! ${listaParaInserir.length} membros restaurados.');
    } else {
      print('Nenhum novo membro para restaurar.');
    }
  } catch (e) {
    print('Erro durante a restauração: $e');
  }
}
