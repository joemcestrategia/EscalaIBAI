import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/models/regra.dart';
import '../../core/models/agenda_item.dart';
import '../../core/models/funcao.dart';
import '../../core/models/compatibilidade.dart';
import '../../core/models/ministerio.dart';
import '../../core/services/update_service.dart';
import '../../core/services/notification_service.dart';
import '../splash/quem_sou_eu_screen.dart';
import '../../shared/widgets/app_widgets.dart';

class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    final isMembro = role == UserRole.membro;

    return Scaffold(
      backgroundColor: context.bgPrincipal,
      appBar: AppBar(
        title: Text('Ajustes', style: AppTextStyles.heading()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          // Cartão de Perfil e Notificações no topo
          const _MeuPerfilNotificacoesConfig(),
          const SizedBox(height: 20),

          // Seletor rápido de Tema (Claro Editorial / Escuro Palco / Sistema)
          const _RotuloCategoria('APARÊNCIA E EXIBIÇÃO'),
          const SizedBox(height: 8),
          const _TemaConfig(),
          const SizedBox(height: 10),
          const _SecaoExpansivel(
            titulo: 'Tela Inicial (Home)',
            subtitulo: 'Escolha quais cartões exibir no início',
            icone: PhosphorIconsRegular.house,
            child: _HomeConfig(),
          ),

          if (!isMembro) ...[
            const SizedBox(height: 24),
            const _RotuloCategoria('GESTÃO DA IGREJA'),
            const SizedBox(height: 8),
            const _SecaoExpansivel(
              titulo: 'Cultos Regulares',
              subtitulo: 'Dias e horários oficiais de culto',
              icone: PhosphorIconsRegular.church,
              child: _CultosConfig(),
            ),
            const SizedBox(height: 10),
            const _SecaoExpansivel(
              titulo: 'Eventos e Reuniões',
              subtitulo: 'Ensaios, reuniões e programações especiais',
              icone: PhosphorIconsRegular.calendarStar,
              child: _AgendaConfig(),
            ),
            const SizedBox(height: 10),
            const _SecaoExpansivel(
              titulo: 'Ministérios',
              subtitulo: 'Equipes e ícones de identificação',
              icone: PhosphorIconsRegular.usersThree,
              child: _MinisteriosConfig(),
            ),
            const SizedBox(height: 10),
            const _SecaoExpansivel(
              titulo: 'Funções por Ministério',
              subtitulo: 'Cargos e instrumentos disponíveis',
              icone: PhosphorIconsRegular.tag,
              child: _FuncoesConfig(),
            ),
            const SizedBox(height: 10),
            const _SecaoExpansivel(
              titulo: 'Regras de Escala',
              subtitulo: 'Quantidade necessária por função em cada culto',
              icone: PhosphorIconsRegular.listChecks,
              child: _RegrasConfig(),
            ),
            const SizedBox(height: 10),
            const _SecaoExpansivel(
              titulo: 'Acúmulos de Função',
              subtitulo: 'Permissões para exercer duas funções juntas',
              icone: PhosphorIconsRegular.intersect,
              child: _AcumulosConfig(),
            ),
            const SizedBox(height: 10),
            const _SecaoExpansivel(
              titulo: 'Escala de Jejum',
              subtitulo: 'Quantidade diária de integrantes no rodízio',
              icone: PhosphorIconsRegular.drop,
              child: _JejumConfig(),
            ),
          ],

          const SizedBox(height: 24),
          const _RotuloCategoria('SISTEMA E CONTA'),
          const SizedBox(height: 8),
          AppSurfaceCard(
            padding: const EdgeInsets.all(6),
            borderRadius: 18,
            child: Column(
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.acentoSuave,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      PhosphorIconsBold.arrowsClockwise,
                      color: context.corPrimaria,
                      size: 19,
                    ),
                  ),
                  title: Text(
                    'Verificar Atualizações',
                    style: AppTextStyles.body(
                      color: context.textoPrimario,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Buscar nova versão disponível do aplicativo',
                    style: AppTextStyles.bodySmall(color: context.textoSecund),
                  ),
                  trailing: Icon(
                    PhosphorIconsBold.caretRight,
                    size: 16,
                    color: context.textoMuted,
                  ),
                  onTap: () async {
                    final scaffold = ScaffoldMessenger.of(context);
                    AppSnackbar.show(context, 'Verificando atualizações...');
                    final update = await UpdateService.checkForUpdate();
                    if (context.mounted) {
                      scaffold.hideCurrentSnackBar();
                      if (update != null) {
                        UpdateService.checkForUpdateAndPrompt(context);
                      } else {
                        AppSnackbar.show(
                          context,
                          'O aplicativo já está na versão mais recente!',
                        );
                      }
                    }
                  },
                ),
                Divider(color: context.bgBorda, height: 8, indent: 56),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.perigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      PhosphorIconsBold.signOut,
                      color: AppColors.perigo,
                      size: 19,
                    ),
                  ),
                  title: Text(
                    'Alterar Perfil / Sair',
                    style: AppTextStyles.body(
                      color: AppColors.perigo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Trocar entre acesso de Membro ou Liderança',
                    style: AppTextStyles.bodySmall(color: context.textoSecund),
                  ),
                  onTap: () async {
                    final confirm = await ConfirmDialog.show(
                      context,
                      titulo: 'Alterar Perfil',
                      mensagem:
                          'Deseja sair deste perfil e voltar para a tela de escolha de acesso?',
                      labelConfirmar: 'Sair',
                      perigo: true,
                    );

                    if (confirm) {
                      await NotificationService.cancelarTodas();
                      await ref.read(userRoleProvider.notifier).logout();
                      ref.invalidate(userRoleProvider);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RotuloCategoria extends StatelessWidget {
  final String texto;
  const _RotuloCategoria(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        texto,
        style: AppTextStyles.label(
          color: context.textoMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SecaoExpansivel extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData icone;
  final Widget child;

  const _SecaoExpansivel({
    required this.titulo,
    this.subtitulo,
    required this.icone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      borderRadius: 18,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.acentoSuave,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icone, color: context.corPrimaria, size: 20),
          ),
          title: Text(
            titulo,
            style: AppTextStyles.subheading(
              color: context.textoPrimario,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: subtitulo != null
              ? Text(
                  subtitulo!,
                  style: AppTextStyles.bodySmall(color: context.textoSecund),
                )
              : null,
          iconColor: context.corPrimaria,
          collapsedIconColor: context.textoMuted,
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            Divider(color: context.bgBorda, height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Meu Perfil ───────────────────────────────────────────────────────────────
class _MeuPerfilNotificacoesConfig extends ConsumerStatefulWidget {
  const _MeuPerfilNotificacoesConfig();

  @override
  ConsumerState<_MeuPerfilNotificacoesConfig> createState() =>
      _MeuPerfilNotificacoesConfigState();
}

class _MeuPerfilNotificacoesConfigState
    extends ConsumerState<_MeuPerfilNotificacoesConfig> {
  bool _verHorariosAvisos = false;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final roleNotifier = ref.watch(userRoleProvider.notifier);
    final nomeMembro = roleNotifier.selectedMembroNome ?? 'Não selecionado';
    final perfilStr = role == UserRole.lider ? 'Liderança' : 'Integrante';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: nomeMembro, size: 54, circular: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.acentoSuave,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        perfilStr,
                        style: AppTextStyles.label(
                          color: context.acentoTexto,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nomeMembro,
                      style: AppTextStyles.heading(
                        color: context.textoPrimario,
                      ).copyWith(fontSize: 19),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Trocar Meu Nome na Escala',
            outlined: true,
            icon: PhosphorIconsBold.userSwitch,
            width: double.infinity,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuemSouEuScreen(
                    role: role,
                    isReconfiguration: true,
                    onMemberSelected: () {
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                setState(() => _verHorariosAvisos = !_verHorariosAvisos),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.bellRinging,
                    size: 18,
                    color: context.corPrimaria,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Como funcionam meus lembretes automáticos',
                      style: AppTextStyles.bodySmall(
                        color: context.textoSecund,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _verHorariosAvisos
                        ? PhosphorIconsBold.caretUp
                        : PhosphorIconsBold.caretDown,
                    size: 15,
                    color: context.textoMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_verHorariosAvisos) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.bgSubtle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '• Culto à Tarde/Noite: aviso às 08:00 do dia e 1h antes\n'
                '• Culto pela Manhã: aviso na véspera às 20:00 e 1h antes\n'
                '• Ministros de Louvor: aviso 2 dias antes às 20:00 para montar o repertório\n'
                '• Escala de Jejum: aviso às 20:00 da véspera e 06:00 do dia\n'
                '• Novo Repertório de Culto: aviso enviado para a equipe',
                style: AppTextStyles.bodySmall(color: context.textoSecund),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Tema Config ──────────────────────────────────────────────────────────────
class _TemaConfig extends ConsumerWidget {
  const _TemaConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.sunDim,
                color: context.corPrimaria,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Iluminação do Aplicativo',
                style: AppTextStyles.subheading(
                  color: context.textoPrimario,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Use Claro Editorial no dia a dia ou Escuro Suave no palco.',
            style: AppTextStyles.bodySmall(color: context.textoSecund),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TemaCard(
                  label: 'Claro (Dia)',
                  icone: PhosphorIconsBold.sun,
                  selecionado: themeMode == ThemeMode.light,
                  onTap: () => notifier.setThemeMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TemaCard(
                  label: 'Escuro (Palco)',
                  icone: PhosphorIconsBold.moon,
                  selecionado: themeMode == ThemeMode.dark,
                  onTap: () => notifier.setThemeMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TemaCard(
                  label: 'Sistema',
                  icone: PhosphorIconsBold.deviceMobile,
                  selecionado: themeMode == ThemeMode.system,
                  onTap: () => notifier.setThemeMode(ThemeMode.system),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemaCard extends StatelessWidget {
  final String label;
  final IconData icone;
  final bool selecionado;
  final VoidCallback onTap;

  const _TemaCard({
    required this.label,
    required this.icone,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionado ? AppColors.acento : context.bgSubtle,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selecionado ? AppColors.acento : context.bgBorda,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icone,
                color: selecionado ? Colors.white : context.textoSecund,
                size: 22,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label(
                  color: selecionado ? Colors.white : context.textoPrimario,
                  fontWeight: selecionado ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Agenda Config ────────────────────────────────────────────────────────────
class _AgendaConfig extends ConsumerWidget {
  const _AgendaConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agendaAsync = ref.watch(agendaProvider);
    return agendaAsync.when(
      data: (lista) {
        final eventosEReunioes =
            lista.where((item) => item.tipo != TipoAgenda.culto).toList();

        return Column(
          children: [
            if (eventosEReunioes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Nenhum evento ou reunião cadastrado.',
                  style: AppTextStyles.bodySmall(color: context.textoSecund),
                ),
              )
            else
              ...eventosEReunioes.map((item) {
                String recorrencia = '';
                if (item.recorrenciaTipo == TipoRecorrencia.semanal) {
                  final dias = [
                    'Dom',
                    'Seg',
                    'Ter',
                    'Qua',
                    'Qui',
                    'Sex',
                    'Sáb',
                  ];
                  recorrencia = 'Toda ${dias[item.diaSemana!]}';
                } else if (item.recorrenciaTipo ==
                    TipoRecorrencia.mensalPosicao) {
                  final dias = [
                    'Domingo',
                    'Segunda',
                    'Terça',
                    'Quarta',
                    'Quinta',
                    'Sexta',
                    'Sábado',
                  ];
                  final posicoes = {
                    1: '1º',
                    2: '2º',
                    3: '3º',
                    4: '4º',
                    -1: 'Último',
                  };
                  recorrencia =
                      '${posicoes[item.recorrenciaValor]} ${dias[item.diaSemana!]} do mês';
                } else {
                  recorrencia =
                      DateFormat('dd/MM/yyyy').format(item.dataEspecifica!);
                }

                IconData icone = PhosphorIconsRegular.calendarStar;
                if (item.tipo == TipoAgenda.reuniao) {
                  icone = PhosphorIconsRegular.usersThree;
                }

                return _ItemConfig(
                  titulo: item.titulo,
                  subtitulo: '$recorrencia às ${item.horario}',
                  icone: icone,
                  onEdit: () => _showAgendaDialog(context, ref, item: item),
                  onDelete: () async {
                    final ok = await ConfirmDialog.show(
                      context,
                      titulo: 'Excluir Item',
                      mensagem: 'Excluir "${item.titulo}" da agenda?',
                      labelConfirmar: 'Excluir',
                      perigo: true,
                    );
                    if (ok) {
                      await ref.read(agendaRepoProvider).excluir(item.id);
                      ref.invalidate(agendaProvider);
                      ref.invalidate(proximasAtividadesProvider);
                    }
                  },
                );
              }),
            const SizedBox(height: 10),
            AppButton(
              label: 'Adicionar Evento / Reunião',
              outlined: true,
              icon: PhosphorIconsBold.plus,
              onPressed: () => _showAgendaDialog(context, ref),
              width: double.infinity,
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.acento),
      ),
      error: (e, _) => Text('Erro: $e', style: AppTextStyles.body()),
    );
  }

  Future<void> _showAgendaDialog(
    BuildContext context,
    WidgetRef ref, {
    AgendaItem? item,
  }) async {
    final isEdit = item != null;
    TipoAgenda tipo = item?.tipo ?? TipoAgenda.evento;
    TipoRecorrencia recTipo = item?.recorrenciaTipo ?? TipoRecorrencia.semanal;
    int? diaSemana = item?.diaSemana ?? 0;
    int? recValor = item?.recorrenciaValor ?? 1;
    DateTime? dataUnica = item?.dataEspecifica ?? DateTime.now();
    final tituloCtrl = TextEditingController(text: item?.titulo);

    final hParts = (item?.horario ?? '19:30').split(':');
    TimeOfDay hora = TimeOfDay(
      hour: int.parse(hParts[0]),
      minute: int.parse(hParts[1]),
    );

    final dias = [
      'Domingo',
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
    ];
    final posicoes = {1: '1º', 2: '2º', 3: '3º', 4: '4º', -1: 'Último'};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: context.bgCard,
          title: Text(
            isEdit ? 'Editar Agenda' : 'Novo na Agenda',
            style: AppTextStyles.heading(),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(label: 'Título / Tema', controller: tituloCtrl),
                const SizedBox(height: 12),
                DropdownButtonFormField<TipoAgenda>(
                  initialValue: tipo,
                  style: AppTextStyles.body(color: context.textoPrimario),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  dropdownColor: context.bgCard,
                  items: [TipoAgenda.evento, TipoAgenda.reuniao]
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            t == TipoAgenda.evento ? 'Evento' : 'Reunião',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => ss(() => tipo = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TipoRecorrencia>(
                  initialValue: recTipo,
                  style: AppTextStyles.body(color: context.textoPrimario),
                  decoration: const InputDecoration(labelText: 'Recorrência'),
                  dropdownColor: context.bgCard,
                  items: TipoRecorrencia.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            t == TipoRecorrencia.semanal
                                ? 'Semanal'
                                : t == TipoRecorrencia.mensalPosicao
                                    ? 'Mensal (Posição)'
                                    : 'Data Única',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => ss(() => recTipo = v!),
                ),
                if (recTipo == TipoRecorrencia.unico) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(PhosphorIconsRegular.calendar, size: 18),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: dataUnica!,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 2)),
                        );
                        if (d != null) ss(() => dataUnica = d);
                      },
                      label: Text(DateFormat('dd/MM/yyyy').format(dataUnica!)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: diaSemana,
                    style: AppTextStyles.body(color: context.textoPrimario),
                    decoration:
                        const InputDecoration(labelText: 'Dia da Semana'),
                    dropdownColor: context.bgCard,
                    items: List.generate(
                      7,
                      (i) => DropdownMenuItem(value: i, child: Text(dias[i])),
                    ),
                    onChanged: (v) => ss(() => diaSemana = v!),
                  ),
                  if (recTipo == TipoRecorrencia.mensalPosicao) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: recValor,
                      style: AppTextStyles.body(color: context.textoPrimario),
                      decoration:
                          const InputDecoration(labelText: 'Posição no Mês'),
                      dropdownColor: context.bgCard,
                      items: posicoes.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => ss(() => recValor = v!),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(PhosphorIconsRegular.clock, size: 18),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: hora,
                      );
                      if (t != null) ss(() => hora = t);
                    },
                    label: Text('Horário: ${hora.format(context)}'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tituloCtrl.text.isEmpty) return;
                final novoItem = AgendaItem(
                  id: item?.id ?? '',
                  tipo: tipo,
                  titulo: tituloCtrl.text.trim(),
                  dataEspecifica:
                      recTipo == TipoRecorrencia.unico ? dataUnica : null,
                  horario:
                      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
                  diaSemana:
                      recTipo != TipoRecorrencia.unico ? diaSemana : null,
                  recorrenciaTipo: recTipo,
                  recorrenciaValor: recTipo == TipoRecorrencia.mensalPosicao
                      ? recValor
                      : null,
                );

                if (isEdit) {
                  await ref
                      .read(agendaRepoProvider)
                      .atualizar(item.id, novoItem.toMap());
                } else {
                  await ref.read(agendaRepoProvider).inserir(novoItem);
                }
                ref.invalidate(agendaProvider);
                ref.invalidate(proximasAtividadesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cultos Config ────────────────────────────────────────────────────────────
class _CultosConfig extends ConsumerWidget {
  const _CultosConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agendaAsync = ref.watch(agendaProvider);
    return agendaAsync.when(
      data: (lista) {
        final cultos =
            lista.where((item) => item.tipo == TipoAgenda.culto).toList();

        return Column(
          children: [
            if (cultos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Nenhum culto cadastrado.',
                  style: AppTextStyles.bodySmall(color: context.textoSecund),
                ),
              )
            else
              ...cultos.map((item) {
                String recorrencia = '';
                if (item.recorrenciaTipo == TipoRecorrencia.semanal) {
                  final dias = [
                    'Dom',
                    'Seg',
                    'Ter',
                    'Qua',
                    'Qui',
                    'Sex',
                    'Sáb',
                  ];
                  recorrencia = 'Toda ${dias[item.diaSemana!]}';
                } else if (item.recorrenciaTipo ==
                    TipoRecorrencia.mensalPosicao) {
                  final dias = [
                    'Domingo',
                    'Segunda',
                    'Terça',
                    'Quarta',
                    'Quinta',
                    'Sexta',
                    'Sábado',
                  ];
                  final posicoes = {
                    1: '1º',
                    2: '2º',
                    3: '3º',
                    4: '4º',
                    -1: 'Último',
                  };
                  recorrencia =
                      '${posicoes[item.recorrenciaValor]} ${dias[item.diaSemana!]} do mês';
                } else {
                  recorrencia =
                      DateFormat('dd/MM/yyyy').format(item.dataEspecifica!);
                }

                return _ItemConfig(
                  titulo: item.titulo,
                  subtitulo: '$recorrencia às ${item.horario}',
                  icone: PhosphorIconsRegular.church,
                  onEdit: () => _showCultoDialog(context, ref, item: item),
                  onDelete: () async {
                    final ok = await ConfirmDialog.show(
                      context,
                      titulo: 'Excluir Culto',
                      mensagem: 'Excluir "${item.titulo}"?',
                      labelConfirmar: 'Excluir',
                      perigo: true,
                    );
                    if (ok) {
                      await ref.read(agendaRepoProvider).excluir(item.id);
                      ref.invalidate(agendaProvider);
                      ref.invalidate(proximasAtividadesProvider);
                    }
                  },
                );
              }),
            const SizedBox(height: 10),
            AppButton(
              label: 'Adicionar Culto',
              outlined: true,
              icon: PhosphorIconsBold.plus,
              onPressed: () => _showCultoDialog(context, ref),
              width: double.infinity,
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.acento),
      ),
      error: (e, _) => Text('Erro: $e', style: AppTextStyles.body()),
    );
  }

  Future<void> _showCultoDialog(
    BuildContext context,
    WidgetRef ref, {
    AgendaItem? item,
  }) async {
    final isEdit = item != null;
    TipoRecorrencia recTipo = item?.recorrenciaTipo ?? TipoRecorrencia.semanal;
    int? diaSemana = item?.diaSemana ?? 0;
    int? recValor = item?.recorrenciaValor ?? 1;
    DateTime? dataUnica = item?.dataEspecifica ?? DateTime.now();
    final tituloCtrl = TextEditingController(text: item?.titulo);

    final hParts = (item?.horario ?? '19:30').split(':');
    TimeOfDay hora = TimeOfDay(
      hour: int.parse(hParts[0]),
      minute: int.parse(hParts[1]),
    );

    final dias = [
      'Domingo',
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
    ];
    final posicoes = {1: '1º', 2: '2º', 3: '3º', 4: '4º', -1: 'Último'};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: context.bgCard,
          title: Text(
            isEdit ? 'Editar Culto' : 'Novo Culto',
            style: AppTextStyles.heading(),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(label: 'Título / Tema', controller: tituloCtrl),
                const SizedBox(height: 12),
                DropdownButtonFormField<TipoRecorrencia>(
                  initialValue: recTipo,
                  style: AppTextStyles.body(color: context.textoPrimario),
                  decoration: const InputDecoration(labelText: 'Recorrência'),
                  dropdownColor: context.bgCard,
                  items: TipoRecorrencia.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            t == TipoRecorrencia.semanal
                                ? 'Semanal'
                                : t == TipoRecorrencia.mensalPosicao
                                    ? 'Mensal (Posição)'
                                    : 'Data Única',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => ss(() => recTipo = v!),
                ),
                if (recTipo == TipoRecorrencia.unico) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(PhosphorIconsRegular.calendar, size: 18),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: dataUnica!,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 2)),
                        );
                        if (d != null) ss(() => dataUnica = d);
                      },
                      label: Text(DateFormat('dd/MM/yyyy').format(dataUnica!)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: diaSemana,
                    style: AppTextStyles.body(color: context.textoPrimario),
                    decoration:
                        const InputDecoration(labelText: 'Dia da Semana'),
                    dropdownColor: context.bgCard,
                    items: List.generate(
                      7,
                      (i) => DropdownMenuItem(value: i, child: Text(dias[i])),
                    ),
                    onChanged: (v) => ss(() => diaSemana = v!),
                  ),
                  if (recTipo == TipoRecorrencia.mensalPosicao) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: recValor,
                      style: AppTextStyles.body(color: context.textoPrimario),
                      decoration:
                          const InputDecoration(labelText: 'Posição no Mês'),
                      dropdownColor: context.bgCard,
                      items: posicoes.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => ss(() => recValor = v!),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(PhosphorIconsRegular.clock, size: 18),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: hora,
                      );
                      if (t != null) ss(() => hora = t);
                    },
                    label: Text('Horário: ${hora.format(context)}'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tituloCtrl.text.isEmpty) return;
                final novoItem = AgendaItem(
                  id: item?.id ?? '',
                  tipo: TipoAgenda.culto,
                  titulo: tituloCtrl.text.trim(),
                  dataEspecifica:
                      recTipo == TipoRecorrencia.unico ? dataUnica : null,
                  horario:
                      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
                  diaSemana:
                      recTipo != TipoRecorrencia.unico ? diaSemana : null,
                  recorrenciaTipo: recTipo,
                  recorrenciaValor: recTipo == TipoRecorrencia.mensalPosicao
                      ? recValor
                      : null,
                );

                if (isEdit) {
                  await ref
                      .read(agendaRepoProvider)
                      .atualizar(item.id, novoItem.toMap());
                } else {
                  await ref.read(agendaRepoProvider).inserir(novoItem);
                }
                ref.invalidate(agendaProvider);
                ref.invalidate(proximasAtividadesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ministérios Config ───────────────────────────────────────────────────────
class _MinisteriosConfig extends ConsumerWidget {
  const _MinisteriosConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ministeriosProvider);
    return async.when(
      data: (lista) => Column(
        children: [
          ...lista.map(
            (m) => _ItemConfig(
              titulo: m.nome,
              icone: m.iconData,
              onEdit: () => _add(context, ref, m),
              onDelete: () async {
                final ok = await ConfirmDialog.show(
                  context,
                  titulo: 'Excluir Ministério',
                  mensagem: 'Excluir o ministério "${m.nome}"?',
                  labelConfirmar: 'Excluir',
                  perigo: true,
                );
                if (ok) {
                  await ref.read(ministeriosRepoProvider).excluir(m.nome);
                  ref.invalidate(ministeriosProvider);
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Adicionar Ministério',
            outlined: true,
            icon: PhosphorIconsBold.plus,
            onPressed: () => _add(context, ref),
            width: double.infinity,
          ),
        ],
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.acento),
      ),
      error: (e, _) => Text('Erro', style: AppTextStyles.body()),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref, [
    Ministerio? m,
  ]) async {
    final isEdit = m != null;
    final ctrl = TextEditingController(text: m?.nome);
    String? iconeSel = m?.icone ?? 'users';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: context.bgCard,
          title: Text(
            isEdit ? 'Editar Ministério' : 'Novo Ministério',
            style: AppTextStyles.heading(),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(label: 'Nome', controller: ctrl, enabled: !isEdit),
              const SizedBox(height: 16),
              Text(
                'Ícone do ministério:',
                style: AppTextStyles.bodySmall(
                  color: context.textoPrimario,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 132,
                width: double.maxFinite,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: Ministerio.availableIcons.length,
                  itemBuilder: (ctx, i) {
                    final entry = Ministerio.availableIcons.entries.elementAt(i);
                    final isSel = iconeSel == entry.key;
                    return GestureDetector(
                      onTap: () => ss(() => iconeSel = entry.key),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.acento : context.bgSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? AppColors.acento : context.bgBorda,
                          ),
                        ),
                        child: Icon(
                          entry.value,
                          color: isSel ? Colors.white : context.textoSecund,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                if (isEdit) {
                  await ref
                      .read(ministeriosRepoProvider)
                      .atualizarIcone(m.nome, iconeSel!);
                } else {
                  await ref.read(ministeriosRepoProvider).inserir(
                        Ministerio(nome: ctrl.text.trim(), icone: iconeSel),
                      );
                }
                ref.invalidate(ministeriosProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Funções Config ───────────────────────────────────────────────────────────
class _FuncoesConfig extends ConsumerWidget {
  const _FuncoesConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministeriosAsync = ref.watch(ministeriosProvider);
    final funcoesAsync = ref.watch(funcoesProvider);

    return funcoesAsync.when(
      data: (funcs) => ministeriosAsync.when(
        data: (mins) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...mins.map((m) {
              final ff =
                  funcs.where((f) => f.ministerioPai == m.nome).toList();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: context.bgSubtle,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      m.nome,
                      style: AppTextStyles.body(
                        color: context.textoPrimario,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: Text(
                      '${ff.length}',
                      style: AppTextStyles.monoSmall(
                        color: context.acentoTexto,
                      ),
                    ),
                    iconColor: context.corPrimaria,
                    collapsedIconColor: context.textoSecund,
                    childrenPadding:
                        const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    children: [
                      ...ff.map(
                        (f) => _ItemConfig(
                          titulo: f.nomeFuncao,
                          onDelete: () async {
                            await ref.read(funcoesRepoProvider).excluir(f.id);
                            ref.invalidate(funcoesProvider);
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: Icon(
                            PhosphorIconsBold.plus,
                            size: 16,
                            color: context.corPrimaria,
                          ),
                          label: Text(
                            'Nova função em ${m.nome}',
                            style: AppTextStyles.bodySmall(
                              color: context.corPrimaria,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => _add(context, ref, m.nome),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        loading: () => const CircularProgressIndicator(color: AppColors.acento),
        error: (_, __) => const SizedBox.shrink(),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.acento),
      ),
      error: (e, _) => Text('Erro', style: AppTextStyles.body()),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    String ministerio,
  ) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'Nova Função — $ministerio',
          style: AppTextStyles.heading(),
        ),
        content: AppTextField(label: 'Nome da Função', controller: ctrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref.read(funcoesRepoProvider).inserir(
                    ministerioPai: ministerio,
                    nomeFuncao: ctrl.text.trim(),
                  );
              ref.invalidate(funcoesProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// ─── Regras Config ────────────────────────────────────────────────────────────
class _RegrasConfig extends ConsumerWidget {
  const _RegrasConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regrasAsync = ref.watch(regrasProvider);
    final agendaAsync = ref.watch(agendaProvider);

    return regrasAsync.when(
      data: (regras) => agendaAsync.when(
        data: (agenda) {
          final cultos =
              agenda.where((item) => item.tipo == TipoAgenda.culto).toList();
          final agrupadas = <String, List<Regra>>{};
          final diasNomes = [
            'Domingo',
            'Segunda',
            'Terça',
            'Quarta',
            'Quinta',
            'Sexta',
            'Sábado',
          ];

          for (final c in cultos) {
            final diaCompleto = c.recorrenciaTipo == TipoRecorrencia.semanal
                ? diasNomes[c.diaSemana!]
                : '';

            final chave = '${c.diaSemana}_${c.horario}';
            agrupadas[chave] = regras
                .where(
                  (r) => r.diaSemana == diaCompleto && r.horario == c.horario,
                )
                .toList();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...cultos.map((c) {
                final chave = '${c.diaSemana}_${c.horario}';
                final regrasDoCulto = agrupadas[chave] ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.bgSubtle,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: Icon(
                        PhosphorIconsRegular.church,
                        color: context.corPrimaria,
                        size: 18,
                      ),
                      title: Text(
                        '${diasNomes[c.diaSemana!]} ${c.horario} · ${c.titulo}',
                        style: AppTextStyles.body(
                          color: context.textoPrimario,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      iconColor: context.corPrimaria,
                      collapsedIconColor: context.textoSecund,
                      childrenPadding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              PhosphorIconsRegular.pencilSimple,
                              color: context.corPrimaria,
                              size: 18,
                            ),
                            onPressed: () =>
                                _configurarRegrasCulto(context, ref, c),
                            tooltip: 'Configurar Regras',
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: [
                        if (regrasDoCulto.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Text(
                              'Nenhuma regra definida para este culto.',
                              style: AppTextStyles.bodySmall(
                                color: context.textoSecund,
                              ),
                            ),
                          )
                        else
                          ...regrasDoCulto.map(
                            (r) => _ItemConfig(
                              titulo: '${r.ministerio} — ${r.funcao}',
                              subtitulo: 'Quantidade: ${r.qtd}',
                              onEdit: () =>
                                  _configurarRegrasCulto(context, ref, c),
                              onDelete: () async {
                                final ok = await ConfirmDialog.show(
                                  context,
                                  titulo: 'Excluir Regra',
                                  mensagem:
                                      'Excluir regra ${r.ministerio}/${r.funcao}?',
                                  labelConfirmar: 'Excluir',
                                  perigo: true,
                                );
                                if (ok) {
                                  await ref
                                      .read(regrasRepoProvider)
                                      .excluir(r.id);
                                  ref.invalidate(regrasProvider);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.acento),
        ),
        error: (e, _) => Text('Erro', style: AppTextStyles.body()),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.acento),
      ),
      error: (e, _) => Text('Erro', style: AppTextStyles.body()),
    );
  }

  Future<void> _configurarRegrasCulto(
    BuildContext context,
    WidgetRef ref,
    AgendaItem? cultoInicial,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.acento),
      ),
    );

    late final List<AgendaItem> cultos;
    late final List<Ministerio> ministerios;
    late final List<Funcao> funcoes;
    late final List<Regra> regras;
    late AgendaItem cultoSelecionado;

    try {
      final agenda = await ref.read(agendaProvider.future);
      cultos = agenda.where((i) => i.tipo == TipoAgenda.culto).toList();
      if (cultos.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context);
          AppSnackbar.show(context, 'Nenhum culto cadastrado.', erro: true);
        }
        return;
      }

      cultoSelecionado = cultoInicial ?? cultos.first;
      ministerios = await ref.read(ministeriosProvider.future);
      funcoes = await ref.read(funcoesProvider.future);
      regras = await ref.read(regrasProvider.future);

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        AppSnackbar.show(context, 'Erro ao carregar dados: $e', erro: true);
      }
      return;
    }

    final Map<String, int> qtds = {};
    final diasNomes = [
      'Domingo',
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
    ];

    void inicializarQtds(AgendaItem c) {
      qtds.clear();
      for (final min in ministerios) {
        final funcsDoMin =
            funcoes.where((f) => f.ministerioPai == min.nome).toList();
        for (final f in funcsDoMin) {
          qtds['${min.nome}_${f.nomeFuncao}'] = 0;
        }
      }
      final diaStr = diasNomes[c.diaSemana!];
      final regrasDoCulto = regras
          .where((r) => r.diaSemana == diaStr && r.horario == c.horario);
      for (final r in regrasDoCulto) {
        qtds['${r.ministerio}_${r.funcao}'] = r.qtd;
      }
    }

    inicializarQtds(cultoSelecionado);

    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (ctx, ss) {
            return AlertDialog(
              backgroundColor: context.bgCard,
              title: Text(
                'Configurar Regras do Culto',
                style: AppTextStyles.heading(),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<AgendaItem>(
                      initialValue: cultoSelecionado,
                      isExpanded: true,
                      dropdownColor: context.bgCard,
                      style: AppTextStyles.body(color: context.textoPrimario),
                      decoration: const InputDecoration(labelText: 'Culto'),
                      items: cultos
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${diasNomes[c.diaSemana!]} - ${c.horario} (${c.titulo})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          ss(() {
                            cultoSelecionado = v;
                            inicializarQtds(v);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: ministerios.map((min) {
                          final funcsDoMin = funcoes
                              .where((f) => f.ministerioPai == min.nome)
                              .toList();
                          if (funcsDoMin.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return ExpansionTile(
                            title: Text(
                              min.nome,
                              style: AppTextStyles.body(
                                color: context.corPrimaria,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            initiallyExpanded: true,
                            children: funcsDoMin.map((f) {
                              final chave = '${min.nome}_${f.nomeFuncao}';
                              final qtd = qtds[chave] ?? 0;

                              return ListTile(
                                dense: true,
                                title: Text(
                                  f.nomeFuncao,
                                  style: AppTextStyles.body(
                                    color: context.textoPrimario,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.remove_circle_outline,
                                        size: 20,
                                        color: context.corPrimaria,
                                      ),
                                      onPressed: () => ss(() {
                                        qtds[chave] = (qtd - 1).clamp(0, 10);
                                      }),
                                    ),
                                    SizedBox(
                                      width: 24,
                                      child: Text(
                                        '$qtd',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.mono(
                                          color: context.textoPrimario,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                        color: context.corPrimaria,
                                      ),
                                      onPressed: () => ss(() {
                                        qtds[chave] = (qtd + 1).clamp(0, 10);
                                      }),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final diaStr = diasNomes[cultoSelecionado.diaSemana!];
                    final regrasAtuais = regras
                        .where(
                          (r) =>
                              r.diaSemana == diaStr &&
                              r.horario == cultoSelecionado.horario,
                        )
                        .toList();

                    for (final min in ministerios) {
                      final funcsDoMin = funcoes
                          .where((f) => f.ministerioPai == min.nome)
                          .toList();
                      for (final f in funcsDoMin) {
                        final chave = '${min.nome}_${f.nomeFuncao}';
                        final novaQtd = qtds[chave] ?? 0;

                        final regraExistente =
                            regrasAtuais.cast<Regra?>().firstWhere(
                                  (r) =>
                                      r?.ministerio == min.nome &&
                                      r?.funcao == f.nomeFuncao,
                                  orElse: () => null,
                                );

                        if (novaQtd > 0) {
                          if (regraExistente != null) {
                            if (regraExistente.qtd != novaQtd) {
                              await ref.read(regrasRepoProvider).atualizar(
                                regraExistente.id,
                                {'qtd': novaQtd},
                              );
                            }
                          } else {
                            await ref.read(regrasRepoProvider).inserir(
                                  Regra(
                                    id: '',
                                    diaSemana: diaStr,
                                    horario: cultoSelecionado.horario,
                                    ministerio: min.nome,
                                    funcao: f.nomeFuncao,
                                    qtd: novaQtd,
                                    createdAt: DateTime.now(),
                                  ),
                                );
                          }
                        } else {
                          if (regraExistente != null) {
                            await ref
                                .read(regrasRepoProvider)
                                .excluir(regraExistente.id);
                          }
                        }
                      }
                    }

                    ref.invalidate(regrasProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        ),
      );
    }
  }
}

// ─── Item Config ──────────────────────────────────────────────────────────────
class _ItemConfig extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData? icone;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const _ItemConfig({
    required this.titulo,
    this.subtitulo,
    this.icone,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.bgBorda),
      ),
      child: Row(
        children: [
          if (icone != null) ...[
            Icon(icone, color: context.corPrimaria, size: 19),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppTextStyles.body(
                    color: context.textoPrimario,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: AppTextStyles.bodySmall(color: context.textoSecund),
                  ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(
                PhosphorIconsRegular.pencilSimple,
                color: context.corPrimaria,
                size: 18,
              ),
              onPressed: onEdit,
            ),
          IconButton(
            icon: const Icon(
              PhosphorIconsRegular.trash,
              color: AppColors.perigo,
              size: 18,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ─── Acúmulos Config ──────────────────────────────────────────────────────────
class _AcumulosConfig extends ConsumerWidget {
  const _AcumulosConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compatibilidadesAsync = ref.watch(compatibilidadesProvider);

    return compatibilidadesAsync.when(
      data: (lista) {
        if (lista.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Nenhum acúmulo pendente ou configurado.',
              style: AppTextStyles.bodySmall(color: context.textoSecund),
            ),
          );
        }

        final pendentes = lista.where((c) => c.status == 'pendente').toList();
        final aprovados = lista.where((c) => c.status == 'aprovado').toList();
        final rejeitados = lista.where((c) => c.status == 'rejeitado').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendentes.isNotEmpty) ...[
              Text(
                'Pendentes de Revisão',
                style: AppTextStyles.label(
                  color: AppColors.alerta,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...pendentes.map((c) => _ItemAcumulo(compatibilidade: c)),
              Divider(color: context.bgBorda, height: 24),
            ],
            if (aprovados.isNotEmpty) ...[
              Text(
                'Permitidos',
                style: AppTextStyles.label(
                  color: AppColors.sucesso,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...aprovados.map((c) => _ItemAcumulo(compatibilidade: c)),
              Divider(color: context.bgBorda, height: 24),
            ],
            if (rejeitados.isNotEmpty) ...[
              Text(
                'Bloqueados',
                style: AppTextStyles.label(
                  color: AppColors.perigo,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...rejeitados.map((c) => _ItemAcumulo(compatibilidade: c)),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.acento),
      ),
      error: (e, _) => Text('Erro', style: AppTextStyles.body()),
    );
  }
}

class _ItemAcumulo extends ConsumerWidget {
  final Compatibilidade compatibilidade;

  const _ItemAcumulo({required this.compatibilidade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isPendente = compatibilidade.status == 'pendente';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.bgSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPendente ? AppColors.alerta : context.bgBorda,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compatibilidade.ministerio,
                  style: AppTextStyles.label(
                    color: context.corPrimaria,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${compatibilidade.funcao1} + ${compatibilidade.funcao2}',
                  style: AppTextStyles.body(
                    color: context.textoPrimario,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (isPendente) ...[
            IconButton(
              icon: const Icon(
                PhosphorIconsBold.checkCircle,
                color: AppColors.sucesso,
              ),
              tooltip: 'Permitir Acúmulo',
              onPressed: () async {
                await ref
                    .read(compatibilidadesRepoProvider)
                    .atualizarStatus(compatibilidade.id, 'aprovado');
                ref.invalidate(compatibilidadesProvider);
              },
            ),
            IconButton(
              icon: const Icon(
                PhosphorIconsBold.prohibit,
                color: AppColors.perigo,
              ),
              tooltip: 'Bloquear Acúmulo',
              onPressed: () async {
                await ref
                    .read(compatibilidadesRepoProvider)
                    .atualizarStatus(compatibilidade.id, 'rejeitado');
                ref.invalidate(compatibilidadesProvider);
              },
            ),
          ] else ...[
            TextButton(
              onPressed: () async {
                final novoStatus = compatibilidade.status == 'aprovado'
                    ? 'rejeitado'
                    : 'aprovado';
                await ref
                    .read(compatibilidadesRepoProvider)
                    .atualizarStatus(compatibilidade.id, novoStatus);
                ref.invalidate(compatibilidadesProvider);
              },
              child: Text(
                compatibilidade.status == 'aprovado' ? 'Bloquear' : 'Permitir',
                style: AppTextStyles.bodySmall(
                  color: compatibilidade.status == 'aprovado'
                      ? AppColors.perigo
                      : AppColors.sucesso,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Jejum Config ─────────────────────────────────────────────────────────────
class _JejumConfig extends ConsumerWidget {
  const _JejumConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(cfgJejumProvider);

    return configAsync.when(
      data: (config) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Integrantes por dia',
                    style: AppTextStyles.body(
                      color: context.textoPrimario,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Quantidade de pessoas escaladas no rodízio diário.',
                    style: AppTextStyles.bodySmall(color: context.textoSecund),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    PhosphorIconsBold.minusCircle,
                    color: context.corPrimaria,
                  ),
                  onPressed: config.qtdMembros <= 1
                      ? null
                      : () async {
                          await ref
                              .read(cfgJejumRepoProvider)
                              .atualizar(config.qtdMembros - 1);
                          ref.invalidate(cfgJejumProvider);
                        },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.bgSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.bgBorda),
                  ),
                  child: Text(
                    '${config.qtdMembros}',
                    style: AppTextStyles.mono(
                      color: context.textoPrimario,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    PhosphorIconsBold.plusCircle,
                    color: context.corPrimaria,
                  ),
                  onPressed: () async {
                    await ref
                        .read(cfgJejumRepoProvider)
                        .atualizar(config.qtdMembros + 1);
                    ref.invalidate(cfgJejumProvider);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.acento),
      ),
      error: (e, _) => Text('Erro: $e', style: AppTextStyles.body()),
    );
  }
}

// ─── Home Config ──────────────────────────────────────────────────────────────
class _HomeConfig extends ConsumerWidget {
  const _HomeConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(homePreferencesProvider);
    final ministeriosAsync = ref.watch(ministeriosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Mostrar Próximas Escalas',
            style: AppTextStyles.body(
              color: context.textoPrimario,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Exibe os cartões de escala no início',
            style: AppTextStyles.bodySmall(color: context.textoSecund),
          ),
          value: prefs.mostrarEscalas,
          activeThumbColor: AppColors.acento,
          onChanged: (v) =>
              ref.read(homePreferencesProvider.notifier).toggle('escalas', v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Mostrar Agenda da Igreja',
            style: AppTextStyles.body(
              color: context.textoPrimario,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Exibe os próximos cultos e eventos',
            style: AppTextStyles.bodySmall(color: context.textoSecund),
          ),
          value: prefs.mostrarEventos,
          activeThumbColor: AppColors.acento,
          onChanged: (v) =>
              ref.read(homePreferencesProvider.notifier).toggle('eventos', v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Mostrar Escala de Jejum',
            style: AppTextStyles.body(
              color: context.textoPrimario,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Exibe os integrantes escalados para jejum hoje',
            style: AppTextStyles.bodySmall(color: context.textoSecund),
          ),
          value: prefs.mostrarJejum,
          activeThumbColor: AppColors.acento,
          onChanged: (v) =>
              ref.read(homePreferencesProvider.notifier).toggle('jejum', v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Mostrar Participações do Mês',
            style: AppTextStyles.body(
              color: context.textoPrimario,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Exibe o resumo mensal de participações',
            style: AppTextStyles.bodySmall(color: context.textoSecund),
          ),
          value: prefs.mostrarRelatorio,
          activeThumbColor: AppColors.acento,
          onChanged: (v) =>
              ref.read(homePreferencesProvider.notifier).toggle('relatorio', v),
        ),
        Divider(color: context.bgBorda, height: 24),
        Text(
          'Filtrar Ministérios na Home',
          style: AppTextStyles.bodySmall(
            color: context.textoPrimario,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Se nenhum estiver marcado, todos os ministérios serão exibidos.',
          style: AppTextStyles.bodySmall(color: context.textoSecund),
        ),
        const SizedBox(height: 10),
        ministeriosAsync.when(
          data: (lista) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: lista.map((m) {
              final selecionado = prefs.ministeriosVisiveis.contains(m.nome);
              return FilterChip(
                label: Text(
                  m.nome,
                  style: AppTextStyles.bodySmall(
                    color: selecionado ? Colors.white : context.textoPrimario,
                    fontWeight:
                        selecionado ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: selecionado,
                onSelected: (_) => ref
                    .read(homePreferencesProvider.notifier)
                    .toggleMinisterio(m.nome),
                selectedColor: AppColors.acento,
                backgroundColor: context.bgSubtle,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: selecionado ? AppColors.acento : context.bgBorda,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }).toList(),
          ),
          loading: () =>
              const CircularProgressIndicator(color: AppColors.acento),
          error: (_, __) => const Text('Erro ao carregar ministérios'),
        ),
      ],
    );
  }
}
