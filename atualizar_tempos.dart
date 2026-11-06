import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() async {
  const url = 'https://dsgqlylniqqjavxwlzku.supabase.co/rest/v1/musicas';
  const key = 'sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q';

  // Mapa: título (lowercase) -> tempo (MM:SS)
  final tempos = {
    'adoramos o cordeiro': '07:04',
    'ao que está assentado sobre o trono + nada vai roubar tua glória': '09:01',
    'aqui vou eu': '04:40',
    'celebrai': '02:50',
    'conhecerei': '07:30',
    'consagração': '05:52',
    'digno de tudo + te exaltamos': '09:05',
    'digno é o senhor/ senhor e rei': '09:09',
    'espírito, enche a minha vida+ ao único.': '04:50',
    'essência da adoração': '08:50',
    'estrela da manhã': '03:28',
    'eu me rendo': '06:13',
    'marca de promessa': '05:14',
    'me derramar': '05:28',
    'nada além do sangue': '04:39',
    'não há outro': '03:57',
    'oferta de amor': '05:00',
    'poder pra salvar': '05:59',
    'quero conhecer jesus': '06:07',
    'se não for pra te adorar': '06:00',
    'sobre as águas': '07:15',
    'sonda-me': '04:30',
    'tudo é perda': '05:42',
  };

  // Busca todas as músicas
  final res = await http.get(
    Uri.parse('$url?select=id,titulo&order=titulo'),
    headers: {
      'apikey': key,
      'Authorization': 'Bearer $key',
    },
  );

  if (res.statusCode != 200) {
    print('Erro ao buscar músicas: ${res.statusCode} — ${res.body}');
    exit(1);
  }

  final List musicas = jsonDecode(res.body);
  print('Atualizando ${musicas.length} músicas...\n');

  int ok = 0;
  int naoEncontrado = 0;

  for (final m in musicas) {
    final id = m['id'] as String;
    final titulo = m['titulo'] as String;
    final tituloKey = titulo.toLowerCase();

    final tempo = tempos[tituloKey];

    if (tempo == null) {
      print('⚠️  Sem tempo definido para: "$titulo"');
      naoEncontrado++;
      continue;
    }

    final patch = await http.patch(
      Uri.parse('$url?id=eq.$id'),
      headers: {
        'apikey': key,
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: jsonEncode({'tempo': tempo}),
    );

    if (patch.statusCode == 204) {
      print('✅ "$titulo" → $tempo');
      ok++;
    } else {
      print('❌ Erro ao atualizar "$titulo": ${patch.statusCode} — ${patch.body}');
    }
  }

  print('\n─────────────────────────');
  print('Atualizadas: $ok | Sem tempo: $naoEncontrado');
  exit(0);
}
