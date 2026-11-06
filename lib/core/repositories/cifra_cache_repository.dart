import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cifra_cache.dart';

class CifraCacheRepository {
  final _db = Supabase.instance.client;

  /// Busca cache por videoId. Retorna null se não existe.
  Future<CifraCache?> getByVideoId(String videoId) async {
    try {
      final res = await _db
          .from('cifra_cache')
          .select()
          .eq('video_id', videoId)
          .maybeSingle();
      if (res == null) return null;
      return CifraCache.fromMap(res as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Retorna todos os caches para uso no fuzzy local
  Future<List<CifraCache>> getAll() async {
    try {
      final res = await _db.from('cifra_cache').select();
      return (res as List)
          .map((e) => CifraCache.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Salva ou atualiza o cache para um videoId.
  /// Se já existe uma entrada confirmada (manual), não sobrescreve.
  Future<void> upsert(CifraCache cache) async {
    try {
      // Não sobrescrever entradas confirmadas manualmente com dados automáticos
      if (cache.origem != 'manual') {
        final existing = await getByVideoId(cache.videoId);
        if (existing != null && existing.confirmado) return;
      }
      await _db.from('cifra_cache').upsert(
        cache.toMap(),
        onConflict: 'video_id',
      );
    } catch (_) {}
  }

  /// Confirma manualmente o nome de cifra/letra (qualquer membro pode corrigir)
  Future<void> confirmar({
    required String videoId,
    required String nomeCifra,
    required String artistaCifra,
  }) async {
    await _db.from('cifra_cache').upsert(
      {
        'video_id': videoId,
        'nome_cifra': nomeCifra,
        'artista_cifra': artistaCifra,
        'origem': 'manual',
        'confirmado': true,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'video_id',
    );
  }
}
