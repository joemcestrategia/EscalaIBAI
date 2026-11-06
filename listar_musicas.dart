import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() async {
  const url = 'https://dsgqlylniqqjavxwlzku.supabase.co/rest/v1/musicas';
  const key = 'sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q';

  final res = await http.get(
    Uri.parse('$url?select=id,titulo,artista&order=titulo'),
    headers: {
      'apikey': key,
      'Authorization': 'Bearer $key',
    },
  );

  if (res.statusCode == 200) {
    final List data = jsonDecode(res.body);
    print('Total de músicas: ${data.length}');
    for (final m in data) {
      print('${m['titulo']} | ${m['artista']} | tempo: "${m['tempo']}"');
    }
  } else {
    print('Erro: ${res.statusCode} — ${res.body}');
  }
  exit(0);
}
