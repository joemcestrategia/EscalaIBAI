import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/membro.dart';
import '../../core/models/funcao.dart';
import '../../core/models/ministerio.dart';
import '../../shared/widgets/app_widgets.dart';

class MembrosScreen extends ConsumerStatefulWidget {
  const MembrosScreen({super.key});

  @override
  ConsumerState<MembrosScreen> createState() => _MembrosScreenState();
}

class _MembrosScreenState extends ConsumerState<MembrosScreen> {
  final _buscaController = TextEditingController();

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    
    if (role == UserRole.membro) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Membros', style: AppTextStyles.heading()),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsBold.lockKey, size: 64, color: AppColors.acento),
              const SizedBox(height: 16),
              Text(
                'Acesso Restrito',
                style: AppTextStyles.subheading(color: context.textoPrimario),
              ),
              const SizedBox(height: 8),
              Text(
                'Esta área é reservada para Líderes.',
                style: AppTextStyles.bodySmall(color: context.textoSecund),
              ),
            ],
          ),
        ),
      );
    }

    final membrosAsync = ref.watch(membrosFiltradosProvider);
    final ministeriosAsync = ref.watch(ministeriosProvider);
    final filtro = ref.watch(membrosMinisterioFiltroProvider);
    final busca = ref.watch(membrosBuscaProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Membros', style: AppTextStyles.heading()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openModal(context, ref, null),
        child: const Icon(PhosphorIconsBold.plus),
      ),
      body: Column(
        children: [
          // Busca
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _buscaController,
              style: AppTextStyles.body(),
              onChanged: (v) =>
                  ref.read(membrosBuscaProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Buscar por nome...',
                prefixIcon: Icon(PhosphorIconsBold.magnifyingGlass,
                    color: context.textoSecund, size: 18),
                suffixIcon: _buscaController.text.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.clear, color: context.textoSecund, size: 18),
                      onPressed: () {
                        _buscaController.clear();
                        ref.read(membrosBuscaProvider.notifier).state = '';
                      },
                    )
                  : null,
              ),
            ),
          ),
          // Filtro por ministério
          ministeriosAsync.when(
            data: (mins) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _FiltroChip(
                    label: 'Todos',
                    selecionado: filtro == null,
                    onTap: () => ref
                        .read(membrosMinisterioFiltroProvider.notifier)
                        .state = null,
                  ),
                  ...mins.map((m) => _FiltroChip(
                        label: m.nome,
                        selecionado: filtro == m.nome,
                        onTap: () => ref
                            .read(membrosMinisterioFiltroProvider.notifier)
                            .state = m.nome,
                      )),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 40),
            error: (_, __) => const SizedBox(),
          ),
          // Lista
          Expanded(
            child: RefreshIndicator(
              color: AppColors.acento,
              backgroundColor: context.bgCard,
              onRefresh: () async {
                ref.invalidate(membrosProvider);
                await ref.read(membrosProvider.future);
              },
              child: membrosAsync.when(
                data: (lista) {
                  final filtrada = busca.isEmpty
                      ? lista
                      : lista
                          .where((m) =>
                              m.nome.toLowerCase().contains(busca.toLowerCase()))
                          .toList();

                  if (filtrada.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Text('Nenhum membro encontrado.',
                              style:
                                  AppTextStyles.body(color: context.textoSecund)),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: filtrada.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _MembroCard(
                      membro: filtrada[i],
                      onEdit: () => _openModal(context, ref, filtrada[i]),
                      onDelete: () async {
                        final ok = await ConfirmDialog.show(
                          context,
                          titulo: 'Excluir',
                          mensagem: 'Excluir o membro "${filtrada[i].nome}"?',
                          labelConfirmar: 'Excluir',
                          perigo: true,
                        );
                        if (ok) {
                          await ref
                              .read(membrosRepoProvider)
                              .excluir(filtrada[i].id);
                          ref.invalidate(membrosProvider);
                        }
                      },
                    ),
                  );
                },
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.acento)),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                    Center(child: Text('Erro ao carregar membros.', style: AppTextStyles.body(color: AppColors.perigo))),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(e.toString(), style: AppTextStyles.bodySmall(color: context.textoSecund), textAlign: TextAlign.center),
                    ),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => ref.invalidate(membrosProvider),
                        child: const Text('Tentar Novamente'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openModal(
      BuildContext context, WidgetRef ref, Membro? membro) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ModalMembro(membro: membro),
    );
    ref.invalidate(membrosProvider);
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.acento.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado ? AppColors.acento : (Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label(
              color: selecionado ? AppColors.acento : context.textoSecund),
        ),
      ),
    );
  }
}

class _MembroCard extends StatelessWidget {
  final Membro membro;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MembroCard({
    required this.membro,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.acento.withValues(alpha: 0.15),
          child: Text(
            membro.nome.isNotEmpty ? membro.nome[0].toUpperCase() : '?',
            style: AppTextStyles.subheading(color: AppColors.acento),
          ),
        ),
        title: Text(membro.nome, style: AppTextStyles.body()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(membro.ministerio, style: AppTextStyles.bodySmall()),
            if (membro.funcao.isNotEmpty)
              Text(membro.funcao,
                  style: AppTextStyles.bodySmall(color: AppColors.acento)),
          ],
        ),
        isThreeLine: membro.funcao.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(PhosphorIconsBold.pencil,
                  color: AppColors.acentoAzul, size: 18),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(PhosphorIconsBold.trash,
                  color: AppColors.perigo, size: 18),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Modal Membro ─────────────────────────────────────────────────────────────
class ModalMembro extends ConsumerStatefulWidget {
  final Membro? membro;
  const ModalMembro({super.key, this.membro});

  @override
  ConsumerState<ModalMembro> createState() => _ModalMembroState();
}

class _ModalMembroState extends ConsumerState<ModalMembro> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nome;
  late TextEditingController _email;
  String? _nascimento;
  String? _ministerio;
  List<String> _funcoesSel = [];
  String _escalaTrab = 'Sem restrição';
  List<String> _diasIndisp = [];
  bool _loading = false;

  final List<String> _diasSemana = [
    'Domingo',
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado'
  ];
  final List<String> _tiposEscala = ['Sem restrição', 'Herculano A'];

  @override
  void initState() {
    super.initState();
    final m = widget.membro;
    _nome = TextEditingController(text: m?.nome ?? '');
    _email = TextEditingController(text: m?.email ?? '');
    _nascimento = m?.nascimento;
    _ministerio = m?.ministerio.isEmpty == true ? null : m?.ministerio;
    _funcoesSel = m?.funcoes ?? [];
    _escalaTrab = m?.escalaTrabaho.isEmpty == true
        ? 'Sem restrição'
        : (m?.escalaTrabaho ?? 'Sem restrição');
    _diasIndisp = m?.diasIndisponiveisList ?? [];
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ministeriosAsync = ref.watch(ministeriosProvider);
    final funcoesAsync = _ministerio != null
        ? ref.watch(funcoesDoMinisterioProvider(_ministerio!))
        : const AsyncData<List<Funcao>>([]);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: LoadingOverlay(
          loading: _loading,
          mensagem: 'Salvando...',
          child: Form(
            key: _formKey,
            child: ListView(
              controller: ctrl,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? context.bgBorda : AppColors.bgBordaLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  widget.membro == null ? 'Novo Membro' : 'Editar Membro',
                  style: AppTextStyles.heading(),
                ),
                const SizedBox(height: 20),

                AppTextField(
                  label: 'Nome *',
                  controller: _nome,
                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),

                AppTextField(
                  label: 'E-mail',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),

                AppTextField(
                  label: 'Nascimento',
                  readOnly: true,
                  controller: TextEditingController(text: _nascimento ?? ''),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _nascimento != null
                          ? DateTime.parse(_nascimento!)
                          : DateTime(2000),
                      firstDate: DateTime(1930),
                      lastDate: DateTime.now(),
                      builder: (c, w) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme:
                              const ColorScheme.dark(primary: AppColors.acento),
                        ),
                        child: w!,
                      ),
                    );
                    if (d != null) {
                      setState(() =>
                          _nascimento = DateFormat('yyyy-MM-dd').format(d));
                    }
                  },
                  suffixIcon:
                      const Icon(Icons.cake, color: AppColors.acento, size: 18),
                ),
                const SizedBox(height: 12),

                ministeriosAsync.when(
                  data: (mins) {
                    final items = [...mins];
                    if (_ministerio != null && !items.any((m) => m.nome == _ministerio)) {
                      items.add(Ministerio(nome: _ministerio!));
                    }
                    
                    return DropdownButtonFormField<String>(
                      value: _ministerio,
                      style: AppTextStyles.body(),
                      dropdownColor: context.bgCard,
                      decoration:
                          const InputDecoration(labelText: 'Ministério *'),
                      items: items
                          .map((m) => DropdownMenuItem(value: m.nome, child: Text(m.nome)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _ministerio = v;
                        _funcoesSel = [];
                      }),
                      validator: (v) => v == null ? 'Selecione' : null,
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 12),

                if (_ministerio != null) ...[
                  Text('Funções *', style: AppTextStyles.label()),
                  funcoesAsync.when(
                    data: (funcs) => Column(
                      children: funcs
                          .map((f) => CheckboxListTile(
                                dense: true,
                                value: _funcoesSel.contains(f.nomeFuncao),
                                activeColor: AppColors.acento,
                                title: Text(f.nomeFuncao,
                                    style: AppTextStyles.body()),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _funcoesSel.add(f.nomeFuncao);
                                  } else {
                                    _funcoesSel.remove(f.nomeFuncao);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                  const SizedBox(height: 12),
                ],

                DropdownButtonFormField<String>(
                  value: _escalaTrab,
                  style: AppTextStyles.body(),
                  dropdownColor: context.bgCard,
                  decoration:
                      const InputDecoration(labelText: 'Escala de Trabalho'),
                  items: _tiposEscala
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _escalaTrab = v!),
                ),
                const SizedBox(height: 12),

                Text('Dias Indisponíveis', style: AppTextStyles.label()),
                Column(
                  children: _diasSemana
                      .map((d) => CheckboxListTile(
                            dense: true,
                            value: _diasIndisp.contains(d),
                            activeColor: AppColors.acento,
                            title: Text(d, style: AppTextStyles.body()),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _diasIndisp.add(d);
                              } else {
                                _diasIndisp.remove(d);
                              }
                            }),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),

                AppButton(
                  label: 'Salvar',
                  loading: _loading,
                  onPressed: _salvar,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    try {
      final dados = {
        'nome': _nome.text.trim(),
        'email': _email.text.trim(),
        'nascimento': _nascimento,
        'ministerio': _ministerio ?? '',
        'funcao': _funcoesSel.join(', '),
        'escala_trabalho': _escalaTrab,
        'dias_indisponiveis': _diasIndisp.join(', '),
      };
      if (widget.membro == null) {
        await ref.read(membrosRepoProvider).inserir(dados);
      } else {
        await ref.read(membrosRepoProvider).atualizar(widget.membro!.id, dados);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}