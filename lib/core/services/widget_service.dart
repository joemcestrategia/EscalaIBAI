import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/escala_item.dart';

class WidgetService {
  static const String _appGroupId = 'group.com.igreja.escala'; // Usado para iOS se for ativado no futuro
  static const String _androidWidgetName = 'EscalaWidgetProvider';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  static Future<void> updateEscalasWidget(List<EscalaItem> escalas) async {
    try {
      debugPrint('🟦 WidgetService.updateEscalasWidget: recebeu ${escalas.length} itens.');

      // Filtrar apenas as escalas a partir de hoje
      final hoje = DateTime.now();
      final hojeString =
          '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

      debugPrint('🟦 Data de hoje: $hojeString');

      final futuras =
          escalas.where((e) => e.data.compareTo(hojeString) >= 0).toList();
      debugPrint('🟦 Escalas a partir de hoje: ${futuras.length}');

      // Ordenar por data e horário
      futuras.sort((a, b) {
        final dataComp = a.data.compareTo(b.data);
        if (dataComp != 0) return dataComp;
        return a.horario.compareTo(b.horario);
      });

      // Agrupar por data e horário
      final mapDias = <String, Map<String, dynamic>>{};
      
      for (var e in futuras) {
        final key = '${e.data}_${e.horario}';
        if (!mapDias.containsKey(key)) {
          mapDias[key] = {
            'data': e.data,
            'dia_semana': e.diaSemana,
            'horario': e.horario,
            'tema': e.tema.isNotEmpty ? e.tema : 'Culto',
            '_ministerios_map': <String, List<String>>{},
          };
        }
        
        final mMap = mapDias[key]!['_ministerios_map'] as Map<String, List<String>>;
        if (!mMap.containsKey(e.ministerio)) {
          mMap[e.ministerio] = [];
        }
        
        final texto = e.nome.isNotEmpty ? '<b>${e.nome}</b> <small>- ${e.funcao}</small>' : '<small>${e.funcao}</small>';
        mMap[e.ministerio]!.add(texto);
      }

      // Converter map interno de ministérios para o formato JSON final
      final jsonData = mapDias.values.map((dia) {
        final mMap = dia['_ministerios_map'] as Map<String, List<String>>;
        final listaMinisterios = mMap.entries.map((entry) => {
          'nome_min': entry.key,
          'pessoas': entry.value.join('<br>')
        }).toList();
        
        return {
          'data': dia['data'],
          'dia_semana': dia['dia_semana'],
          'horario': dia['horario'],
          'tema': dia['tema'],
          'ministerios': listaMinisterios,
        };
      }).toList();
      
      // Limitar a 10 dias para não estourar o limite do widget
      if (jsonData.length > 10) {
        jsonData.removeRange(10, jsonData.length);
      }

      final jsonString = jsonEncode(jsonData);
      debugPrint(
          '🟦 JSON (primeiros 200 chars): ${jsonString.substring(0, jsonString.length > 200 ? 200 : jsonString.length)}');

      // Salvar os dados no SharedPreferences do widget
      await HomeWidget.saveWidgetData<String>('escalas_data', jsonString);
      await HomeWidget.saveWidgetData<int>('current_escala_index', 0);

      // Solicitar atualização visual do widget
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
      );

      debugPrint(
          '✅ WidgetService: Widget atualizado com ${jsonData.length} cultos futuros (agrupados).');
    } catch (e) {
      debugPrint('❌ Erro ao atualizar o widget: $e');
    }
  }
}
