import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/models/escala_item.dart';
import '../../../core/models/agenda_item.dart';
import '../../../shared/widgets/app_widgets.dart';

class HomeCalendarWeb extends ConsumerStatefulWidget {
  const HomeCalendarWeb({super.key});

  @override
  ConsumerState<HomeCalendarWeb> createState() => _HomeCalendarWebState();
}

class _HomeCalendarWebState extends ConsumerState<HomeCalendarWeb> {
  DateTime _focusedDay = DateTime.now();

  List<EscalaItem> _getEscalasForDay(
    DateTime day,
    List<EscalaItem> todasEscalas,
  ) {
    return todasEscalas.where((e) {
      final eDate = DateTime.parse(e.data);
      return eDate.year == day.year &&
          eDate.month == day.month &&
          eDate.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final proximaAsync = ref.watch(proximaEscalaProvider);
    final agendaAsync = ref.watch(agendaProvider);
    final selectedDate = ref.watch(globalSelectedDateProvider);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: proximaAsync.when(
        data: (escalas) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    PhosphorIconsFill.calendarBlank,
                    color: context.corPrimaria,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Calendário',
                    style: AppTextStyles.subheading(
                      color: context.textoPrimario,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TableCalendar(
                locale: 'pt_BR',
                rowHeight: 44,
                daysOfWeekHeight: 28,
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  ref.read(globalSelectedDateProvider.notifier).state =
                      selectedDay;
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: (day) => _getEscalasForDay(day, escalas),
                calendarFormat: CalendarFormat.month,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: AppTextStyles.subheading(
                    color: context.textoPrimario,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: context.corPrimaria,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: context.corPrimaria,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: context.acentoSuave,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: AppTextStyles.bodySmall(
                    color: context.acentoTexto,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: context.corPrimaria,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: AppTextStyles.bodySmall(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  defaultTextStyle: AppTextStyles.bodySmall(
                    color: context.textoPrimario,
                  ),
                  weekendTextStyle: AppTextStyles.bodySmall(
                    color: context.textoSecund,
                  ),
                  outsideTextStyle: AppTextStyles.bodySmall(
                    color: context.textoMuted.withValues(alpha: 0.45),
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: AppTextStyles.label(color: context.textoSecund),
                  weekendStyle: AppTextStyles.label(color: context.textoSecund),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) => const SizedBox(),
                  defaultBuilder: (context, day, focusedDay) {
                    final temEscala =
                        _getEscalasForDay(day, escalas).isNotEmpty;
                    if (temEscala) {
                      return Container(
                        margin: const EdgeInsets.all(5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.acentoSuave,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${day.day}',
                          style: AppTextStyles.bodySmall(
                            color: context.acentoTexto,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }
                    return null;
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
                      const Divider(height: 28),
                      Text(
                        'Eventos do Dia',
                        style: AppTextStyles.label(color: context.textoSecund),
                      ),
                      const SizedBox(height: 10),
                      ...eventosDia.map((ag) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.alerta.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                PhosphorIconsBold.calendarStar,
                                color: AppColors.alerta,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ag.titulo,
                                      style: AppTextStyles.bodySmall(
                                        color: context.textoPrimario,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      ag.horario,
                                      style: AppTextStyles.monoSmall(
                                        color: context.textoSecund,
                                      ),
                                    ),
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
        loading: () => Center(
          child: CircularProgressIndicator(color: context.corPrimaria),
        ),
        error: (err, _) => Center(
          child: Text(
            'Erro ao carregar',
            style: AppTextStyles.body(color: AppColors.perigo),
          ),
        ),
      ),
    );
  }
}
