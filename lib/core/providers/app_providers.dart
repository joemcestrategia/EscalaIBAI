import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agenda_item.dart';
import '../models/culto.dart';
import '../models/membro.dart';
import '../models/escala_item.dart';
import '../models/musica.dart';
import '../models/repertorio.dart';
import '../models/funcao.dart';
import '../models/regra.dart';
import '../models/compatibilidade.dart';
import '../models/ministerio.dart';
import '../models/cfg_jejum.dart';
import '../models/frequencia_registro.dart';
import '../repositories/agenda_repository.dart';
import '../repositories/cultos_repository.dart';
import '../repositories/ministerios_repository.dart';
import '../repositories/funcoes_repository.dart';
import '../repositories/regras_repository.dart';
import '../repositories/compatibilidades_repository.dart';
import '../repositories/cfg_jejum_repository.dart';
import '../repositories/membros_repository.dart';
import '../repositories/escala_repository.dart';
import '../repositories/musicas_repository.dart';
import '../repositories/repertorios_repository.dart';
import '../repositories/ausencias_repository.dart';
import '../repositories/frequencia_repository.dart';
import '../services/versiculo_service.dart';

// ─── Persistência ───────────────────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

enum UserRole { lider, membro }

class UserRoleNotifier extends StateNotifier<UserRole> {
  final SharedPreferences _prefs;
  static const _key = 'user_role';
  static const _selectedKey = 'has_selected_role';
  static const _membroIdKey = 'selected_membro_id';
  static const _membroNomeKey = 'selected_membro_nome';

  UserRoleNotifier(this._prefs) : super(UserRole.lider) {
    _loadRole();
  }

  bool get hasSelectedRole => _prefs.getBool(_selectedKey) ?? false;
  String? get selectedMembroId => _prefs.getString(_membroIdKey);
  String? get selectedMembroNome => _prefs.getString(_membroNomeKey);

  void _loadRole() {
    final roleStr = _prefs.getString(_key);
    if (roleStr != null) {
      state = UserRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => UserRole.lider,
      );
    }
  }

  Future<void> setRole(UserRole role, {String? membroId, String? membroNome}) async {
    state = role;
    await _prefs.setString(_key, role.name);
    await _prefs.setBool(_selectedKey, true);
    
    if (membroId != null) {
      await _prefs.setString(_membroIdKey, membroId);
    }
    if (membroNome != null) {
      await _prefs.setString(_membroNomeKey, membroNome);
    }
  }

  Future<void> logout() async {
    await _prefs.remove(_key);
    await _prefs.remove(_selectedKey);
    await _prefs.remove(_membroIdKey);
    await _prefs.remove(_membroNomeKey);
  }
}


final userRoleProvider = StateNotifierProvider<UserRoleNotifier, UserRole>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserRoleNotifier(prefs);
});

// ─── Data Global (Calendário / Escala) ──────────────────────────────────────
final globalSelectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ─── Preferências da Home ───────────────────────────────────────────────────
class HomePreferences {
  final bool mostrarEscalas;
  final bool mostrarEventos;
  final bool mostrarJejum;
  final bool mostrarRelatorio;
  final List<String> ministeriosVisiveis;

  HomePreferences({
    this.mostrarEscalas = true,
    this.mostrarEventos = true,
    this.mostrarJejum = true,
    this.mostrarRelatorio = true,
    this.ministeriosVisiveis = const [],
  });

  HomePreferences copyWith({
    bool? mostrarEscalas,
    bool? mostrarEventos,
    bool? mostrarJejum,
    bool? mostrarRelatorio,
    List<String>? ministeriosVisiveis,
  }) {
    return HomePreferences(
      mostrarEscalas: mostrarEscalas ?? this.mostrarEscalas,
      mostrarEventos: mostrarEventos ?? this.mostrarEventos,
      mostrarJejum: mostrarJejum ?? this.mostrarJejum,
      mostrarRelatorio: mostrarRelatorio ?? this.mostrarRelatorio,
      ministeriosVisiveis: ministeriosVisiveis ?? this.ministeriosVisiveis,
    );
  }
}

class HomePreferencesNotifier extends StateNotifier<HomePreferences> {
  final SharedPreferences _prefs;
  HomePreferencesNotifier(this._prefs) : super(HomePreferences()) {
    _load();
  }

  void _load() {
    state = HomePreferences(
      mostrarEscalas: _prefs.getBool('home_show_escalas') ?? true,
      mostrarEventos: _prefs.getBool('home_show_eventos') ?? true,
      mostrarJejum: _prefs.getBool('home_show_jejum') ?? true,
      mostrarRelatorio: _prefs.getBool('home_show_relatorio') ?? true,
      ministeriosVisiveis: _prefs.getStringList('home_ministerios_visiveis') ?? [],
    );
  }

  Future<void> toggleMinisterio(String ministerio) async {
    final atual = List<String>.from(state.ministeriosVisiveis);
    if (atual.contains(ministerio)) {
      atual.remove(ministerio);
    } else {
      atual.add(ministerio);
    }
    await _prefs.setStringList('home_ministerios_visiveis', atual);
    _load();
  }

  Future<void> setMinisterios(List<String> lista) async {
    await _prefs.setStringList('home_ministerios_visiveis', lista);
    _load();
  }

  Future<void> toggle(String key, bool value) async {
    await _prefs.setBool('home_show_$key', value);
    _load();
  }
}

final homePreferencesProvider =
    StateNotifierProvider<HomePreferencesNotifier, HomePreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HomePreferencesNotifier(prefs);
});



// ─── Repositórios ───────────────────────────────────────────────────────────
final agendaRepoProvider = Provider((_) => AgendaRepository());
final cultosRepoProvider = Provider((_) => CultosRepository());
final ministeriosRepoProvider = Provider((_) => MinisteriosRepository());
final funcoesRepoProvider = Provider((_) => FuncoesRepository());
final regrasRepoProvider = Provider((_) => RegrasRepository());
final compatibilidadesRepoProvider = Provider((_) => CompatibilidadesRepository());
final cfgJejumRepoProvider = Provider((_) => CfgJejumRepository());
final membrosRepoProvider = Provider((_) => MembrosRepository());
final escalaRepoProvider = Provider((_) => EscalaRepository());
final musicasRepoProvider = Provider((_) => MusicasRepository());
final repertoriosRepoProvider = Provider((_) => RepertoriosRepository());
final ausenciasRepoProvider = Provider((_) => AusenciasRepository());
final frequenciaRepoProvider = Provider((_) => FrequenciaRepository());

// ─── Dados ──────────────────────────────────────────────────────────────────
final agendaProvider = FutureProvider<List<AgendaItem>>((ref) async {
  return ref.read(agendaRepoProvider).getAll();
});

final proximasAtividadesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final itens = await ref.watch(agendaProvider.future);
  final proximas = <Map<String, dynamic>>[];
  
  for (var item in itens) {
    final datas = item.calcularProximasDatas(5);
    for (var data in datas) {
      proximas.add({
        'item': item,
        'data': data,
      });
    }
  }
  
  proximas.sort((a, b) {
    final dataA = a['data'] as DateTime;
    final dataB = b['data'] as DateTime;
    final cmp = dataA.compareTo(dataB);
    if (cmp != 0) return cmp;
    return (a['item'] as AgendaItem).horario.compareTo((b['item'] as AgendaItem).horario);
  });
  
  return proximas.where((e) {
    final data = e['data'] as DateTime;
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    return data.isAtSameMomentAs(hoje) || data.isAfter(hoje);
  }).toList();
});

final cultosProvider = FutureProvider<List<Culto>>((ref) async {
  return ref.read(cultosRepoProvider).getAll();
});

final ministeriosProvider = FutureProvider<List<Ministerio>>((ref) async {
  return ref.read(ministeriosRepoProvider).getAll();
});

final funcoesProvider = FutureProvider<List<Funcao>>((ref) async {
  return ref.read(funcoesRepoProvider).getAll();
});

final funcoesDoMinisterioProvider =
    FutureProvider.family<List<Funcao>, String>((ref, ministerio) async {
  return ref.read(funcoesRepoProvider).getByMinisterio(ministerio);
});

final regrasProvider = FutureProvider<List<Regra>>((ref) async {
  return ref.read(regrasRepoProvider).getAll();
});

final cfgJejumProvider = FutureProvider<CfgJejum>((ref) async {
  return ref.read(cfgJejumRepoProvider).get();
});

final compatibilidadesProvider = FutureProvider<List<Compatibilidade>>((ref) async {
  return ref.read(compatibilidadesRepoProvider).getAll();
});

final membrosProvider = FutureProvider<List<Membro>>((ref) async {
  return ref.read(membrosRepoProvider).getAll();
});

// Mês e ano selecionados na tela de escala
final escalaAnoProvider = StateProvider<int>((ref) => DateTime.now().year);
final escalaMesProvider = StateProvider<int>((ref) => DateTime.now().month);

final escalaDoMesProvider = StreamProvider<List<EscalaItem>>((ref) {
  final ano = ref.watch(escalaAnoProvider);
  final mes = ref.watch(escalaMesProvider);
  return ref.read(escalaRepoProvider).getByMesStream(ano, mes);
});

final proximaEscalaProvider = FutureProvider<List<EscalaItem>>((ref) async {
  final prefs = ref.watch(homePreferencesProvider);
  final repo = ref.read(escalaRepoProvider);
  return repo.getProximos(ministerios: prefs.ministeriosVisiveis);
});

final musicasProvider = FutureProvider<List<Musica>>((ref) async {
  return ref.read(musicasRepoProvider).getAll();
});

final repertoriosProvider = FutureProvider<List<Repertorio>>((ref) async {
  return ref.read(repertoriosRepoProvider).getAll();
});

final versiculoProvider = FutureProvider<Map<String, String>>((ref) async {
  return VersiculoService.getVersiculoDoDia();
});

// KPIs do mês
final kpiMesProvider = FutureProvider<Map<String, int>>((ref) async {
  final ano = ref.watch(escalaAnoProvider);
  final mes = ref.watch(escalaMesProvider);
  final repo = ref.read(escalaRepoProvider);
  final results = await Future.wait([
    repo.contarPorMes(ano, mes),
    repo.contarCultosPorMes(ano, mes),
    repo.contarFaltasPorMes(ano, mes),
  ]);
  return {
    'escalados': results[0],
    'cultos': results[1],
    'faltas': results[2],
  };
});

// Filtro de ministério na tela de membros
final membrosMinisterioFiltroProvider = StateProvider.autoDispose<String?>((ref) => null);

final membrosFiltradosProvider = Provider.autoDispose<AsyncValue<List<Membro>>>((ref) {
  final todos = ref.watch(membrosProvider);
  final filtro = ref.watch(membrosMinisterioFiltroProvider);
  return todos.whenData((lista) {
    if (filtro == null || filtro.isEmpty) return lista;
    return lista.where((m) => m.ministerio == filtro).toList();
  });
});

// Busca de membros
final membrosBuscaProvider = StateProvider.autoDispose<String>((ref) => '');

final escalaJejumDeHojeProvider = FutureProvider<List<EscalaItem>>((ref) async {
  return ref.read(escalaRepoProvider).getJejumDoDia();
});

final proximosJejunsProvider = FutureProvider<List<EscalaItem>>((ref) async {
  return ref.read(escalaRepoProvider).getProximosJejuns();
});


final compromissosDoMembroProvider =
    FutureProvider.family<List<EscalaItem>, String>((ref, nome) async {
  return ref.read(escalaRepoProvider).getByMembro(nome);
});

// ─── Frequência e Faltas ────────────────────────────────────────────────────
final frequenciaPeriodoProvider =
    StateProvider<PeriodoFrequencia>((ref) => PeriodoFrequencia.esteMes);

final frequenciaMinisterioFiltroProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final frequenciaRefreshProvider = StateProvider<int>((ref) => 0);

final relatorioFrequenciaProvider =
    FutureProvider.autoDispose<RelatorioFrequenciaResult>((ref) async {
  final todosMembros = await ref.watch(membrosProvider.future);
  final periodo = ref.watch(frequenciaPeriodoProvider);
  final ministerio = ref.watch(frequenciaMinisterioFiltroProvider);
  ref.watch(frequenciaRefreshProvider);
  ref.watch(escalaDoMesProvider);

  final intervalo = periodo.intervalo(DateTime.now());
  return ref.read(frequenciaRepoProvider).gerarRelatorio(
        todosMembros: todosMembros,
        inicio: intervalo.inicio,
        fim: intervalo.fim,
        ministerioFiltro: ministerio,
      );
});

final chamadaCultosRecentesProvider =
    FutureProvider.autoDispose<List<EscalaItem>>((ref) async {
  ref.watch(frequenciaRefreshProvider);
  ref.watch(escalaDoMesProvider);
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final inicio = hoje.subtract(const Duration(days: 45));
  String fmtIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return ref
      .read(escalaRepoProvider)
      .getPorPeriodo(fmtIso(inicio), fmtIso(hoje));
});
