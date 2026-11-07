import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_widgets.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  int _mes = DateTime.now().month;
  int _ano = DateTime.now().year;

  // Provider local para o ranking
  late final _rankingProvider =
      FutureProvider.family<List<MapEntry<String, int>>, String>(
          (ref, key) async {
    final parts = key.split('_');
    final ano = int.parse(parts[0]);
    final mes = int.parse(parts[1]);
    final data = await ref.read(escalaRepoProvider).getByMes(ano, mes);
    final map = <String, int>{};
    for (final e in data) {
      if (e.nome == '[FALTA]') continue;
      map[e.nome] = (map[e.nome] ?? 0) + 1;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  });

  @override
  Widget build(BuildContext context) {
    final key = '${_ano}_$_mes';
    final rankingAsync = ref.watch(_rankingProvider(key));
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return Scaffold(
      backgroundColor: context.bgPrincipal,
      appBar: AppBar(
        title: Text('Participações no Mês', style: AppTextStyles.heading()),
      ),
      body: Column(
        children: [
          // Seletor de mês/ano
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    initialValue: _mes,
                    style: AppTextStyles.body(color: context.textoPrimario),
                    dropdownColor: context.bgCard,
                    decoration: const InputDecoration(labelText: 'Mês'),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(meses[i]),
                      ),
                    ),
                    onChanged: (v) => setState(() => _mes = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: _ano,
                    style: AppTextStyles.body(color: context.textoPrimario),
                    dropdownColor: context.bgCard,
                    decoration: const InputDecoration(labelText: 'Ano'),
                    items: List.generate(
                      5,
                      (i) => DropdownMenuItem(
                        value: DateTime.now().year - 2 + i,
                        child: Text('${DateTime.now().year - 2 + i}'),
                      ),
                    ),
                    onChanged: (v) => setState(() => _ano = v!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: rankingAsync.when(
              data: (lista) {
                if (lista.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIconsRegular.trophy,
                            color: context.textoMuted,
                            size: 52,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Nenhuma escala registrada em ${meses[_mes - 1]} de $_ano.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body(
                              color: context.textoSecund,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(_rankingProvider(key)),
                            child: const Text('Atualizar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final max = lista.first.value;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final entry = lista[i];
                    final pct = max > 0 ? entry.value / max : 0.0;
                    final Color corDestaque;
                    IconData? icone;

                    if (i == 0) {
                      corDestaque = context.isDark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFD97706);
                      icone = PhosphorIconsFill.trophy;
                    } else if (i == 1) {
                      corDestaque = context.isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569);
                      icone = PhosphorIconsFill.medal;
                    } else if (i == 2) {
                      corDestaque = context.isDark
                          ? const Color(0xFFFB923C)
                          : const Color(0xFFB45309);
                      icone = PhosphorIconsFill.medal;
                    } else {
                      corDestaque = context.corPrimaria;
                      icone = null;
                    }

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 250 + (i * 45).clamp(0, 450)),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, (1 - v) * 16),
                          child: child,
                        ),
                      ),
                      child: AppSurfaceCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        borderRadius: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: i < 3
                                        ? corDestaque.withValues(alpha: 0.14)
                                        : context.bgSubtle,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: icone != null
                                      ? Icon(icone, color: corDestaque, size: 19)
                                      : Text(
                                          '${i + 1}º',
                                          style: AppTextStyles.bodySmall(
                                            color: context.textoSecund,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                AppAvatar(name: entry.key, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: AppTextStyles.subheading(
                                      color: context.textoPrimario,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: corDestaque.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${entry.value}×',
                                    style: AppTextStyles.mono(
                                      color: corDestaque,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: context.bgSubtle,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(corDestaque),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.acento),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erro: $e',
                  style: AppTextStyles.body(color: AppColors.perigo),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
