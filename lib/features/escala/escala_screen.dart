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

    final tabBar = TabBar(
      indicatorColor: AppColors.acento,
      labelColor: AppColors.acento,
      unselectedLabelColor: context.textoSecund,
      tabs: const [
        Tab(text: 'Ministério'),
        Tab(text: 'Jejum'),
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
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
        error: (e, _) => Center(child: Text('Erro: $e', style: AppTextStyles.body())),
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
      error: (e, _) => Center(child: Text('Erro: $e', style: AppTextStyles.body())),
    );

    if (widget.hideAppBar) {
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Theme.of(context).appBarTheme.backgroundColor ?? const Color(0xFF0F172A),
              child: tabBar,
            ),
            Expanded(child: bodyContent),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Escala', style: AppTextStyles.heading()),
          actions: [
            IconButton(
              icon: const Icon(PhosphorIconsBold.magnifyingGlass, color: AppColors.acento),
              tooltip: 'Pesquisar Membro',
              onPressed: () => _pesquisarMembro(context),
            ),
            IconButton(
              icon: const Icon(PhosphorIconsBold.whatsappLogo, color: AppColors.acento),
              tooltip: 'Compartilhar no WhatsApp',
              onPressed: () => _compartilharEscalaWhatsApp(context, escalaAsync.value ?? []),
            ),
            Consumer(
              builder: (context, ref, child) {
                final role = ref.watch(userRoleProvider);
                if (role != UserRole.lider) return const SizedBox();
                return IconButton(
                  icon: const Icon(PhosphorIconsBold.robot, color: AppColors.acento),
                  tooltip: 'Gerar Escala Automática',
                  onPressed: () => _gerarEscala(context),
                );
              },
            ),
            Consumer(
              builder: (context, ref, child) {
                final role = ref.watch(userRoleProvider);
                if (role != UserRole.lider) return const SizedBox();
                return PopupMenuButton<String>(
                  icon: const Icon(PhosphorIconsBold.plus, color: AppColors.acento),
                  tooltip: 'Adicionar',
                  onSelected: (value) {
                    if (value == 'escala') {
                      _addEscala(context);
                    } else if (value == 'repertorio') {
                      _criarNovoRepertorio(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'escala',
                      child: Row(
                        children: [
                          Icon(PhosphorIconsBold.user, color: AppColors.acento, size: 18),
                          SizedBox(width: 8),
                          Text('Membro à Escala'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'repertorio',
                      child: Row(
                        children: [
                          Icon(PhosphorIconsBold.musicNotes, color: AppColors.acento, size: 18),
                          SizedBox(width: 8),
                          Text('Repertório'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          bottom: tabBar,
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

  Widget _buildAbaEscala(List<EscalaItem> lista, List<AgendaItem> agenda, bool isJejum) {
    final listaFiltrada = lista.where((item) {
      return isJejum ? item.ministerio == 'Jejum' : item.ministerio != 'Jejum';
    }).toList();

    final eventos = _mapearEventos(listaFiltrada);
    final _selecionado = ref.watch(globalSelectedDateProvider);
    final selKey = "${_selecionado.year}-${_selecionado.month}-${_selecionado.day}";
    final itensDia = eventos[selKey] ?? [];
    
    final agendaDia = agenda.where((item) {
      // Simplificado: verifica se o dia selecionado bate com a agenda
      final proximas = item.calcularProximasDatas(30);
      return proximas.any((p) => isSameDay(p, _selecionado));
    }).toList();
    
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final agendaParaExibir = agendaDia.where((ag) {
      if (ag.tipo == TipoAgenda.culto) return false;
      if (isDesktop) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      color: AppColors.acento,
      backgroundColor: Theme.of(context).colorScheme.surface,
      onRefresh: () async {
        ref.invalidate(escalaDoMesProvider);
        ref.invalidate(agendaProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            if (!isDesktop) _buildCalendario(eventos, agenda, _selecionado),
            if (!isDesktop) const SizedBox(height: 8),
            if (itensDia.isNotEmpty || agendaParaExibir.isNotEmpty) _buildDetalhes(itensDia, agendaParaExibir, _selecionado),
            if (itensDia.isEmpty && agendaParaExibir.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(PhosphorIconsBold.calendarBlank,
                        color: AppColors.textoMuted, size: 48),
                    const SizedBox(height: 12),
                    Text('Nenhuma escala neste dia.',
                        style:
                            AppTextStyles.body(color: context.textoSecund)),
                  ],
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendario(Map<String, List<EscalaItem>> eventos, List<AgendaItem> agenda, DateTime selecionado) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight),
      ),
      child: TableCalendar(
        locale: 'pt_BR',
        rowHeight: 36,
        daysOfWeekHeight: 24,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mês',
          CalendarFormat.week: 'Semana',
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
          markerBuilder: (context, day, events) => const SizedBox(), // Garante a remoção das bolinhas
          
          defaultBuilder: (context, day, focusedDay) {
            final key = "${day.year}-${day.month}-${day.day}";
            final temEscala = eventos.containsKey(key) && eventos[key]!.isNotEmpty;
            
            // Verifica agenda
            final diaAgenda = agenda.where((item) {
              final proximas = item.calcularProximasDatas(15);
              return proximas.any((p) => isSameDay(p, day));
            }).toList();

            if (diaAgenda.isNotEmpty || temEscala) {
              Color cor = AppColors.acento;
              if (diaAgenda.isNotEmpty) {
                final primary = diaAgenda.first;
                if (primary.tipo == TipoAgenda.evento || primary.tipo == TipoAgenda.reuniao) {
                  cor = AppColors.perigo;
                } else if (primary.tipo == TipoAgenda.culto) {
                  cor = AppColors.acento;
                }
              } else {
                cor = AppColors.acentoAzul; // Cor padrão para escala avulsa
              }

              return Container(
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: AppTextStyles.bodySmall(
                    color: cor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }
            return null;
          },

          outsideBuilder: (context, day, focusedDay) {
            final key = "${day.year}-${day.month}-${day.day}";
            final temEscala = eventos.containsKey(key) && eventos[key]!.isNotEmpty;
            
            final diaAgenda = agenda.where((item) {
              final proximas = item.calcularProximasDatas(15);
              return proximas.any((p) => isSameDay(p, day));
            }).toList();

            if (diaAgenda.isNotEmpty || temEscala) {
              Color cor = AppColors.acento;
              if (diaAgenda.isNotEmpty) {
                final primary = diaAgenda.first;
                if (primary.tipo == TipoAgenda.evento || primary.tipo == TipoAgenda.reuniao) {
                  cor = AppColors.perigo;
                } else if (primary.tipo == TipoAgenda.culto) {
                  cor = AppColors.acento;
                }
              } else {
                cor = AppColors.textoMuted;
              }

              return Container(
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: AppTextStyles.bodySmall(color: cor.withValues(alpha: 0.3)),
                ),
              );
            }
            return null;
          },
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: AppTextStyles.bodySmall(),
          weekendTextStyle: AppTextStyles.bodySmall(color: AppColors.acento),
          outsideTextStyle: AppTextStyles.bodySmall(color: AppColors.textoMuted),
          selectedDecoration: BoxDecoration(
            color: AppColors.acento.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.acento.withValues(alpha: 0.3)),
          ),
          selectedTextStyle:
              const TextStyle(color: AppColors.acento, fontWeight: FontWeight.bold, fontSize: 13),
          todayDecoration: const BoxDecoration(
            color: AppColors.acento,
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(2),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: AppTextStyles.bodySmall(color: context.textoSecund),
          weekendStyle: AppTextStyles.bodySmall(color: AppColors.acento),
        ),
        headerStyle: HeaderStyle(
          titleTextStyle: AppTextStyles.subheading(),
          formatButtonVisible: true,
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: AppColors.acento.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          formatButtonTextStyle: AppTextStyles.bodySmall(color: AppColors.acento),
          titleCentered: true,
          leftChevronIcon:
              const Icon(Icons.chevron_left, color: AppColors.acento),
          rightChevronIcon:
              const Icon(Icons.chevron_right, color: AppColors.acento),
        ),
      ),
    );
  }

  Widget _buildDetalhes(List<EscalaItem> itens, List<AgendaItem> agendaDia, DateTime selecionado) {
    final dataExibicao = itens.isNotEmpty ? DateTime.parse(itens.first.data) : selecionado;
    final dataFmt = DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(dataExibicao);

    // Agrupar por horário → ministério
    final porHorario = <String, List<EscalaItem>>{};
    for (final item in itens) {
      porHorario.putIfAbsent(item.horario, () => []).add(item);
    }
    final horarios = porHorario.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(dataFmt, style: AppTextStyles.subheading()),
          ),
          
          if (agendaDia.isNotEmpty) ...[
            ...agendaDia.map((ag) {
              final cor = ag.tipo == TipoAgenda.culto ? AppColors.acento : AppColors.perigo;
              final icone = ag.tipo == TipoAgenda.culto ? PhosphorIconsBold.church : PhosphorIconsBold.calendarStar;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(icone, color: cor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ag.titulo, style: AppTextStyles.body(fontWeight: FontWeight.bold)),
                          Text(ag.horario, style: AppTextStyles.bodySmall(color: context.textoSecund)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ag.tipo.name.toUpperCase(),
                        style: AppTextStyles.label(color: cor).copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (itens.isNotEmpty) const Divider(height: 32),
          ],
          ...horarios.map((hora) {
            final itensHora = porHorario[hora]!;
            final tema = itensHora.first.tema;
            final porMin = <String, List<EscalaItem>>{};
            for (final i in itensHora) {
              porMin.putIfAbsent(i.ministerio, () => []).add(i);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.acento.withValues(alpha: 0.1),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsBold.clock,
                            color: AppColors.acento, size: 16),
                        const SizedBox(width: 6),
                        Text(hora,
                            style: AppTextStyles.mono(color: AppColors.acento)),
                        if (tema.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '— $tema',
                              style: AppTextStyles.bodySmall(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        
                        // Botão Play (Playlist)
                        _PlaylistPlayButton(dataCulto: itens.first.data, horaCulto: hora),
                        
                        // Botão Adicionar Músicas (+)
                        PopupMenuButton<String>(
                          icon: const Icon(PhosphorIconsBold.plus, color: AppColors.acento, size: 18),
                          tooltip: 'Opções do Culto',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (value) async {
                            if (value == 'musica') {
                              _gerenciarSetlist(context, itens.first.data, hora);
                            } else if (value == 'membro') {
                              final dataObj = DateTime.tryParse(itens.first.data);
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
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'musica',
                              child: Row(
                                children: [
                                  Icon(PhosphorIconsBold.musicNotes, color: AppColors.acento, size: 18),
                                  SizedBox(width: 8),
                                  Text('Músicas do Culto'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'membro',
                              child: Row(
                                children: [
                                  Icon(PhosphorIconsBold.user, color: AppColors.acento, size: 18),
                                  SizedBox(width: 8),
                                  Text('Adicionar Membro'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ...porMin.entries.toList().asMap().entries.map((entry) {
                    final minIdx = entry.key;
                    final minNome = entry.value.key;
                    final minItens = entry.value.value;
                    final cor = AppColors
                        .minColors[minIdx % AppColors.minColors.length];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: cor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(minNome,
                                style: AppTextStyles.label(color: cor)),
                          ]),
                        ),
                        ...minItens.map((e) => _EscalaItemTile(
                              item: e,
                              cor: cor,
                              onRefresh: () =>
                                  ref.invalidate(escalaDoMesProvider),
                            )),
                      ],
                    );
                  }),
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
    final horaStr = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalSetlistRapido(dataCulto: dataStr, horaCulto: horaStr),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.acento,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final itensFiltrados = itens.where((item) {
      final dataItem = DateTime.parse(item.data);
      final d = DateTime(dataItem.year, dataItem.month, dataItem.day);
      final start = DateTime(picked.start.year, picked.start.month, picked.start.day);
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

  Future<void> _gerenciarSetlist(BuildContext context, String data, String hora) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalSetlistRapido(dataCulto: data, horaCulto: hora),
    );
    ref.invalidate(repertoriosProvider);
  }

  Future<void> _pesquisarMembro(BuildContext context) async {
    // Mostra um loading se necessário ou aguarda o future
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
        MaterialPageRoute(builder: (_) => _ModalCompromissos(nome: selecionado)),
      );
    }
  }
}

// ─── Item Tile ────────────────────────────────────────────────────────────────
class _EscalaItemTile extends ConsumerWidget {
  final EscalaItem item;
  final Color cor;
  final VoidCallback onRefresh;

  const _EscalaItemTile({
    required this.item,
    required this.cor,
    required this.onRefresh,
  });

  IconData _getIconeFuncao(String funcao, String ministerio) {
    final f = funcao.toLowerCase();
    final m = ministerio.toLowerCase();

    if (m.contains('jejum')) return PhosphorIconsBold.coffee;
    if (f.contains('guitarra') || f.contains('violão') || f.contains('violao') || f.contains('baixo')) return PhosphorIconsBold.guitar;
    if (f.contains('bateria')) return PhosphorIconsBold.musicNote;
    if (f.contains('teclado') || f.contains('piano')) return PhosphorIconsBold.keyboard;
    if (f.contains('voz') || f.contains('canto') || f.contains('back') || f.contains('ministro')) return PhosphorIconsBold.microphone;
    if (f.contains('pregador') || f.contains('pastor') || f.contains('palavra')) return PhosphorIconsBold.megaphone;
    if (f.contains('infantil') || f.contains('criança') || f.contains('tias') || f.contains('tio')) return PhosphorIconsBold.baby;
    if (f.contains('som') || f.contains('mesa') || f.contains('áudio') || f.contains('audio')) return PhosphorIconsBold.speakerHigh;
    if (f.contains('mídia') || f.contains('midia') || f.contains('projeção') || f.contains('letra')) return PhosphorIconsBold.desktop;
    
    return PhosphorIconsBold.user;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final falta = item.nome == '[FALTA]';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1.5),
      child: Container(
        decoration: BoxDecoration(
          color: falta
              ? AppColors.perigo.withValues(alpha: 0.08)
              : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: falta
                ? AppColors.perigo.withValues(alpha: 0.3)
                : (Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight),
          ),
        ),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(
            _getIconeFuncao(item.funcao, item.ministerio),
            color: falta ? AppColors.perigo : cor,
            size: 18,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.nome,
                  style: AppTextStyles.body(
                      color: falta ? AppColors.perigo : context.textoPrimario),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.funcao,
                style: AppTextStyles.bodySmall(color: context.textoSecund),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.statusConvite == 'PRESENTE')
                const Icon(PhosphorIconsBold.checkCircle,
                    color: AppColors.sucesso, size: 16)
              else if (item.statusConvite == 'ENVIADO')
                const Icon(PhosphorIconsBold.paperPlaneTilt,
                    color: AppColors.acento, size: 16)
              else if (item.statusConvite == 'FALTA')
                const Icon(PhosphorIconsBold.xCircle,
                    color: AppColors.perigo, size: 16)
              else
                const Icon(PhosphorIconsBold.clock,
                    color: AppColors.textoMuted, size: 16),
              const SizedBox(width: 4),
              Consumer(
                builder: (context, ref, child) {
                  final role = ref.watch(userRoleProvider);
                    if (role == UserRole.membro) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(PhosphorIconsBold.lock, color: AppColors.textoMuted, size: 16),
                      );
                    }
                  return PopupMenuButton<String>(
                    icon: Icon(PhosphorIconsBold.dotsThreeVertical,
                        color: context.textoSecund, size: 18),
                    color: Theme.of(context).colorScheme.surface,

                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                  const PopupMenuItem(
                      value: 'presenca', child: Text('Marcar Presença')),
                  const PopupMenuItem(
                      value: 'falta', child: Text('Registrar Falta')),
                  const PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir',
                          style: TextStyle(color: AppColors.perigo))),
                ],
                onSelected: (v) => _onMenu(context, ref, v),
              );
            },
          ),
        ],

          ),
        ),
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
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
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
          padding: const EdgeInsets.all(20),
          child: Text(
            query.isEmpty ? 'Nenhum membro cadastrado.' : 'Nenhum membro encontrado para "$query".',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: context.textoSecund),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: itens.length,
      itemBuilder: (context, index) {
        final nome = itens[index];
        return ListTile(
          title: Text(nome, style: AppTextStyles.body()),
          onTap: () => close(context, nome),
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

  @override
  void initState() {
    super.initState();
    // Tenta focar no mês atual
    _focado = DateTime.now();
    _selecionado = DateTime.now();
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

  @override
  Widget build(BuildContext context) {
    final compromissosAsync = ref.watch(compromissosDoMembroProvider(widget.nome));
    final escalaCompletaAsync = ref.watch(escalaDoMesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Agenda de ${widget.nome}', style: AppTextStyles.heading(color: context.textoPrimario)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textoPrimario),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          compromissosAsync.when(
            data: (meusCompromissos) => IconButton(
              icon: const Icon(PhosphorIconsBold.whatsappLogo, color: AppColors.sucesso),
              tooltip: 'Exportar Agenda via WhatsApp',
              onPressed: meusCompromissos.isEmpty ? null : () async {
                try {
                  await WhatsappService.compartilharEscala(
                    itens: meusCompromissos,
                    mes: _focado.month,
                    ano: _focado.year,
                  );
                } catch (e) {
                  if (context.mounted) AppSnackbar.show(context, e.toString(), erro: true);
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
          final selKey = "${_selecionado.year}-${_selecionado.month}-${_selecionado.day}";
          final meusItensDia = eventosMembro[selKey] ?? [];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


                // Calendário
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                        ? context.bgBorda 
                        : AppColors.bgBordaLight,
                    ),
                  ),
                  child: TableCalendar(
                    locale: 'pt_BR',
                    rowHeight: 32,
                    daysOfWeekHeight: 20,
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
                      titleTextStyle: AppTextStyles.body(fontWeight: FontWeight.bold),
                      formatButtonVisible: false,
                      titleCentered: true,
                      leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.acento, size: 16),
                      rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.acento, size: 16),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isNotEmpty) {
                          return Positioned(
                            bottom: 4,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.acento,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                      defaultBuilder: (context, day, focusedDay) {
                        final key = "${day.year}-${day.month}-${day.day}";
                        if (eventosMembro.containsKey(key) && eventosMembro[key]!.isNotEmpty) {
                          return Container(
                            margin: const EdgeInsets.all(4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.acento.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.acento),
                            ),
                            child: Text(
                              '${day.day}',
                              style: AppTextStyles.bodySmall(color: context.textoPrimario),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: AppTextStyles.bodySmall(),
                      weekendTextStyle: AppTextStyles.bodySmall(color: AppColors.acento),
                      outsideTextStyle: AppTextStyles.bodySmall(color: AppColors.textoMuted),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.acento,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                      todayDecoration: BoxDecoration(
                        color: AppColors.acento.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: const TextStyle(color: AppColors.acento, fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Conteúdo com Scroll
                Expanded(
                  child: ListView(
                    children: [
                      // Seus Compromissos no Dia
                      Text('Seus Compromissos no Dia', style: AppTextStyles.label(color: AppColors.acento)),
                      const SizedBox(height: 8),
                      if (meusItensDia.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('Nenhum compromisso seu neste dia.', style: AppTextStyles.bodySmall(color: context.textoSecund)),
                        )
                      else
                        ...meusItensDia.map((item) {
                          final isJejum = item.ministerio == 'Jejum';
                          final jaSalvo = _itensSalvos.contains(item.id);
                          return Card(
                            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: jaSalvo ? AppColors.sucesso : context.bgBorda,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(isJejum ? 'Jejum Diário' : item.ministerio, style: AppTextStyles.body().copyWith(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                isJejum ? 'Dia de Jejum' : 'Função: ${item.funcao}\nHorário: ${item.horario}',
                                style: AppTextStyles.bodySmall(),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  jaSalvo ? PhosphorIconsBold.checkCircle : PhosphorIconsBold.calendarPlus,
                                  color: jaSalvo ? AppColors.sucesso : AppColors.acento,
                                  size: 20,
                                ),
                                tooltip: 'Salvar na Agenda do Celular',
                                onPressed: () {
                                  _salvarNaAgenda(item);
                                  setState(() {
                                    _itensSalvos.add(item.id);
                                  });
                                },
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 16),
                      Divider(color: context.bgBorda),
                      const SizedBox(height: 8),

                      // Escala Completa do Dia
                      Text('Escala Completa do Dia', style: AppTextStyles.label()),
                      const SizedBox(height: 8),
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
                            return Text('Nenhuma escala cadastrada para este dia.', 
                                style: AppTextStyles.bodySmall(color: context.textoSecund));
                          }

                          // Agrupar por horário
                          final porHora = <String, List<EscalaItem>>{};
                          for (final e in diaFiltrado) {
                            porHora.putIfAbsent(e.horario, () => []).add(e);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: porHora.entries.map((entry) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('⏰ ${entry.key}', style: AppTextStyles.body(color: AppColors.acento, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    ...entry.value.map((e) {
                                      final souEu = e.nome == widget.nome;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          children: [
                                            Text(e.nome == '[FALTA]' ? '❌ ' : '• ', style: const TextStyle(fontSize: 10)),
                                            Expanded(
                                              child: Text(
                                                e.nome == '[FALTA]' ? 'VAGA ABERTA' : e.nome,
                                                style: AppTextStyles.bodySmall(
                                                  color: souEu ? AppColors.acento : context.textoPrimario,
                                                ).copyWith(
                                                  fontWeight: souEu ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              e.funcao,
                                              style: AppTextStyles.bodySmall(color: context.textoSecund),
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
                        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
                        error: (_, __) => const Text('Erro ao carregar escala completa.'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
        error: (_, __) => Text('Erro ao buscar compromissos.', style: AppTextStyles.body()),
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

    final titulo = Uri.encodeComponent(
        item.ministerio == 'Jejum' ? 'Jejum IBAI' : 'Escala IBAI - ${item.ministerio}');
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

// ─── Botão de Playlist do YouTube ────────────────────────────────────────────
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
          orElse: () => Repertorio(id: '', dataCulto: dataCulto, horaCulto: horaCulto, listaMusicas: [], createdAt: DateTime.now()),
        );

        if (rep.listaMusicas.isEmpty) return const SizedBox();

        return IconButton(
          icon: const Icon(PhosphorIconsBold.play, color: AppColors.acento, size: 18),
          tooltip: 'Tocar Playlist',
          padding: const EdgeInsets.only(right: 8),
          constraints: const BoxConstraints(),
          onPressed: () async {
            final ids = rep.listaMusicas
                .map((m) => _extrairVideoId(m['link'] ?? ''))
                .where((id) => id != null)
                .cast<String>()
                .toList();

            if (ids.isEmpty) {
              AppSnackbar.show(context, 'Nenhum link do YouTube válido encontrado.');
              return;
            }

            final playlistUrl = 'https://www.youtube.com/watch_videos?video_ids=${ids.join(',')}';
            final uri = Uri.parse(playlistUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (context.mounted) AppSnackbar.show(context, 'Não foi possível abrir o YouTube.');
            }
          },
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}


