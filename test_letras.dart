import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  String formatarParaLetras(String text) {
    var s = text.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[áàâãä]'), 'a');
    s = s.replaceAll(RegExp(r'[éèêë]'), 'e');
    s = s.replaceAll(RegExp(r'[íìîï]'), 'i');
    s = s.replaceAll(RegExp(r'[óòôõö]'), 'o');
    s = s.replaceAll(RegExp(r'[úùûü]'), 'u');
    s = s.replaceAll(RegExp(r'[ç]'), 'c');
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    s = s.replaceAll(RegExp(r'\s+'), '-');
    s = s.replaceAll(RegExp(r'-+'), '-');
    if (s.startsWith('-')) s = s.substring(1);
    if (s.endsWith('-')) s = s.substring(0, s.length - 1);
    return s;
  }

  final musicas = [
    {'titulo': 'Tudo é Perda', 'artista': 'Felipe Rodrigues'},
    {'titulo': 'Essência da Adoração', 'artista': 'Gabi Sampaio'},
    {'titulo': 'Conhecerei', 'artista': 'Diante do Trono'},
    {'titulo': 'Marca de Promessa', 'artista': 'DAVI SACER'},
  ];

  for (var m in musicas) {
    final art = formatarParaLetras(m['artista']!);
    final tit = formatarParaLetras(m['titulo']!);
    final url = Uri.parse('https://www.letras.mus.br/$art/$tit/');
    
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        print('✅ [200 OK] ${m['titulo']} - ${m['artista']} -> ${url.toString()}');
      } else {
        print('❌ [${res.statusCode}] ${m['titulo']} - ${m['artista']} -> ${url.toString()}');
      }
    } catch (e) {
      print('❌ [ERRO] ${m['titulo']} - ${m['artista']} -> $e');
    }
  }
  exit(0);
}
