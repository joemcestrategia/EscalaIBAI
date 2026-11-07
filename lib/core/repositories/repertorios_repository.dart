import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/repertorio.dart';
import '../services/notification_service.dart';

class RepertoriosRepository {
  final _db = Supabase.instance.client;

  Future<List<Repertorio>> getAll() async {
    final data = await _db
        .from('repertorios')
        .select()
        .order('data_culto', ascending: false)
        .order('hora_culto');
    return (data as List)
        .map((e) => Repertorio.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Repertorio?> getByDataHora(String data, String hora) async {
    final res = await _db
        .from('repertorios')
        .select()
        .eq('data_culto', data)
        .eq('hora_culto', hora)
        .maybeSingle();
    if (res == null) return null;
    return Repertorio.fromMap(res);
  }

  Future<void> upsert({
    required String data,
    required String hora,
    required List<Map<String, dynamic>> listaMusicas,
  }) async {
    // 1. Salva no banco
    await _db.from('repertorios').upsert({
      'data_culto': data,
      'hora_culto': hora,
      'lista_musicas': listaMusicas,
    }, onConflict: 'data_culto,hora_culto');

    // 2. Dispara notificação push para todos quando há músicas na playlist
    if (listaMusicas.isNotEmpty) {
      // Cancela cobrança local de playlist pendente para este culto
      NotificationService.cancelarCobrancaPlaylist(data, hora);

      try {
        await _db.functions.invoke('notificar-repertorio', body: {
          'dataCulto': data,
          'horaCulto': hora,
          'qtdMusicas': listaMusicas.length,
        });
      } catch (e) {
        // Falha silenciosa para não quebrar a UI
        debugPrint('Erro ao invocar notificar-repertorio: $e');
      }
    }
  }

  Future<void> excluir(String id) async {
    await _db.from('repertorios').delete().eq('id', id);
  }
}
