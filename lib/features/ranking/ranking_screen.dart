import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';

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
    final meses = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];

    return Scaffold(
      backgroundColor: context.bgPrincipal,
      appBar: AppBar(
        title: Text('Ranking', style: AppTextStyles.heading()),
      ),
      body: Column(
        children: [
          // Seletor de mês/ano
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _mes,
                  style: AppTextStyles.body(),
                  dropdownColor: context.bgCard,
                  decoration: const InputDecoration(labelText: 'Mês'),
                  items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(meses[i]),
                          )),
                  onChanged: (v) => setState(() => _mes = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _ano,
                  style: AppTextStyles.body(),
                  dropdownColor: context.bgCard,
                  decoration: const InputDecoration(labelText: 'Ano'),
                  items: List.generate(
                      5,
                      (i) => DropdownMenuItem(
                            value: DateTime.now().year - 2 + i,
                            child: Text('${DateTime.now().year - 2 + i}'),
                          )),
                  onChanged: (v) => setState(() => _ano = v!),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: rankingAsync.when(
              data: (lista) {
                if (lista.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(PhosphorIconsBold.trophy,
                            color: AppColors.textoMuted, size: 48),
                        const SizedBox(height: 12),
                        Text('Nenhuma escala em $meses[_mes - 1] de $_ano.',
                            style: AppTextStyles.body(
                                color: context.textoSecund)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(_rankingProvider(key)),
                          child: const Text('Tentar Novamente'),
                        ),
                      ],
                    ),
                  );
                }
                final max = lista.first.value;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final entry = lista[i];
                    final pct = max > 0 ? entry.value / max : 0.0;
                    Color cor;
                    IconData? icone;
                    if (i == 0) {
                      cor = const Color(0xFFFFD700);
                      icone = PhosphorIconsBold.trophy;
                    } else if (i == 1) {
                      cor = const Color(0xFFC0C0C0);
                      icone = PhosphorIconsBold.medal;
                    } else if (i == 2) {
                      cor = const Color(0xFFCD7F32);
                      icone = PhosphorIconsBold.medal;
                    } else {
                      cor = context.textoSecund;
                      icone = null;
                    }

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + i * 60),
                      curve: Curves.easeOut,
                      builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, (1 - v) * 20),
                          child: child,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: context.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: i < 3
                                ? cor.withValues(alpha: 0.4)
                                : context.bgBorda,
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 30,
                                alignment: Alignment.center,
                                child: icone != null
                                    ? Icon(icone, color: cor, size: 20)
                                    : Text('${i + 1}',
                                        style: AppTextStyles.mono(color: cor)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(entry.key,
                                    style: AppTextStyles.body()),
                              ),
                              Text(
                                '${entry.value}×',
                                style: AppTextStyles.mono(color: cor),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: context.bgBorda,
                                valueColor: AlwaysStoppedAnimation<Color>(cor),
                                minHeight: 5,
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
                  child: CircularProgressIndicator(color: AppColors.acento)),
              error: (e, _) =>
                  Center(child: Text('Erro: $e', style: AppTextStyles.body())),
            ),
          ),
        ],
      ),
    );
  }
}
