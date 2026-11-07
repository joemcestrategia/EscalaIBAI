import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/escala_item.dart';
import '../../shared/widgets/app_widgets.dart';
import 'escala_screen.dart';

class MinhasEscalasScreen extends ConsumerStatefulWidget {
  const MinhasEscalasScreen({super.key});

  @override
  ConsumerState<MinhasEscalasScreen> createState() =>
      _MinhasEscalasScreenState();
}

class _MinhasEscalasScreenState extends ConsumerState<MinhasEscalasScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final nomeMembro =
        ref.read(userRoleProvider.notifier).selectedMembroNome ?? '';
    final primeiroNome = nomeMembro.trim().isNotEmpty
        ? nomeMembro.trim().split(RegExp(r'\s+')).first
        : '';
    final minhasEscalasAsync =
        ref.watch(compromissosDoMembroProvider(nomeMembro));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.bgPrincipal,
        appBar: AppBar(
          title: Text(
            primeiroNome.isNotEmpty ? 'Escala de $primeiroNome' : 'Minha Escala',
            style: AppTextStyles.heading(color: context.textoPrimario),
          ),
          bottom: const AppSegmentedTabBar(
            tabs: [
              Tab(text: 'Meus Dias'),
              Tab(text: 'Escala Geral'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAbaPessoal(minhasEscalasAsync, context),
            const EscalaScreen(hideAppBar: true),
          ],
        ),
      ),
    );
  }

  Widget _buildAbaPessoal(
    AsyncValue<List<EscalaItem>> minhasEscalasAsync,
    BuildContext context,
  ) {
    return minhasEscalasAsync.when(
      data: (escalas) {
        final Map<DateTime, List<EscalaItem>> escalasPorDia = {};

        for (var item in escalas) {
          final parts = item.data.split('-');
          if (parts.length == 3) {
            final date = DateTime.utc(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            escalasPorDia.putIfAbsent(date, () => []).add(item);
          }
        }

        final diaNormalizado = _selectedDay != null
            ? DateTime.utc(
                _selectedDay!.year,
                _selectedDay!.month,
                _selectedDay!.day,
              )
            : null;

        final escalasDoDia = diaNormalizado != null
            ? (escalasPorDia[diaNormalizado] ?? [])
            : <EscalaItem>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppSurfaceCard(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
              child: TableCalendar<EscalaItem>(
                locale: 'pt_BR',
                rowHeight: 46,
                daysOfWeekHeight: 30,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Mês',
                  CalendarFormat.week: 'Semana',
                },
                calendarFormat: _calendarFormat,
                onFormatChanged: (fmt) => setState(() => _calendarFormat = fmt),
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
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return const SizedBox();
                    final isSel = isSameDay(day, _selectedDay);
                    return Positioned(
                      bottom: 6,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel ? Colors.white : context.corPrimaria,
                        ),
                      ),
                    );
                  },
                  defaultBuilder: (context, day, focusedDay) {
                    final d = DateTime.utc(day.year, day.month, day.day);
                    final tem = escalasPorDia[d]?.isNotEmpty ?? false;
                    if (!tem) return null;
                    return Container(
                      margin: const EdgeInsets.all(4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.acentoSuave,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${day.day}',
                        style: AppTextStyles.body(
                          color: context.acentoTexto,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  cellMargin: const EdgeInsets.all(4),
                  todayDecoration: BoxDecoration(
                    color: context.bgSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.corPrimaria, width: 1.5),
                  ),
                  todayTextStyle: AppTextStyles.body(
                    color: context.corPrimaria,
                    fontWeight: FontWeight.w800,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppColors.acento,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selectedTextStyle: AppTextStyles.body(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  defaultTextStyle: AppTextStyles.body(
                    color: context.textoPrimario,
                  ),
                  weekendTextStyle: AppTextStyles.body(
                    color: context.textoSecund,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  formatButtonShowsNext: false,
                  formatButtonDecoration: BoxDecoration(
                    color: context.acentoSuave,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  formatButtonPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  formatButtonTextStyle: AppTextStyles.label(
                    color: context.acentoTexto,
                  ),
                  titleCentered: false,
                  titleTextStyle: AppTextStyles.subheading(
                    color: context.textoPrimario,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: context.textoPrimario,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: context.textoPrimario,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: AppTextStyles.label(color: context.textoMuted),
                  weekendStyle: AppTextStyles.label(color: context.textoMuted),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (escalasDoDia.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      PhosphorIconsRegular.calendarCheck,
                      size: 40,
                      color: context.textoMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Você não está escalado neste dia.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(color: context.textoSecund),
                    ),
                  ],
                ),
              )
            else
              ...escalasDoDia.map((item) {
                return AppSurfaceCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: context.acentoSuave,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIconsBold.clock,
                              color: context.acentoTexto,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.horario.isNotEmpty ? item.horario : 'Dia',
                              style: AppTextStyles.monoSmall(
                                color: context.acentoTexto,
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
                              style: AppTextStyles.subheading(
                                color: context.textoPrimario,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Função: ${item.funcao}',
                              style: AppTextStyles.body(
                                color: context.textoSecund,
                              ),
                            ),
                            if (item.tema.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.tema,
                                style: AppTextStyles.bodySmall(
                                  color: context.corPrimaria,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
      loading: () => Center(
        child: CircularProgressIndicator(color: context.corPrimaria),
      ),
      error: (err, stack) => Center(
        child: Text(
          'Erro ao carregar suas escalas: $err',
          style: AppTextStyles.body(color: AppColors.perigo),
        ),
      ),
    );
  }
}
