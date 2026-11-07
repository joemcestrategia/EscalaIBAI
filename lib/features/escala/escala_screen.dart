import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/escala_item.dart';
import '../../core/models/repertorio.dart';
import '../../core/models/agenda_item.dart';
import '../../core/services/whatsapp_service.dart';
import '../../shared/widgets/app_widgets.dart';
import 'modais/modal_add_escala.dart';
import 'modais/modal_gerar_escala.dart';
import 'modais/modal_edit_escala.dart';
import 'modais/modal_setlist_rapido.dart';

class EscalaScreen extends ConsumerStatefulWidget {
  final bool hideAppBar;
  const EscalaScreen({super.key, this.hideAppBar = false});

  @override
  ConsumerState<EscalaScreen> createState() => _EscalaScreenState();
}

class _EscalaScreenState extends ConsumerState<EscalaScreen> {
  DateTime _focado = DateTime.now();
  CalendarFormat _formatoCalendario = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    final escalaAsync = ref.watch(escalaDoMesProvider);
    final agendaAsync = ref.watch(agendaProvider);

    const segmentedTabs = AppSegmentedTabBar(
      tabs: [
        Tab(text: 'Ministérios'),
        Tab(text: 'Escala de Jejum'),
      ],
    );

    final bodyContent = agendaAsync.when(
      data: (agenda) => escalaAsync.when(
        data: (lista) => TabBarView(
          children: [
            _buildAbaEscala(lista, agenda, false),
            _buildAbaEscala(lista, agenda, true),
          ],
        ),
        loading: () => Center(
          child: CircularProgressIndicator(color: context.corPrimaria),
        ),
        error: (e, _) => Center(
          child: Text('Erro: $e', style: AppTextStyles.body()),
        ),
      ),
      loading: () => Center(
        child: CircularProgressIndicator(color: context.corPrimaria),
      ),
      error: (e, _) => Center(
        child: Text('Erro: $e', style: AppTextStyles.body()),
      ),
    );

    if (widget.hideAppBar) {
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: context.bgPrincipal,
              padding: const EdgeInsets.only(top: 6),
              child: segmentedTabs,
            ),
            Expanded(child: bodyContent),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.bgPrincipal,
        appBar: AppBar(
          title: Text(
            'Escala',
            style: AppTextStyles.heading(color: context.textoPrimario),
          ),
          actions: [
            IconButton(
              icon: Icon(
                PhosphorIconsBold.magnifyingGlass,
                color: context.textoPrimario,
              ),
              tooltip: 'Pesquisar Membro',
              onPressed: () => _pesquisarMembro(context),
            ),
            IconButton(
              icon: const Icon(
                PhosphorIconsBold.whatsappLogo,
                color: AppColors.sucesso,
              ),
              tooltip: 'Compartilhar no WhatsApp',
              onPressed: () =>
                  _compartilharEscalaWhatsApp(context, escalaAsync.value ?? []),
            ),
            Consumer(
              builder: (context, ref, child) {
                final role = ref.watch(userRoleProvider);
                if (role != UserRole.lider) return const SizedBox();
                return IconButton(
                  icon: Icon(
                    PhosphorIconsBold.magicWand,
                    color: context.textoPrimario,
                  ),
                  tooltip: 'Gerar Escala Automática',
                  onPressed: () => _gerarEscala(context),
                );
              },
            ),
            Consumer(
              builder: (context, ref, child) {
                final role = ref.watch(userRoleProvider);
                if (role != UserRole.lider) return const SizedBox(width: 8);
                return Padding(
                  padding: const EdgeInsets.only(right: 12, left: 4),
                  child: PopupMenuButton<String>(
                    tooltip: 'Adicionar',
                    onSelected: (value) {
                      if (value == 'escala') {
                        _addEscala(context);
                      } else if (value == 'repertorio') {
                        _criarNovoRepertorio(context);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'escala',
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIconsBold.userPlus,
                              color: context.corPrimaria,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text('Membro à Escala'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'repertorio',
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIconsBold.musicNotesPlus,
                              color: context.corPrimaria,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text('Repertório do Culto'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.acento,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            PhosphorIconsBold.plus,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Novo',
                            style: AppTextStyles.label(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: segmentedTabs,
        ),
        body: bodyContent,
      ),
    );
  }

  Map<String, List<EscalaItem>> _mapearEventos(List<EscalaItem> lista) {
    final map = <String, List<EscalaItem>>{};
    for (final item in lista) {
      final d = DateTime.parse(item.data);
      final key = "${d.year}-${d.month}-${d.day}";
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  Widget _buildAbaEscala(
    List<EscalaItem> lista,
    List<AgendaItem> agenda,
    bool isJejum,
  ) {
    final listaFiltrada = lista.where((item) {
      return isJejum ? item.ministerio == 'Jejum' : item.ministerio != 'Jejum';
    }).toList();

    final eventos = _mapearEventos(listaFiltrada);
    final selecionado = ref.watch(globalSelectedDateProvider);
    final selKey =
        "${selecionado.year}-${selecionado.month}-${selecionado.day}";
    final itensDia = eventos[selKey] ?? [];

    final agendaDia = agenda.where((item) {
      final proximas = item.calcularProximasDatas(30);
      return proximas.any((p) => isSameDay(p, selecionado));
    }).toList();

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final agendaParaExibir = agendaDia.where((ag) {
      if (ag.tipo == TipoAgenda.culto) return false;
      if (isDesktop) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      color: context.corPrimaria,
      backgroundColor: context.bgCard,
      onRefresh: () async {
        ref.invalidate(escalaDoMesProvider);
        ref.invalidate(agendaProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            if (!isDesktop) _buildCalendario(eventos, agenda, selecionado),
            if (!isDesktop) const SizedBox(height: 8),
            if (itensDia.isNotEmpty || agendaParaExibir.isNotEmpty)
              _buildDetalhes(itensDia, agendaParaExibir, selecionado),
            if (itensDia.isEmpty && agendaParaExibir.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 48,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: context.bgSubtle,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        PhosphorIconsRegular.calendarBlank,
                        color: context.textoMuted,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma escala neste dia',
                      style: AppTextStyles.subheading(
                        color: context.textoPrimario,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Selecione outra data acima para visualizar os escalados.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall(
                        color: context.textoSecund,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendario(
    Map<String, List<EscalaItem>> eventos,
    List<AgendaItem> agenda,
    DateTime selecionado,
  ) {
    return AppSurfaceCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      child: TableCalendar(
        locale: 'pt_BR',
        rowHeight: 48,
        daysOfWeekHeight: 30,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Visão Mensal',
          CalendarFormat.week: 'Visão Semanal',
        },
        firstDay: DateTime(2024, 1, 1),
        lastDay: DateTime(2030, 12, 31),
        focusedDay: _focado,
        selectedDayPredicate: (d) => isSameDay(d, selecionado),
        eventLoader: (d) {
          final key = "${d.year}-${d.month}-${d.day}";
          return eventos[key] ?? [];
        },
        onDaySelected: (sel, foc) {
          ref.read(globalSelectedDateProvider.notifier).state = sel;
          setState(() {
            _focado = foc;
          });
        },
        calendarFormat: _formatoCalendario,
        onFormatChanged: (format) {
          setState(() {
            _formatoCalendario = format;
          });
        },
        onPageChanged: (foc) {
          _focado = foc;
          ref.read(escalaAnoProvider.notifier).state = foc.year;
          ref.read(escalaMesProvider.notifier).state = foc.month;
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return const SizedBox();
            final isSel = isSameDay(day, selecionado);
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
            final key = "${day.year}-${day.month}-${day.day}";
            final temEscala =
                eventos.containsKey(key) && eventos[key]!.isNotEmpty;

            final diaAgenda = agenda.where((item) {
              final proximas = item.calcularProximasDatas(15);
              return proximas.any((p) => isSameDay(p, day));
            }).toList();

            if (diaAgenda.isNotEmpty || temEscala) {
              Color cor = context.corPrimaria;
              if (diaAgenda.isNotEmpty) {
                final primary = diaAgenda.first;
                if (primary.tipo == TipoAgenda.evento ||
                    primary.tipo == TipoAgenda.reuniao) {
                  cor = AppColors.alerta;
                }
              }

              return Container(
                margin: const EdgeInsets.all(4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: context.isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${day.day}',
                  style: AppTextStyles.body(
                    color: cor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }
            return null;
          },
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: AppTextStyles.body(color: context.textoPrimario),
          weekendTextStyle: AppTextStyles.body(color: context.textoSecund),
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(4),
          selectedDecoration: BoxDecoration(
            color: AppColors.acento,
            borderRadius: BorderRadius.circular(12),
          ),
          selectedTextStyle: AppTextStyles.body(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          todayDecoration: BoxDecoration(
            color: context.bgSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.corPrimaria, width: 1.5),
          ),
          todayTextStyle: AppTextStyles.body(
            color: context.corPrimaria,
            fontWeight: FontWeight.w800,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: AppTextStyles.label(color: context.textoMuted),
          weekendStyle: AppTextStyles.label(color: context.textoMuted),
        ),
        headerStyle: HeaderStyle(
          titleTextStyle: AppTextStyles.subheading(
            color: context.textoPrimario,
          ),
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
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: context.textoPrimario,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: context.textoPrimario,
          ),
        ),
      ),
    );
  }

  Widget _buildDetalhes(
    List<EscalaItem> itens,
    List<AgendaItem> agendaDia,
    DateTime selecionado,
  ) {
    final dataExibicao =
        itens.isNotEmpty ? DateTime.parse(itens.first.data) : selecionado;
    final dataFmt =
        DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(dataExibicao);
    final dataCap =
        dataFmt.isNotEmpty ? dataFmt[0].toUpperCase() + dataFmt.substring(1) : '';

    final porHorario = <String, List<EscalaItem>>{};
    for (final item in itens) {
      porHorario.putIfAbsent(item.horario, () => []).add(item);
    }
    final horarios = porHorario.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
            child: Text(
              dataCap,
              style: AppTextStyles.subheading(color: context.textoPrimario),
            ),
          ),
          if (agendaDia.isNotEmpty) ...[
            ...agendaDia.map((ag) {
              final cor = ag.tipo == TipoAgenda.culto
                  ? context.corPrimaria
                  : AppColors.alerta;
              final icone = ag.tipo == TipoAgenda.culto
                  ? PhosphorIconsBold.church
                  : PhosphorIconsBold.calendarStar;

              return AppSurfaceCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icone, color: cor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ag.titulo,
                            style: AppTextStyles.body(
                              color: context.textoPrimario,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            ag.horario,
                            style: AppTextStyles.bodySmall(
                              color: context.textoSecund,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        ag.tipo.name.toUpperCase(),
                        style: AppTextStyles.label(color: cor)
                            .copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          ...horarios.map((hora) {
            final itensHora = porHorario[hora]!;
            final tema = itensHora.first.tema;
            final porMin = <String, List<EscalaItem>>{};
            for (final i in itensHora) {
              porMin.putIfAbsent(i.ministerio, () => []).add(i);
            }

            return AppSurfaceCard(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho limpo do Culto / Horário
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: context.acentoSuave,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsBold.clock,
                                color: context.acentoTexto,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hora.isNotEmpty ? hora : 'Dia todo',
                                style: AppTextStyles.mono(
                                  color: context.acentoTexto,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tema.isNotEmpty ? tema : 'Programação',
                            style: AppTextStyles.subheading(
                              color: context.textoPrimario,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _PlaylistPlayButton(
                          dataCulto: itens.first.data,
                          horaCulto: hora,
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            PhosphorIconsBold.dotsThreeVertical,
                            color: context.textoSecund,
                            size: 20,
                          ),
                          tooltip: 'Opções do Culto',
                          onSelected: (value) async {
                            if (value == 'musica') {
                              _gerenciarSetlist(context, itens.first.data, hora);
                            } else if (value == 'membro') {
                              final dataObj =
                                  DateTime.tryParse(itens.first.data);
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => ModalAddEscala(
                                  initialData: dataObj,
                                  initialHorario: hora,
                                  initialTema: tema,
                                ),
                              );
                              ref.invalidate(escalaDoMesProvider);
                            }
                          },
                          itemBuilder: (context) {
                            final role = ref.read(userRoleProvider);
                            return [
                              PopupMenuItem(
                                value: 'musica',
                                child: Row(
                                  children: [
                                    Icon(
                                      PhosphorIconsBold.musicNotes,
                                      color: context.corPrimaria,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Músicas do Culto'),
                                  ],
                                ),
                              ),
                              if (role == UserRole.lider)
                                PopupMenuItem(
                                  value: 'membro',
                                  child: Row(
                                    children: [
                                      Icon(
                                        PhosphorIconsBold.userPlus,
                                        color: context.corPrimaria,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      const Text('Adicionar Membro'),
                                    ],
                                  ),
                                ),
                            ];
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: context.bgBorda),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children:
                          porMin.entries.toList().asMap().entries.map((entry) {
                        final minIdx = entry.key;
                        final minNome = entry.value.key;
                        final minItens = entry.value.value;
                        final cor = AppColors
                            .minColors[minIdx % AppColors.minColors.length];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 14, 18, 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: cor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    minNome.toUpperCase(),
                                    style: AppTextStyles.label(color: cor),
                                  ),
                                ],
                              ),
                            ),
                            ...minItens.map(
                              (e) => _EscalaItemTile(
                                item: e,
                                cor: cor,
                                onRefresh: () =>
                                    ref.invalidate(escalaDoMesProvider),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _addEscala(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ModalAddEscala(),
    );
    if (ok == true && mounted) {
      ref.invalidate(escalaDoMesProvider);
    }
  }

  Future<void> _criarNovoRepertorio(BuildContext context) async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      locale: const Locale('pt', 'BR'),
    );

    if (data == null) return;
    if (!context.mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );

    if (hora == null) return;
    if (!context.mounted) return;

    final dataStr = DateFormat('yyyy-MM-dd').format(data);
    final horaStr =
        '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ModalSetlistRapido(dataCulto: dataStr, horaCulto: horaStr),
    );

    ref.invalidate(repertoriosProvider);
  }

  Future<void> _gerarEscala(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ModalGerarEscala(),
    );
    if (ok == true && mounted) {
      ref.invalidate(escalaDoMesProvider);
      ref.invalidate(kpiMesProvider);
    }
  }

  Future<void> _compartilharEscalaWhatsApp(
      BuildContext context, List<EscalaItem> itens) async {
    if (itens.isEmpty) {
      AppSnackbar.show(context, 'Nenhuma escala no mês para compartilhar.');
      return;
    }

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: firstDay, end: lastDay),
      helpText: 'Selecione o período da escala',
      cancelText: 'Cancelar',
      confirmText: 'Compartilhar',
      saveText: 'Compartilhar',
    );

    if (picked == null) return;

    final itensFiltrados = itens.where((item) {
      final dataItem = DateTime.parse(item.data);
      final d = DateTime(dataItem.year, dataItem.month, dataItem.day);
      final start =
          DateTime(picked.start.year, picked.start.month, picked.start.day);
      final end = DateTime(picked.end.year, picked.end.month, picked.end.day);
      return (d.isAtSameMomentAs(start) || d.isAfter(start)) &&
          (d.isAtSameMomentAs(end) || d.isBefore(end));
    }).toList();

    if (itensFiltrados.isEmpty) {
      if (context.mounted) {
        AppSnackbar.show(context, 'Nenhuma escala encontrada nesse período.');
      }
      return;
    }

    final mes = ref.read(escalaMesProvider);
    final ano = ref.read(escalaAnoProvider);

    try {
      if (context.mounted) {
        AppSnackbar.show(context, 'Abrindo WhatsApp...');
      }
      await WhatsappService.compartilharEscala(
        itens: itensFiltrados,
        mes: mes,
        ano: ano,
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(context, e.toString(), erro: true);
      }
    }
  }

  Future<void> _gerenciarSetlist(
      BuildContext context, String data, String hora) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalSetlistRapido(dataCulto: data, horaCulto: hora),
    );
    ref.invalidate(repertoriosProvider);
  }

  Future<void> _pesquisarMembro(BuildContext context) async {
    final listaMembros = await ref.read(membrosProvider.future);
    if (!context.mounted) return;

    final nomes = listaMembros.map((e) => e.nome).toSet().toList()..sort();
    final selecionado = await showSearch<String?>(
      context: context,
      delegate: MembroSearchDelegate(nomes),
    );

    if (selecionado != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ModalCompromissos(nome: selecionado),
        ),
      );
    }
  }
}

// ─── Item Tile Limpo (Avatares + Sem Poluição de Caixas) ──────────────────────
class _EscalaItemTile extends ConsumerWidget {
  final EscalaItem item;
  final Color cor;
  final VoidCallback onRefresh;

  const _EscalaItemTile({
    required this.item,
    required this.cor,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final falta = item.nome == '[FALTA]' || item.statusConvite == 'FALTA';
    final role = ref.watch(userRoleProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          AppAvatar(
            name: item.nome == '[FALTA]' ? '!' : item.nome,
            size: 42,
            accentColor: falta ? AppColors.perigo : cor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nome == '[FALTA]' ? 'Vaga em aberto' : item.nome,
                  style: AppTextStyles.body(
                    color: falta ? AppColors.perigo : context.textoPrimario,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.funcao.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    item.funcao,
                    style: AppTextStyles.bodySmall(
                      color: context.textoSecund,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (item.statusConvite == 'PRESENTE')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.sucesso.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Confirmado',
                style: AppTextStyles.label(color: AppColors.sucesso)
                    .copyWith(fontSize: 12),
              ),
            )
          else if (item.statusConvite == 'FALTA')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.perigo.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Falta',
                style: AppTextStyles.label(color: AppColors.perigo)
                    .copyWith(fontSize: 12),
              ),
            )
          else if (item.statusConvite == 'ENVIADO')
            Icon(
              PhosphorIconsBold.paperPlaneTilt,
              color: context.corPrimaria,
              size: 18,
            ),
          if (role == UserRole.lider)
            PopupMenuButton<String>(
              icon: Icon(
                PhosphorIconsBold.dotsThreeVertical,
                color: context.textoSecund,
                size: 20,
              ),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(
                  value: 'presenca',
                  child: Text('Marcar Presença'),
                ),
                PopupMenuItem(
                  value: 'falta',
                  child: Text('Registrar Falta'),
                ),
                PopupMenuItem(
                  value: 'excluir',
                  child: Text(
                    'Excluir',
                    style: TextStyle(color: AppColors.perigo),
                  ),
                ),
              ],
              onSelected: (v) => _onMenu(context, ref, v),
            ),
        ],
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String v) async {
    final repo = ref.read(escalaRepoProvider);
    switch (v) {
      case 'editar':
        if (context.mounted) {
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => ModalEditEscala(item: item),
          );
          if (ok == true) onRefresh();
        }
        break;
      case 'presenca':
        await repo.atualizar(item.id, {'status_convite': 'PRESENTE'});
        onRefresh();
        break;
      case 'falta':
        if (context.mounted) {
          final ok = await ConfirmDialog.show(
            context,
            titulo: 'Registrar Falta',
            mensagem: 'Registrar falta para ${item.nome}?',
            labelConfirmar: 'Confirmar',
            perigo: true,
          );
          if (ok) {
            await repo.atualizar(item.id, {'status_convite': 'FALTA'});
            await ref
                .read(ausenciasRepoProvider)
                .inserir(nome: item.nome, motivo: 'Falta no culto');
            if (context.mounted) AppSnackbar.show(context, 'Falta registrada!');
            onRefresh();
          }
        }
        break;
      case 'excluir':
        if (context.mounted) {
          final ok = await ConfirmDialog.show(
            context,
            titulo: 'Excluir',
            mensagem: 'Remover ${item.nome} da escala?',
            labelConfirmar: 'Excluir',
            perigo: true,
          );
          if (ok) {
            await repo.excluir(item.id);
            onRefresh();
          }
        }
        break;
    }
  }
}

class MembroSearchDelegate extends SearchDelegate<String?> {
  final List<String> nomes;
  MembroSearchDelegate(this.nomes);

  @override
  String get searchFieldLabel => 'Buscar nome do membro...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final sugestoes = nomes
        .where((n) => n.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return _buildLista(context, sugestoes);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final sugestoes = nomes
        .where((n) => n.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return _buildLista(context, sugestoes);
  }

  Widget _buildLista(BuildContext context, List<String> itens) {
    if (itens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            query.isEmpty
                ? 'Nenhum membro cadastrado.'
                : 'Nenhum membro encontrado para "$query".',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: context.textoSecund),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final nome = itens[index];
        return AppSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onTap: () => close(context, nome),
          child: Row(
            children: [
              AppAvatar(name: nome, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  nome,
                  style: AppTextStyles.body(
                    color: context.textoPrimario,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                PhosphorIconsBold.caretRight,
                color: context.textoMuted,
                size: 18,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModalCompromissos extends ConsumerStatefulWidget {
  final String nome;
  const _ModalCompromissos({required this.nome});

  @override
  ConsumerState<_ModalCompromissos> createState() => _ModalCompromissosState();
}

class _ModalCompromissosState extends ConsumerState<_ModalCompromissos> {
  final Set<String> _itensSalvos = {};
  DateTime _focado = DateTime.now();
  DateTime _selecionado = DateTime.now();

  Map<String, List<EscalaItem>> _mapearEventos(List<EscalaItem> lista) {
    final map = <String, List<EscalaItem>>{};
    for (final item in lista) {
      final d = DateTime.parse(item.data);
      final key = "${d.year}-${d.month}-${d.day}";
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final compromissosAsync =
        ref.watch(compromissosDoMembroProvider(widget.nome));
    final escalaCompletaAsync = ref.watch(escalaDoMesProvider);

    return Scaffold(
      backgroundColor: context.bgPrincipal,
      appBar: AppBar(
        title: Text(
          'Agenda de ${widget.nome}',
          style: AppTextStyles.heading(color: context.textoPrimario),
        ),
        actions: [
          compromissosAsync.when(
            data: (meusCompromissos) => IconButton(
              icon: const Icon(
                PhosphorIconsBold.whatsappLogo,
                color: AppColors.sucesso,
              ),
              tooltip: 'Exportar Agenda via WhatsApp',
              onPressed: meusCompromissos.isEmpty
                  ? null
                  : () async {
                      try {
                        await WhatsappService.compartilharEscala(
                          itens: meusCompromissos,
                          mes: _focado.month,
                          ano: _focado.year,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackbar.show(context, e.toString(), erro: true);
                        }
                      }
                    },
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: compromissosAsync.when(
        data: (meusCompromissos) {
          final eventosMembro = _mapearEventos(meusCompromissos);
          final selKey =
              "${_selecionado.year}-${_selecionado.month}-${_selecionado.day}";
          final meusItensDia = eventosMembro[selKey] ?? [];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSurfaceCard(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                  child: TableCalendar(
                    locale: 'pt_BR',
                    rowHeight: 42,
                    daysOfWeekHeight: 26,
                    firstDay: DateTime(2024, 1, 1),
                    lastDay: DateTime(2030, 12, 31),
                    focusedDay: _focado,
                    selectedDayPredicate: (d) => isSameDay(d, _selecionado),
                    eventLoader: (d) {
                      final key = "${d.year}-${d.month}-${d.day}";
                      return eventosMembro[key] ?? [];
                    },
                    onDaySelected: (sel, foc) {
                      setState(() {
                        _selecionado = sel;
                        _focado = foc;
                      });
                    },
                    onPageChanged: (foc) {
                      setState(() {
                        _focado = foc;
                      });
                    },
                    calendarFormat: CalendarFormat.month,
                    headerStyle: HeaderStyle(
                      titleTextStyle: AppTextStyles.subheading(
                        color: context.textoPrimario,
                      ),
                      formatButtonVisible: false,
                      titleCentered: true,
                      leftChevronIcon: Icon(
                        Icons.chevron_left_rounded,
                        color: context.corPrimaria,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right_rounded,
                        color: context.corPrimaria,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) => const SizedBox(),
                      defaultBuilder: (context, day, focusedDay) {
                        final key = "${day.year}-${day.month}-${day.day}";
                        if (eventosMembro.containsKey(key) &&
                            eventosMembro[key]!.isNotEmpty) {
                          return Container(
                            margin: const EdgeInsets.all(4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.acentoSuave,
                              borderRadius: BorderRadius.circular(10),
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
                    calendarStyle: CalendarStyle(
                      defaultTextStyle:
                          AppTextStyles.bodySmall(color: context.textoPrimario),
                      weekendTextStyle:
                          AppTextStyles.bodySmall(color: context.textoSecund),
                      outsideDaysVisible: false,
                      selectedDecoration: BoxDecoration(
                        color: AppColors.acento,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      selectedTextStyle: AppTextStyles.bodySmall(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      todayDecoration: BoxDecoration(
                        color: context.bgSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.corPrimaria),
                      ),
                      todayTextStyle: AppTextStyles.bodySmall(
                        color: context.corPrimaria,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        'COMPROMISSOS NO DIA',
                        style: AppTextStyles.label(color: context.corPrimaria),
                      ),
                      const SizedBox(height: 10),
                      if (meusItensDia.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Nenhum compromisso para ${widget.nome} neste dia.',
                            style: AppTextStyles.body(
                              color: context.textoSecund,
                            ),
                          ),
                        )
                      else
                        ...meusItensDia.map((item) {
                          final isJejum = item.ministerio == 'Jejum';
                          final jaSalvo = _itensSalvos.contains(item.id);
                          return AppSurfaceCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isJejum
                                            ? 'Jejum Diário'
                                            : item.ministerio,
                                        style: AppTextStyles.subheading(
                                          color: context.textoPrimario,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isJejum
                                            ? 'Dia de Jejum'
                                            : '${item.funcao} • ${item.horario}',
                                        style: AppTextStyles.bodySmall(
                                          color: context.textoSecund,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    jaSalvo
                                        ? PhosphorIconsBold.checkCircle
                                        : PhosphorIconsBold.calendarPlus,
                                    color: jaSalvo
                                        ? AppColors.sucesso
                                        : context.corPrimaria,
                                    size: 22,
                                  ),
                                  tooltip: 'Salvar na Agenda do Celular',
                                  onPressed: () {
                                    _salvarNaAgenda(item);
                                    setState(() {
                                      _itensSalvos.add(item.id);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      Text(
                        'ESCALA COMPLETA DO DIA',
                        style: AppTextStyles.label(color: context.textoSecund),
                      ),
                      const SizedBox(height: 10),
                      escalaCompletaAsync.when(
                        data: (todasEscalas) {
                          final diaFiltrado = todasEscalas.where((e) {
                            final d = DateTime.tryParse(e.data);
                            return d != null &&
                                d.year == _selecionado.year &&
                                d.month == _selecionado.month &&
                                d.day == _selecionado.day;
                          }).toList();

                          if (diaFiltrado.isEmpty) {
                            return Text(
                              'Nenhuma escala cadastrada para este dia.',
                              style: AppTextStyles.body(
                                color: context.textoSecund,
                              ),
                            );
                          }

                          final porHora = <String, List<EscalaItem>>{};
                          for (final e in diaFiltrado) {
                            porHora.putIfAbsent(e.horario, () => []).add(e);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: porHora.entries.map((entry) {
                              return AppSurfaceCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key.isNotEmpty
                                          ? 'Horário: ${entry.key}'
                                          : 'Dia Todo',
                                      style: AppTextStyles.subheading(
                                        color: context.corPrimaria,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ...entry.value.map((e) {
                                      final souEu = e.nome == widget.nome;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                        ),
                                        child: Row(
                                          children: [
                                            AppAvatar(
                                              name: e.nome,
                                              size: 34,
                                              accentColor: souEu
                                                  ? AppColors.acento
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                e.nome == '[FALTA]'
                                                    ? 'Vaga em aberto'
                                                    : e.nome,
                                                style: AppTextStyles.body(
                                                  color: souEu
                                                      ? context.corPrimaria
                                                      : context.textoPrimario,
                                                  fontWeight: souEu
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              e.funcao,
                                              style: AppTextStyles.bodySmall(
                                                color: context.textoSecund,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => Center(
                          child: CircularProgressIndicator(
                            color: context.corPrimaria,
                          ),
                        ),
                        error: (_, __) =>
                            const Text('Erro ao carregar escala completa.'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: context.corPrimaria),
        ),
        error: (_, __) =>
            Text('Erro ao buscar compromissos.', style: AppTextStyles.body()),
      ),
    );
  }

  Future<void> _salvarNaAgenda(EscalaItem item) async {
    final d = DateTime.parse(item.data);
    String inicioStr;
    String fimStr;

    if (item.ministerio == 'Jejum') {
      inicioStr =
          '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      fimStr = inicioStr;
    } else {
      final hParts = item.horario.split(':');
      final h = hParts.isNotEmpty ? int.parse(hParts[0]) : 18;
      final m = hParts.length > 1 ? int.parse(hParts[1]) : 0;

      final dtInicio = DateTime(d.year, d.month, d.day, h, m);
      final dtFim = dtInicio.add(const Duration(hours: 2));

      inicioStr =
          '${dtInicio.year}${dtInicio.month.toString().padLeft(2, '0')}${dtInicio.day.toString().padLeft(2, '0')}T${dtInicio.hour.toString().padLeft(2, '0')}${dtInicio.minute.toString().padLeft(2, '0')}00';
      fimStr =
          '${dtFim.year}${dtFim.month.toString().padLeft(2, '0')}${dtFim.day.toString().padLeft(2, '0')}T${dtFim.hour.toString().padLeft(2, '0')}${dtFim.minute.toString().padLeft(2, '0')}00';
    }

    final titulo = Uri.encodeComponent(item.ministerio == 'Jejum'
        ? 'Jejum IBAI'
        : 'Escala IBAI - ${item.ministerio}');
    final detalhes = Uri.encodeComponent(item.ministerio == 'Jejum'
        ? 'Seu dia de Jejum IBAI.'
        : 'Ministério: ${item.ministerio}\nFunção: ${item.funcao}');

    final url =
        'https://www.google.com/calendar/render?action=TEMPLATE&text=$titulo&dates=$inicioStr/$fimStr&details=$detalhes';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(() {
        _itensSalvos.add(item.id);
      });
    }
  }
}

// ─── Botão Pílula de Playlist do YouTube ─────────────────────────────────────
class _PlaylistPlayButton extends ConsumerWidget {
  final String dataCulto;
  final String horaCulto;

  const _PlaylistPlayButton({required this.dataCulto, required this.horaCulto});

  String? _extrairVideoId(String url) {
    if (url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.first;
      }
      if (uri.host.contains('youtube.com')) {
        if (uri.pathSegments.contains('shorts')) {
          return uri.pathSegments.last;
        }
        return uri.queryParameters['v'];
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repertoriosAsync = ref.watch(repertoriosProvider);

    return repertoriosAsync.when(
      data: (lista) {
        final rep = lista.firstWhere(
          (r) => r.dataCulto == dataCulto && r.horaCulto == horaCulto,
          orElse: () => Repertorio(
            id: '',
            dataCulto: dataCulto,
            horaCulto: horaCulto,
            listaMusicas: [],
            createdAt: DateTime.now(),
          ),
        );

        if (rep.listaMusicas.isEmpty) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final ids = rep.listaMusicas
                  .map((m) => _extrairVideoId(m['link'] ?? ''))
                  .where((id) => id != null)
                  .cast<String>()
                  .toList();

              if (ids.isEmpty) {
                AppSnackbar.show(
                  context,
                  'Nenhum link do YouTube válido encontrado.',
                );
                return;
              }

              final playlistUrl =
                  'https://www.youtube.com/watch_videos?video_ids=${ids.join(',')}';
              final uri = Uri.parse(playlistUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  AppSnackbar.show(
                    context,
                    'Não foi possível abrir o YouTube.',
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.acentoSuave,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsFill.play,
                    color: context.acentoTexto,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Setlist',
                    style: AppTextStyles.label(color: context.acentoTexto)
                        .copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}
