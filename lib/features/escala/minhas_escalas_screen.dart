import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/escala_item.dart';
import 'escala_screen.dart';

class MinhasEscalasScreen extends ConsumerStatefulWidget {
  const MinhasEscalasScreen({super.key});

  @override
  ConsumerState<MinhasEscalasScreen> createState() => _MinhasEscalasScreenState();
}

class _MinhasEscalasScreenState extends ConsumerState<MinhasEscalasScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final nomeMembro = ref.read(userRoleProvider.notifier).selectedMembroNome ?? '';
    final minhasEscalasAsync = ref.watch(compromissosDoMembroProvider(nomeMembro));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Escala $nomeMembro', style: AppTextStyles.heading(color: Colors.white).copyWith(fontSize: 20)),
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: AppColors.acento,
            labelColor: AppColors.acento,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Minha Escala'),
              Tab(text: 'Geral'),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF0F172A),
        body: TabBarView(
          children: [
            _buildAbaPessoal(minhasEscalasAsync, context),
            const EscalaScreen(hideAppBar: true),
          ],
        ),
      ),
    );
  }

  Widget _buildAbaPessoal(AsyncValue<List<EscalaItem>> minhasEscalasAsync, BuildContext context) {
    return minhasEscalasAsync.when(
      data: (escalas) {
        // Organizar escalas por dia para o calendário
        final Map<DateTime, List<EscalaItem>> escalasPorDia = {};
        
        for (var item in escalas) {
          final parts = item.data.split('-');
          if (parts.length == 3) {
            final date = DateTime.utc(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            
            if (escalasPorDia[date] == null) {
              escalasPorDia[date] = [];
            }
            escalasPorDia[date]!.add(item);
          }
        }

        final diaNormalizado = _selectedDay != null 
            ? DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
            : null;
            
        final escalasDoDia = diaNormalizado != null ? (escalasPorDia[diaNormalizado] ?? []) : <EscalaItem>[];

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.bgBorda.withValues(alpha: 0.5)),
              ),
              child: TableCalendar<EscalaItem>(
                firstDay: DateTime.utc(2023, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: (day) {
                  final d = DateTime.utc(day.year, day.month, day.day);
                  return escalasPorDia[d] ?? [];
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.acento.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.acento,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: const TextStyle(color: Colors.white),
                  weekendTextStyle: const TextStyle(color: Colors.white70),
                  outsideTextStyle: const TextStyle(color: Colors.white30),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: AppTextStyles.subheading(color: Colors.white),
                  leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
                  rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.white70),
                  weekendStyle: TextStyle(color: Colors.white70),
                ),
                locale: 'pt_BR',
              ),
            ),
            Expanded(
              child: escalasDoDia.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma escala para este dia.',
                        style: AppTextStyles.body(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: escalasDoDia.length,
                      itemBuilder: (context, index) {
                        final item = escalasDoDia[index];
                        return Card(
                          color: const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.acento.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(PhosphorIconsRegular.clock, color: AppColors.acento, size: 20),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.horario,
                                        style: const TextStyle(
                                          color: AppColors.acento,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.ministerio,
                                        style: AppTextStyles.subheading(color: Colors.white),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Função: ${item.funcao}',
                                        style: AppTextStyles.bodySmall(color: Colors.white70),
                                      ),
                                      if (item.tema.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tema: ${item.tema}',
                                          style: AppTextStyles.bodySmall(color: AppColors.acento),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
      error: (err, stack) => Center(child: Text('Erro ao carregar suas escalas: $err', style: AppTextStyles.body(color: Colors.red))),
    );
  }
}
