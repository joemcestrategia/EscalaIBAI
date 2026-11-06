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
        title: Text('Configurações', style: AppTextStyles.heading()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _SecaoExpansivel(
            titulo: 'Aparência',
            icone: PhosphorIconsBold.palette,
            child: _TemaConfig(),
          ),
          const SizedBox(height: 8),
          const _SecaoExpansivel(
            titulo: 'Tela Inicial (Home)',
            icone: PhosphorIconsBold.house,
            child: _HomeConfig(),
          ),
          if (!isMembro) ...[
            const SizedBox(height: 8),
            const _SecaoExpansivel(
              titulo: 'Cultos',
              icone: PhosphorIconsBold.church,
              child: _CultosConfig(),
            ),
            const SizedBox(height: 8),
            const _SecaoExpansivel(
              titulo: 'Eventos e Reuniões',
              icone: PhosphorIconsBold.calendarStar,
              child: _AgendaConfig(),
            ),
            const SizedBox(height: 8),
            const _SecaoExpansivel(
              titulo: 'Ministérios',
              icone: PhosphorIconsBold.users,
              child: _MinisteriosConfig(),
            ),
            const SizedBox(height: 8),
            const _SecaoExpansivel(
              titulo: 'Funções',
              icone: PhosphorIconsBold.tag,
              child: _FuncoesConfig(),
            ),
            const SizedBox(height: 8),
            const _SecaoExpansivel(
              titulo: 'Regras de Escala',
              icone: PhosphorIconsBold.listChecks,
              child: _RegrasConfig(),
            ),
            const SizedBox(height: 8),
            const _SecaoExpansivel(
              titulo: 'Revisar Acúmulos de Função',
              icone: PhosphorIconsBold.intersect,
              child: _AcumulosConfig(),
            ),
            const SizedBox(height: 8),
            const _SecaoExpansivel(
              titulo: 'Escala de Jejum',
              icone: PhosphorIconsBold.drop,
              child: _JejumConfig(),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final scaffold = ScaffoldMessenger.of(context);
              scaffold.showSnackBar(
                const SnackBar(content: Text('Verificando atualizações...')),
              );
              final update = await UpdateService.checkForUpdate();
              if (context.mounted) {
                scaffold.hideCurrentSnackBar();
                if (update != null) {
                  UpdateService.checkForUpdateAndPrompt(context);
                } else {
                  scaffold.showSnackBar(
                    const SnackBar(
                      content: Text('O aplicativo já está na versão mais recente!'),
                      backgroundColor: AppColors.sucesso,
                    ),
                  );
                }
              }
            },
            icon: const Icon(PhosphorIconsBold.arrowsClockwise, color: AppColors.acento),
            label: const Text('Verificar Atualizações', style: TextStyle(color: AppColors.acento)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.acento),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: Text('Alterar Perfil', style: AppTextStyles.heading(color: Colors.white)),
                  content: Text('Deseja realmente sair e escolher outro perfil de acesso?', style: AppTextStyles.body(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sair', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(userRoleProvider.notifier).logout();
                ref.invalidate(userRoleProvider);
              }
            },
            icon: const Icon(PhosphorIconsBold.signOut, color: Colors.redAccent),
            label: const Text('Alterar Perfil / Sair', style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SecaoExpansivel extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final Widget child;

  const _SecaoExpansivel({
    required this.titulo,
    required this.icone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight),
      ),
      child: ExpansionTile(
        leading: Icon(icone, color: AppColors.acento, size: 20),
        title: Text(titulo, style: AppTextStyles.subheading()),
        iconColor: AppColors.acento,
        collapsedIconColor: context.textoSecund,
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [child],
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
        final eventosEReunioes = lista.where((item) => item.tipo != TipoAgenda.culto).toList();
        
        return Column(
          children: [
            if (eventosEReunioes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Nenhum evento ou reunião cadastrado.', style: AppTextStyles.bodySmall(color: AppColors.textoMuted)),
              )
            else
              ...eventosEReunioes.map((item) {
                String recorrencia = '';
                if (item.recorrenciaTipo == TipoRecorrencia.semanal) {
                  final dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
                  recorrencia = 'Toda ${dias[item.diaSemana!]}';
                } else if (item.recorrenciaTipo == TipoRecorrencia.mensalPosicao) {
                  final dias = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
                  final posicoes = {1: '1º', 2: '2º', 3: '3º', 4: '4º', -1: 'Último'};
                  recorrencia = '${posicoes[item.recorrenciaValor]} ${dias[item.diaSemana!]} do mês';
                } else {
                  recorrencia = DateFormat('dd/MM/yyyy').format(item.dataEspecifica!);
                }

                IconData icone = PhosphorIconsBold.calendarStar;
                if (item.tipo == TipoAgenda.reuniao) icone = PhosphorIconsBold.usersThree;

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
            const SizedBox(height: 8),
            AppButton(
              label: 'Adicionar Evento/Reunião',
              outlined: true,
              icon: PhosphorIconsBold.plus,
              onPressed: () => _showAgendaDialog(context, ref),
              width: double.infinity,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
      error: (e, _) => Text('Erro: $e', style: AppTextStyles.body()),
    );
  }

  Future<void> _showAgendaDialog(BuildContext context, WidgetRef ref, {AgendaItem? item}) async {
    final isEdit = item != null;
    TipoAgenda tipo = item?.tipo ?? TipoAgenda.evento;
    TipoRecorrencia recTipo = item?.recorrenciaTipo ?? TipoRecorrencia.semanal;
    int? diaSemana = item?.diaSemana ?? 0;
    int? recValor = item?.recorrenciaValor ?? 1;
    DateTime? dataUnica = item?.dataEspecifica ?? DateTime.now();
    final tituloCtrl = TextEditingController(text: item?.titulo);
    
    final hParts = (item?.horario ?? '19:30').split(':');
    TimeOfDay hora = TimeOfDay(hour: int.parse(hParts[0]), minute: int.parse(hParts[1]));

    final dias = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    final posicoes = {1: '1º', 2: '2º', 3: '3º', 4: '4º', -1: 'Último'};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: context.bgCard,
          title: Text(isEdit ? 'Editar Agenda' : 'Novo na Agenda', style: AppTextStyles.heading()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(label: 'Título/Tema', controller: tituloCtrl),
                const SizedBox(height: 12),
                DropdownButtonFormField<TipoAgenda>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  dropdownColor: context.bgCard,
                  items: [TipoAgenda.evento, TipoAgenda.reuniao].map((t) => DropdownMenuItem(
                    value: t, 
                    child: Text(t == TipoAgenda.evento ? 'Evento' : 'Reunião')
                  )).toList(),
                  onChanged: (v) => ss(() => tipo = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TipoRecorrencia>(
                  initialValue: recTipo,
                  decoration: const InputDecoration(labelText: 'Recorrência'),
                  dropdownColor: context.bgCard,
                  items: TipoRecorrencia.values.map((t) => DropdownMenuItem(
                    value: t, 
                    child: Text(t == TipoRecorrencia.semanal ? 'Semanal' : t == TipoRecorrencia.mensalPosicao ? 'Mensal (Posição)' : 'Data Única')
                  )).toList(),
                  onChanged: (v) => ss(() => recTipo = v!),
                ),
                if (recTipo == TipoRecorrencia.unico) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: dataUnica!,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (d != null) ss(() => dataUnica = d);
                    },
                    child: Text(DateFormat('dd/MM/yyyy').format(dataUnica!)),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: diaSemana,
                    decoration: const InputDecoration(labelText: 'Dia da Semana'),
                    dropdownColor: context.bgCard,
                    items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(dias[i]))),
                    onChanged: (v) => ss(() => diaSemana = v!),
                  ),
                  if (recTipo == TipoRecorrencia.mensalPosicao) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: recValor,
                      decoration: const InputDecoration(labelText: 'Posição no Mês'),
                      dropdownColor: context.bgCard,
                      items: posicoes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                      onChanged: (v) => ss(() => recValor = v!),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: ctx, initialTime: hora);
                    if (t != null) ss(() => hora = t);
                  },
                  child: Text('Horário: ${hora.format(context)}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (tituloCtrl.text.isEmpty) return;
                final novoItem = AgendaItem(
                  id: item?.id ?? '',
                  tipo: tipo,
                  titulo: tituloCtrl.text.trim(),
                  dataEspecifica: recTipo == TipoRecorrencia.unico ? dataUnica : null,
                  horario: '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
                  diaSemana: recTipo != TipoRecorrencia.unico ? diaSemana : null,
                  recorrenciaTipo: recTipo,
                  recorrenciaValor: recTipo == TipoRecorrencia.mensalPosicao ? recValor : null,
                );

                if (isEdit) {
                  await ref.read(agendaRepoProvider).atualizar(item.id, novoItem.toMap());
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
        final cultos = lista.where((item) => item.tipo == TipoAgenda.culto).toList();
        
        return Column(
          children: [
            if (cultos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Nenhum culto cadastrado.', style: AppTextStyles.bodySmall(color: AppColors.textoMuted)),
              )
            else
              ...cultos.map((item) {
                String recorrencia = '';
                if (item.recorrenciaTipo == TipoRecorrencia.semanal) {
                  final dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
                  recorrencia = 'Toda ${dias[item.diaSemana!]}';
                } else if (item.recorrenciaTipo == TipoRecorrencia.mensalPosicao) {
                  final dias = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
                  final posicoes = {1: '1º', 2: '2º', 3: '3º', 4: '4º', -1: 'Último'};
                  recorrencia = '${posicoes[item.recorrenciaValor]} ${dias[item.diaSemana!]} do mês';
                } else {
                  recorrencia = DateFormat('dd/MM/yyyy').format(item.dataEspecifica!);
                }

                return _ItemConfig(
                  titulo: item.titulo,
                  subtitulo: '$recorrencia às ${item.horario}',
                  icone: PhosphorIconsBold.church,
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
            const SizedBox(height: 8),
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
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
      error: (e, _) => Text('Erro: $e', style: AppTextStyles.body()),
    );
  }

  Future<void> _showCultoDialog(BuildContext context, WidgetRef ref, {AgendaItem? item}) async {
    final isEdit = item != null;
    TipoRecorrencia recTipo = item?.recorrenciaTipo ?? TipoRecorrencia.semanal;
    int? diaSemana = item?.diaSemana ?? 0;
    int? recValor = item?.recorrenciaValor ?? 1;
    DateTime? dataUnica = item?.dataEspecifica ?? DateTime.now();
    final tituloCtrl = TextEditingController(text: item?.titulo);
    
    final hParts = (item?.horario ?? '19:30').split(':');
    TimeOfDay hora = TimeOfDay(hour: int.parse(hParts[0]), minute: int.parse(hParts[1]));

    final dias = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    final posicoes = {1: '1º', 2: '2º', 3: '3º', 4: '4º', -1: 'Último'};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: context.bgCard,
          title: Text(isEdit ? 'Editar Culto' : 'Novo Culto', style: AppTextStyles.heading()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(label: 'Título/Tema', controller: tituloCtrl),
                const SizedBox(height: 12),
                DropdownButtonFormField<TipoRecorrencia>(
                  initialValue: recTipo,
                  decoration: const InputDecoration(labelText: 'Recorrência'),
                  dropdownColor: context.bgCard,
                  items: TipoRecorrencia.values.map((t) => DropdownMenuItem(
                    value: t, 
                    child: Text(t == TipoRecorrencia.semanal ? 'Semanal' : t == TipoRecorrencia.mensalPosicao ? 'Mensal (Posição)' : 'Data Única')
                  )).toList(),
                  onChanged: (v) => ss(() => recTipo = v!),
                ),
                if (recTipo == TipoRecorrencia.unico) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: dataUnica!,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (d != null) ss(() => dataUnica = d);
                    },
                    child: Text(DateFormat('dd/MM/yyyy').format(dataUnica!)),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: diaSemana,
                    decoration: const InputDecoration(labelText: 'Dia da Semana'),
                    dropdownColor: context.bgCard,
                    items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(dias[i]))),
                    onChanged: (v) => ss(() => diaSemana = v!),
                  ),
                  if (recTipo == TipoRecorrencia.mensalPosicao) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: recValor,
                      decoration: const InputDecoration(labelText: 'Posição no Mês'),
                      dropdownColor: context.bgCard,
                      items: posicoes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                      onChanged: (v) => ss(() => recValor = v!),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: ctx, initialTime: hora);
                    if (t != null) ss(() => hora = t);
                  },
                  child: Text('Horário: ${hora.format(context)}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (tituloCtrl.text.isEmpty) return;
                final novoItem = AgendaItem(
                  id: item?.id ?? '',
                  tipo: TipoAgenda.culto,
                  titulo: tituloCtrl.text.trim(),
                  dataEspecifica: recTipo == TipoRecorrencia.unico ? dataUnica : null,
                  horario: '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
                  diaSemana: recTipo != TipoRecorrencia.unico ? diaSemana : null,
                  recorrenciaTipo: recTipo,
                  recorrenciaValor: recTipo == TipoRecorrencia.mensalPosicao ? recValor : null,
                );

                if (isEdit) {
                  await ref.read(agendaRepoProvider).atualizar(item.id, novoItem.toMap());
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
          ...lista.map((m) => _ItemConfig(
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
              )),
          const SizedBox(height: 8),
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
          child: CircularProgressIndicator(color: AppColors.acento)),
      error: (e, _) => Text('Erro', style: AppTextStyles.body()),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, [Ministerio? m]) async {
    final isEdit = m != null;
    final ctrl = TextEditingController(text: m?.nome);
    String? iconeSel = m?.icone ?? 'users';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: context.bgCard,
          title: Text(isEdit ? 'Editar Ministério' : 'Novo Ministério', style: AppTextStyles.heading()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(label: 'Nome', controller: ctrl, enabled: !isEdit),
              const SizedBox(height: 16),
              Text('Ícone:', style: AppTextStyles.label()),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
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
                          color: isSel ? AppColors.acento.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? AppColors.acento : context.bgBorda),
                        ),
                        child: Icon(entry.value, color: isSel ? AppColors.acento : context.textoSecund, size: 20),
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
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                if (isEdit) {
                  await ref.read(ministeriosRepoProvider).atualizarIcone(m.nome, iconeSel!);
                } else {
                  await ref.read(ministeriosRepoProvider).inserir(
                    Ministerio(nome: ctrl.text.trim(), icone: iconeSel)
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
              final ff = funcs.where((f) => f.ministerioPai == m.nome).toList();
              return ExpansionTile(
                title: Text(m.nome, style: AppTextStyles.label(color: AppColors.acento)),
                iconColor: AppColors.acento,
                collapsedIconColor: context.textoSecund,
                childrenPadding: const EdgeInsets.only(left: 12, bottom: 8),
                children: [
                  ...ff.map((f) => _ItemConfig(
                        titulo: f.nomeFuncao,
                        onDelete: () async {
                          await ref.read(funcoesRepoProvider).excluir(f.id);
                          ref.invalidate(funcoesProvider);
                        },
                      )),
                  TextButton.icon(
                    icon: const Icon(PhosphorIconsBold.plus, size: 14),
                    label: Text('Adicionar função em ${m.nome}',
                        style: AppTextStyles.bodySmall(
                            color: AppColors.acentoAzul)),
                    onPressed: () => _add(context, ref, m.nome),
                  ),
                ],
              );
            }),
          ],
        ),
        loading: () => const CircularProgressIndicator(),
        error: (_, __) => const SizedBox(),
      ),
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.acento)),
      error: (e, _) => Text('Erro', style: AppTextStyles.body()),
    );
  }

  Future<void> _add(
      BuildContext context, WidgetRef ref, String ministerio) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.bgCard,
        title:
            Text('Nova Função — $ministerio', style: AppTextStyles.heading()),
        content: AppTextField(label: 'Nome da Função', controller: ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
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
          final cultos = agenda.where((item) => item.tipo == TipoAgenda.culto).toList();
          final agrupadas = <String, List<Regra>>{};
          final diasNomes = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

          for (final c in cultos) {
            final diaCompleto = c.recorrenciaTipo == TipoRecorrencia.semanal 
              ? diasNomes[c.diaSemana!]
              : '';

            final chave = '${c.diaSemana}_${c.horario}';
            agrupadas[chave] = regras
                .where((r) => r.diaSemana == diaCompleto && r.horario == c.horario)
                .toList();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...cultos.map((c) {
                final chave = '${c.diaSemana}_${c.horario}';
                final regrasDoCulto = agrupadas[chave] ?? [];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: context.bgPrincipal.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.bgBorda.withValues(alpha: 0.5)),
                  ),
                  child: ExpansionTile(
                    leading: const Icon(PhosphorIconsBold.church, color: AppColors.acento, size: 16),
                    title: Text(
                      '${['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'][c.diaSemana!]} ${c.horario} - ${c.titulo}',
                      style: AppTextStyles.body(color: AppColors.acento).copyWith(fontWeight: FontWeight.bold),
                    ),
                    iconColor: AppColors.acento,
                    collapsedIconColor: context.textoSecund,
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(PhosphorIconsBold.pencilSimple, color: AppColors.acento, size: 16),
                          onPressed: () => _configurarRegrasCulto(context, ref, c),
                          tooltip: 'Configurar Regras',
                        ),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                    children: [
                      if (regrasDoCulto.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Text(
                            'Nenhuma regra definida para este culto.',
                            style: AppTextStyles.bodySmall(color: AppColors.textoMuted),
                          ),
                        )
                      else
                        ...regrasDoCulto.map((r) => _ItemConfig(
                              titulo: '${r.ministerio} — ${r.funcao}',
                              subtitulo: 'Quantidade: ${r.qtd}',
                              onEdit: () => _configurarRegrasCulto(context, ref, c),
                              onDelete: () async {
                                final ok = await ConfirmDialog.show(
                                  context,
                                  titulo: 'Excluir Regra',
                                  mensagem: 'Excluir regra ${r.ministerio}/${r.funcao}?',
                                  labelConfirmar: 'Excluir',
                                  perigo: true,
                                );
                                if (ok) {
                                  await ref.read(regrasRepoProvider).excluir(r.id);
                                  ref.invalidate(regrasProvider);
                                }
                              },
                            )),
                    ],
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
        error: (e, _) => Text('Erro', style: AppTextStyles.body()),
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
      error: (e, _) => Text('Erro', style: AppTextStyles.body()),
    );
  }



  Future<void> _configurarRegrasCulto(BuildContext context, WidgetRef ref, AgendaItem? cultoInicial) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
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

    void inicializarQtds(AgendaItem c) {
      qtds.clear();
      for (final min in ministerios) {
        final funcsDoMin = funcoes.where((f) => f.ministerioPai == min.nome).toList();
        for (final f in funcsDoMin) {
          qtds['${min.nome}_${f.nomeFuncao}'] = 0;
        }
      }
      final diaStr = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'][c.diaSemana!];
      final regrasDoCulto = regras.where((r) => r.diaSemana == diaStr && r.horario == c.horario);
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
            title: Text('Configurar Regras do Culto', style: AppTextStyles.heading()),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AgendaItem>(
                    initialValue: cultoSelecionado,
                    isExpanded: true,
                    dropdownColor: context.bgCard,
                    style: AppTextStyles.body(),
                    decoration: const InputDecoration(labelText: 'Culto'),
                    items: cultos
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              '${['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'][c.diaSemana!]} - ${c.horario} (${c.titulo})',
                              overflow: TextOverflow.ellipsis,
                            )))
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
                        final funcsDoMin = funcoes.where((f) => f.ministerioPai == min.nome).toList();
                        if (funcsDoMin.isEmpty) return const SizedBox();

                        return ExpansionTile(
                          title: Text(min.nome, style: AppTextStyles.body(color: AppColors.acento).copyWith(fontWeight: FontWeight.bold)),
                          initiallyExpanded: true,
                          children: funcsDoMin.map((f) {
                            final chave = '${min.nome}_${f.nomeFuncao}';
                            final qtd = qtds[chave] ?? 0;

                            return ListTile(
                              dense: true,
                              title: Text(f.nomeFuncao, style: AppTextStyles.body()),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18, color: AppColors.acento),
                                    onPressed: () => ss(() {
                                      qtds[chave] = (qtd - 1).clamp(0, 10);
                                    }),
                                  ),
                                  Text('$qtd', style: AppTextStyles.mono()),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18, color: AppColors.acento),
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
                  final diaStr = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'][cultoSelecionado.diaSemana!];
                  final regrasAtuais = regras.where((r) =>
                      r.diaSemana == diaStr &&
                      r.horario == cultoSelecionado.horario).toList();

                  for (final min in ministerios) {
                    final funcsDoMin = funcoes.where((f) => f.ministerioPai == min.nome).toList();
                    for (final f in funcsDoMin) {
                      final chave = '${min.nome}_${f.nomeFuncao}';
                      final novaQtd = qtds[chave] ?? 0;
                      
                      final regraExistente = regrasAtuais.cast<Regra?>().firstWhere(
                            (r) => r?.ministerio == min.nome && r?.funcao == f.nomeFuncao,
                            orElse: () => null,
                          );

                      if (novaQtd > 0) {
                        if (regraExistente != null) {
                          if (regraExistente.qtd != novaQtd) {
                            await ref.read(regrasRepoProvider).atualizar(regraExistente.id, {'qtd': novaQtd});
                          }
                        } else {
                          await ref.read(regrasRepoProvider).inserir(Regra(
                            id: '',
                            diaSemana: diaStr,
                            horario: cultoSelecionado.horario,
                            ministerio: min.nome,
                            funcao: f.nomeFuncao,
                            qtd: novaQtd,
                            createdAt: DateTime.now(),
                          ));
                        }
                      } else {
                        if (regraExistente != null) {
                          await ref.read(regrasRepoProvider).excluir(regraExistente.id);
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
    return ListTile(
      dense: true,
      leading: icone != null ? Icon(icone, color: AppColors.acento, size: 20) : null,
      title: Text(titulo, style: AppTextStyles.body()),
      subtitle: subtitulo != null
          ? Text(subtitulo!, style: AppTextStyles.bodySmall())
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(PhosphorIconsBold.pencilSimple,
                  color: AppColors.acento, size: 16),
              onPressed: onEdit,
            ),
          IconButton(
            icon: const Icon(PhosphorIconsBold.trash,
                color: AppColors.perigo, size: 16),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _TemaConfig extends ConsumerWidget {
  const _TemaConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selecione o tema do aplicativo:', style: AppTextStyles.body()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TemaCard(
                  label: 'Escuro',
                  icone: PhosphorIconsBold.moon,
                  selecionado: themeMode == ThemeMode.dark,
                  onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.dark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TemaCard(
                  label: 'Claro',
                  icone: PhosphorIconsBold.sun,
                  selecionado: themeMode == ThemeMode.light,
                  onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.light,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TemaCard(
                  label: 'Sistema',
                  icone: PhosphorIconsBold.desktop,
                  selecionado: themeMode == ThemeMode.system,
                  onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.system,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Personalização da Home:', style: AppTextStyles.body()),
          const SizedBox(height: 12),
          _PreferenciasHomeConfig(),
        ],
      ),
    );
  }
}

class _PreferenciasHomeConfig extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(homePreferencesProvider);
    final notifier = ref.read(homePreferencesProvider.notifier);
    final ministeriosAsync = ref.watch(ministeriosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SwitchItem(
          label: 'Mostrar Agenda da Igreja',
          valor: prefs.mostrarEventos,
          onChanged: (v) => notifier.toggle('eventos', v),
        ),
        _SwitchItem(
          label: 'Mostrar Suas Próximas Escalas',
          valor: prefs.mostrarEscalas,
          onChanged: (v) => notifier.toggle('escalas', v),
        ),
        if (prefs.mostrarEscalas) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text(
              'Filtrar ministérios na Home (deixe vazio para ver todos):',
              style: AppTextStyles.label(color: AppColors.acento),
            ),
          ),
          ministeriosAsync.when(
            data: (mins) => Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: mins.map((m) {
                  final selecionado = prefs.ministeriosVisiveis.contains(m.nome);
                  return FilterChip(
                    label: Text(m.nome, style: AppTextStyles.bodySmall(
                      color: selecionado ? Colors.black : context.textoSecund
                    )),
                    selected: selecionado,
                    onSelected: (_) => notifier.toggleMinisterio(m.nome),
                    selectedColor: AppColors.acento,
                    checkmarkColor: Colors.black,
                    backgroundColor: context.bgBorda.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ),
            loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => const SizedBox(),
          ),
        ],
        _SwitchItem(
          label: 'Mostrar Escala de Jejum',
          valor: prefs.mostrarJejum,
          onChanged: (v) => notifier.toggle('jejum', v),
        ),
        _SwitchItem(
          label: 'Mostrar Relatório de Escalas',
          valor: prefs.mostrarRelatorio,
          onChanged: (v) => notifier.toggle('relatorio', v),
        ),
      ],
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final String label;
  final bool valor;
  final ValueChanged<bool> onChanged;

  const _SwitchItem({required this.label, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label, style: AppTextStyles.bodySmall()),
      value: valor,
      onChanged: onChanged,
      activeThumbColor: AppColors.acento,
      contentPadding: EdgeInsets.zero,
      dense: true,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.acento.withValues(alpha: 0.15)
              : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionado ? AppColors.acento : (Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight),
            width: selecionado ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icone, color: selecionado ? AppColors.acento : context.textoSecund, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall(
                color: selecionado ? AppColors.acento : context.textoSecund,
              ).copyWith(fontWeight: selecionado ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
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
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Nenhum acúmulo pendente ou configurado.',
              style: AppTextStyles.bodySmall(color: AppColors.textoMuted),
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
              Text('Pendentes de Revisão', style: AppTextStyles.label(color: AppColors.acentoAzul)),
              const SizedBox(height: 4),
              ...pendentes.map((c) => _ItemAcumulo(compatibilidade: c)),
              Divider(color: context.bgBorda, height: 24),
            ],
            if (aprovados.isNotEmpty) ...[
              Text('Permitidos', style: AppTextStyles.label(color: AppColors.sucesso)),
              const SizedBox(height: 4),
              ...aprovados.map((c) => _ItemAcumulo(compatibilidade: c)),
              Divider(color: context.bgBorda, height: 24),
            ],
            if (rejeitados.isNotEmpty) ...[
              Text('Bloqueados', style: AppTextStyles.label(color: AppColors.perigo)),
              const SizedBox(height: 4),
              ...rejeitados.map((c) => _ItemAcumulo(compatibilidade: c)),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPendente ? AppColors.acentoAzul : context.bgBorda,
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
                  style: AppTextStyles.label(color: AppColors.acento),
                ),
                Text(
                  '${compatibilidade.funcao1} + ${compatibilidade.funcao2}',
                  style: AppTextStyles.body().copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (isPendente) ...[
            IconButton(
              icon: const Icon(PhosphorIconsBold.checkCircle, color: AppColors.sucesso),
              tooltip: 'Permitir Acúmulo',
              onPressed: () async {
                await ref.read(compatibilidadesRepoProvider).atualizarStatus(compatibilidade.id, 'aprovado');
                ref.invalidate(compatibilidadesProvider);
              },
            ),
            IconButton(
              icon: const Icon(PhosphorIconsBold.prohibit, color: AppColors.perigo),
              tooltip: 'Bloquear Acúmulo',
              onPressed: () async {
                await ref.read(compatibilidadesRepoProvider).atualizarStatus(compatibilidade.id, 'rejeitado');
                ref.invalidate(compatibilidadesProvider);
              },
            ),
          ] else ...[
            TextButton(
              onPressed: () async {
                final novoStatus = compatibilidade.status == 'aprovado' ? 'rejeitado' : 'aprovado';
                await ref.read(compatibilidadesRepoProvider).atualizarStatus(compatibilidade.id, novoStatus);
                ref.invalidate(compatibilidadesProvider);
              },
              child: Text(
                compatibilidade.status == 'aprovado' ? 'Bloquear' : 'Permitir',
                style: TextStyle(
                  color: compatibilidade.status == 'aprovado' ? AppColors.perigo : AppColors.sucesso,
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
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Membros por dia:',
                    style: AppTextStyles.body().copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Quantidade de pessoas escaladas no rodízio diário.',
                    style: AppTextStyles.bodySmall(color: AppColors.textoMuted),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(PhosphorIconsBold.minusCircle, color: AppColors.acento),
                  onPressed: config.qtdMembros <= 1
                      ? null
                      : () async {
                          await ref.read(cfgJejumRepoProvider).atualizar(config.qtdMembros - 1);
                          ref.invalidate(cfgJejumProvider);
                        },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.bgBorda),
                  ),
                  child: Text(
                    '${config.qtdMembros}',
                    style: AppTextStyles.mono().copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsBold.plusCircle, color: AppColors.acento),
                  onPressed: () async {
                    await ref.read(cfgJejumRepoProvider).atualizar(config.qtdMembros + 1);
                    ref.invalidate(cfgJejumProvider);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
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
      children: [
        SwitchListTile(
          title: const Text('Mostrar Escalas'),
          subtitle: const Text('Exibe sua próxima escala no topo'),
          value: prefs.mostrarEscalas,
          activeThumbColor: AppColors.acento,
          onChanged: (v) => ref.read(homePreferencesProvider.notifier).toggle('escalas', v),
        ),
        SwitchListTile(
          title: const Text('Mostrar Agenda'),
          subtitle: const Text('Exibe próximos cultos e eventos'),
          value: prefs.mostrarEventos,
          activeThumbColor: AppColors.acento,
          onChanged: (v) => ref.read(homePreferencesProvider.notifier).toggle('eventos', v),
        ),
        SwitchListTile(
          title: const Text('Mostrar Jejum'),
          subtitle: const Text('Exibe a escala de jejum diário'),
          value: prefs.mostrarJejum,
          activeThumbColor: AppColors.acento,
          onChanged: (v) => ref.read(homePreferencesProvider.notifier).toggle('jejum', v),
        ),
        SwitchListTile(
          title: const Text('Mostrar Relatório'),
          subtitle: const Text('Exibe o ranking do mês'),
          value: prefs.mostrarRelatorio,
          activeThumbColor: AppColors.acento,
          onChanged: (v) => ref.read(homePreferencesProvider.notifier).toggle('relatorio', v),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Filtrar Ministérios na Home', style: AppTextStyles.label(color: AppColors.acento)),
        ),
        Text(
          'Se nenhum estiver selecionado, todos serão exibidos.',
          style: AppTextStyles.bodySmall(color: context.textoSecund),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ministeriosAsync.when(
          data: (lista) => Wrap(
            spacing: 8,
            children: lista.map((m) {
              final selecionado = prefs.ministeriosVisiveis.contains(m.nome);
              return FilterChip(
                label: Text(m.nome),
                selected: selecionado,
                onSelected: (_) => ref.read(homePreferencesProvider.notifier).toggleMinisterio(m.nome),
                selectedColor: AppColors.acento.withValues(alpha: 0.2),
                checkmarkColor: AppColors.acento,
                labelStyle: AppTextStyles.bodySmall(
                  color: selecionado ? AppColors.acento : context.textoSecund,
                ),
              );
            }).toList(),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Erro ao carregar ministérios'),
        ),
      ],
    );
  }
}
