import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/models/escala_item.dart';
import '../../../core/models/agenda_item.dart';

class HomeCalendarWeb extends ConsumerStatefulWidget {
  const HomeCalendarWeb({super.key});

  @override
  ConsumerState<HomeCalendarWeb> createState() => _HomeCalendarWebState();
}

class _HomeCalendarWebState extends ConsumerState<HomeCalendarWeb> {
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  List<EscalaItem> _getEscalasForDay(DateTime day, List<EscalaItem> todasEscalas) {
    return todasEscalas.where((e) {
      final eDate = DateTime.parse(e.data);
      return eDate.year == day.year && eDate.month == day.month && eDate.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final proximaAsync = ref.watch(proximaEscalaProvider);
    final agendaAsync = ref.watch(agendaProvider);
    final selectedDate = ref.watch(globalSelectedDateProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? context.bgBorda
              : AppColors.bgBordaLight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: proximaAsync.when(
        data: (escalas) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIconsBold.calendar, color: AppColors.acento, size: 20),
                  const SizedBox(width: 8),
                  Text('Calendário', style: AppTextStyles.heading(color: AppColors.acento).copyWith(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 16),
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  ref.read(globalSelectedDateProvider.notifier).state = selectedDay;
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: (day) => _getEscalasForDay(day, escalas),
                calendarFormat: CalendarFormat.month,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: AppTextStyles.body(color: context.textoPrimario).copyWith(fontWeight: FontWeight.bold),
                  leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.acento),
                  rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.acento),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.acento.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.acento,
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: AppTextStyles.bodySmall(color: context.textoPrimario),
                  weekendTextStyle: AppTextStyles.bodySmall(color: context.textoSecund),
                  outsideTextStyle: AppTextStyles.bodySmall(color: context.textoSecund.withValues(alpha: 0.5)),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: AppTextStyles.monoSmall(color: context.textoSecund),
                  weekendStyle: AppTextStyles.monoSmall(color: context.textoSecund),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) => const SizedBox(), // Remove as bolinhas
                  defaultBuilder: (context, day, focusedDay) {
                    final temEscala = _getEscalasForDay(day, escalas).isNotEmpty;
                    if (temEscala) {
                      return Container(
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: AppTextStyles.bodySmall(color: AppColors.acento, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    return null;
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return Container(
                      margin: const EdgeInsets.all(6.0),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.acento, // Dia atual com círculo amarelo preenchido
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: AppTextStyles.bodySmall(
                          color: Colors.black, // Texto preto para contrastar com amarelo
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                availableGestures: AvailableGestures.none,
              ),
              agendaAsync.when(
                data: (agenda) {
                  final eventosDia = agenda.where((item) {
                    if (item.tipo == TipoAgenda.culto) return false;
                    final proximas = item.calcularProximasDatas(30);
                    return proximas.any((p) => isSameDay(p, selectedDate));
                  }).toList();

                  if (eventosDia.isEmpty) return const SizedBox();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 32),
                      Text('Eventos do Dia', style: AppTextStyles.label(color: context.textoSecund)),
                      const SizedBox(height: 8),
                      ...eventosDia.map((ag) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.perigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.perigo.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(PhosphorIconsBold.calendarStar, color: AppColors.perigo, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ag.titulo, style: AppTextStyles.bodySmall(color: context.textoPrimario).copyWith(fontWeight: FontWeight.bold)),
                                    Text(ag.horario, style: AppTextStyles.monoSmall(color: context.textoSecund)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
        error: (err, _) => Center(child: Text('Erro ao carregar', style: AppTextStyles.body(color: AppColors.perigo))),
      ),
    );
  }
}
