import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/escala_item.dart';

class WhatsappService {
  static String _getIconeFuncao(String funcao, String ministerio) {
    final f = funcao.toLowerCase();
    final m = ministerio.toLowerCase();

    if (m.contains('jejum')) return '☕';
    if (f.contains('guitarra') || f.contains('violão') || f.contains('violao') || f.contains('baixo')) return '🎸';
    if (f.contains('bateria')) return '🥁';
    if (f.contains('teclado') || f.contains('piano')) return '🎹';
    if (f.contains('voz') || f.contains('canto') || f.contains('back') || f.contains('ministro')) return '🎤';
    if (f.contains('pregador') || f.contains('pastor') || f.contains('palavra')) return '📖';
    if (f.contains('infantil') || f.contains('criança') || f.contains('tias') || f.contains('tio')) return '👶';
    if (f.contains('som') || f.contains('mesa') || f.contains('áudio') || f.contains('audio')) return '🎛️';
    if (f.contains('mídia') || f.contains('midia') || f.contains('projeção') || f.contains('letra')) return '💻';
    
    return '👤';
  }

  static Future<void> compartilharEscala({
    required List<EscalaItem> itens,
    required int mes,
    required int ano,
  }) async {
    final meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final mesStr = meses[mes - 1];

    // Filtra apenas itens do mês/ano
    final filtrados = itens.where((e) {
      final d = DateTime.tryParse(e.data);
      if (d == null) return false;
      return d.month == mes && d.year == ano;
    }).toList();

    // Ordena por data e horário
    filtrados.sort((a, b) {
      final cmpData = a.data.compareTo(b.data);
      if (cmpData != 0) return cmpData;
      return a.horario.compareTo(b.horario);
    });

    // Agrupa por Data -> Horário -> Ministério
    final porData = <String, Map<String, Map<String, List<EscalaItem>>>>{};
    for (final item in filtrados) {
      final d = item.data;
      final h = item.horario;
      final m = item.ministerio;

      porData.putIfAbsent(d, () => {});
      porData[d]!.putIfAbsent(h, () => {});
      porData[d]![h]!.putIfAbsent(m, () => []).add(item);
    }

    final buffer = StringBuffer();
    buffer.writeln('📅 *ESCALA MENSAL — $mesStr / $ano* 📅');
    buffer.writeln();

    for (final dataKey in porData.keys.toList()..sort()) {
      final dateObj = DateTime.parse(dataKey);
      final dataStr = DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(dateObj);

      buffer.writeln('━━━━ *${dataStr.toUpperCase()}* ━━━━');

      final porHorario = porData[dataKey]!;
      for (final hora in porHorario.keys.toList()..sort()) {
        final minMap = porHorario[hora]!;
        final primeiroTema = minMap.values.first.first.tema;
        
        if (primeiroTema.isNotEmpty) {
          buffer.writeln('⏰ $hora — _Tema: ${primeiroTema}_');
        } else {
          buffer.writeln('⏰ $hora');
        }

        for (final min in minMap.keys.toList()..sort()) {
          buffer.writeln('\n📌 *${min.toUpperCase()}*');
          
          final itensMin = minMap[min]!;
          for (final item in itensMin) {
            final emoji = _getIconeFuncao(item.funcao, item.ministerio);
            if (item.nome == '[FALTA]') {
              buffer.writeln('❌ *VAGA ABERTA* (${item.funcao})');
            } else {
              buffer.writeln('$emoji *${item.nome}* (${item.funcao})');
            }
          }
        }
        buffer.writeln();
      }
      buffer.writeln();
    }

    final texto = Uri.encodeComponent(buffer.toString());
    final url = Uri.parse('https://wa.me/?text=$texto');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Não foi possível abrir o WhatsApp.';
    }
  }
}
