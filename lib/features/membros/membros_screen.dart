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
import 'frequencia_screen.dart';

class MembrosScreen extends ConsumerStatefulWidget {
  const MembrosScreen({super.key});

  @override
  ConsumerState<MembrosScreen> createState() => _MembrosScreenState();
}

class _MembrosScreenState extends ConsumerState<MembrosScreen>
    with SingleTickerProviderStateMixin {
  final _buscaController = TextEditingController();
  late final TabController _tabController;
  int _abaAtual = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_abaAtual != _tabController.index && mounted) {
        setState(() => _abaAtual = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);

    if (role == UserRole.membro) {
      return Scaffold(
        backgroundColor: context.bgPrincipal,
        appBar: AppBar(
          title: Text('Equipe', style: AppTextStyles.heading()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.acentoSuave,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIconsBold.lockKey,
                      size: 30,
                      color: context.corPrimaria,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Área da Liderança',
                    style: AppTextStyles.subheading(
                      color: context.textoPrimario,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O gerenciamento de membros e funções é reservado para líderes.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall(color: context.textoSecund),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final membrosAsync = ref.watch(membrosFiltradosProvider);
    final ministeriosAsync = ref.watch(ministeriosProvider);
    final filtro = ref.watch(membrosMinisterioFiltroProvider);
    final busca = ref.watch(membrosBuscaProvider);

    return Scaffold(
      backgroundColor: context.bgPrincipal,
      appBar: AppBar(
        title: Text('Equipe', style: AppTextStyles.heading()),
        bottom: AppSegmentedTabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Integrantes'),
            Tab(text: 'Faltas e Frequência'),
          ],
        ),
      ),
      floatingActionButton: _abaAtual == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openModal(context, ref, null),
              icon: const Icon(PhosphorIconsBold.userPlus, size: 20),
              label: Text(
                'Novo Membro',
                style: AppTextStyles.button(color: Colors.white),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: () => abrirModalFaltaAvulsa(
                context,
                ref,
                ministerioInicial:
                    ref.read(frequenciaMinisterioFiltroProvider),
              ),
              icon: const Icon(PhosphorIconsBold.calendarX, size: 20),
              label: Text(
                'Falta Avulsa',
                style: AppTextStyles.button(color: Colors.white),
              ),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
          // Busca ampla e limpa
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _buscaController,
              style: AppTextStyles.body(color: context.textoPrimario),
              onChanged: (v) {
                setState(() {});
                ref.read(membrosBuscaProvider.notifier).state = v;
              },
              decoration: InputDecoration(
                hintText: 'Buscar integrante por nome...',
                prefixIcon: Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  color: context.textoSecund,
                  size: 20,
                ),
                suffixIcon: _buscaController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          PhosphorIconsBold.x,
                          color: context.textoSecund,
                          size: 18,
                        ),
                        onPressed: () {
                          _buscaController.clear();
                          setState(() {});
                          ref.read(membrosBuscaProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Filtro por ministério em pílulas Safira
          ministeriosAsync.when(
            data: (mins) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _FiltroChip(
                    label: 'Todos',
                    selecionado: filtro == null,
                    onTap: () => ref
                        .read(membrosMinisterioFiltroProvider.notifier)
                        .state = null,
                  ),
                  ...mins.map(
                    (m) => _FiltroChip(
                      label: m.nome,
                      selecionado: filtro == m.nome,
                      onTap: () => ref
                          .read(membrosMinisterioFiltroProvider.notifier)
                          .state = m.nome,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 44),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Lista de integrantes
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
                          .where(
                            (m) => m.nome
                                .toLowerCase()
                                .contains(busca.toLowerCase()),
                          )
                          .toList();

                  if (filtrada.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.14,
                        ),
                        Icon(
                          PhosphorIconsRegular.usersThree,
                          size: 48,
                          color: context.textoMuted,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Nenhum integrante encontrado.',
                            style: AppTextStyles.body(
                              color: context.textoSecund,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
                    itemCount: filtrada.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _MembroCard(
                      membro: filtrada[i],
                      onEdit: () => _openModal(context, ref, filtrada[i]),
                      onDelete: () async {
                        final ok = await ConfirmDialog.show(
                          context,
                          titulo: 'Excluir integrante',
                          mensagem:
                              'Deseja remover "${filtrada[i].nome}" da equipe?',
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
                  child: CircularProgressIndicator(color: AppColors.acento),
                ),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.16,
                    ),
                    Center(
                      child: Text(
                        'Erro ao carregar integrantes.',
                        style: AppTextStyles.body(color: AppColors.perigo),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.toString(),
                      style: AppTextStyles.bodySmall(
                        color: context.textoSecund,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: AppButton(
                        label: 'Tentar Novamente',
                        onPressed: () => ref.invalidate(membrosProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
          const FrequenciaTabView(),
        ],
      ),
    );
  }

  Future<void> _openModal(
    BuildContext context,
    WidgetRef ref,
    Membro? membro,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selecionado ? AppColors.acento : context.bgCard,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selecionado ? AppColors.acento : context.bgBorda,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.bodySmall(
                color: selecionado ? Colors.white : context.textoSecund,
                fontWeight: selecionado ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
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
    final funcoes = membro.funcoes;

    return AppSurfaceCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(name: membro.nome, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membro.nome,
                  style: AppTextStyles.subheading(
                    color: context.textoPrimario,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (membro.ministerio.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    membro.ministerio,
                    style: AppTextStyles.bodySmall(
                      color: context.textoSecund,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (funcoes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: funcoes
                        .map(
                          (f) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.acentoSuave,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              f,
                              style: AppTextStyles.label(
                                color: context.acentoTexto,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionIconButton(
                icon: PhosphorIconsRegular.pencilSimple,
                color: context.corPrimaria,
                tooltip: 'Editar',
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _ActionIconButton(
                icon: PhosphorIconsRegular.trash,
                color: AppColors.perigo,
                tooltip: 'Excluir',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: context.isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: color, size: 19),
          ),
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
  late TextEditingController _nascimentoCtrl;
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
    'Sábado',
  ];
  final List<String> _tiposEscala = ['Sem restrição', 'Herculano A'];

  @override
  void initState() {
    super.initState();
    final m = widget.membro;
    _nome = TextEditingController(text: m?.nome ?? '');
    _email = TextEditingController(text: m?.email ?? '');
    _nascimento = m?.nascimento;
    _nascimentoCtrl = TextEditingController(
      text: _formatarDataExibicao(_nascimento),
    );
    _ministerio = m?.ministerio.isEmpty == true ? null : m?.ministerio;
    _funcoesSel = List<String>.from(m?.funcoes ?? []);
    _escalaTrab = m?.escalaTrabaho.isEmpty == true
        ? 'Sem restrição'
        : (m?.escalaTrabaho ?? 'Sem restrição');
    _diasIndisp = List<String>.from(m?.diasIndisponiveisList ?? []);
  }

  String _formatarDataExibicao(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _nascimentoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ministeriosAsync = ref.watch(ministeriosProvider);
    final funcoesAsync = _ministerio != null
        ? ref.watch(funcoesDoMinisterioProvider(_ministerio!))
        : const AsyncData<List<Funcao>>([]);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.55,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.bgBorda),
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
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    24 +
                    MediaQuery.of(context).padding.bottom,
              ),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: context.bgBorda,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.membro == null
                            ? 'Novo Integrante'
                            : 'Editar Integrante',
                        style: AppTextStyles.heading(
                          color: context.textoPrimario,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        PhosphorIconsBold.x,
                        color: context.textoSecund,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: 'Nome completo *',
                  controller: _nome,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 14),

                AppTextField(
                  label: 'E-mail',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                AppTextField(
                  label: 'Data de nascimento',
                  readOnly: true,
                  controller: _nascimentoCtrl,
                  hint: 'Selecionar data',
                  onTap: () async {
                    final inicial = (_nascimento != null &&
                            DateTime.tryParse(_nascimento!) != null)
                        ? DateTime.parse(_nascimento!)
                        : DateTime(2000);
                    final d = await showDatePicker(
                      context: context,
                      initialDate: inicial,
                      firstDate: DateTime(1930),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      setState(() {
                        _nascimento = DateFormat('yyyy-MM-dd').format(d);
                        _nascimentoCtrl.text =
                            DateFormat('dd/MM/yyyy').format(d);
                      });
                    }
                  },
                  suffixIcon: Icon(
                    PhosphorIconsRegular.cake,
                    color: context.corPrimaria,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 14),

                ministeriosAsync.when(
                  data: (mins) {
                    final items = [...mins];
                    if (_ministerio != null &&
                        !items.any((m) => m.nome == _ministerio)) {
                      items.add(Ministerio(nome: _ministerio!));
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _ministerio,
                      style: AppTextStyles.body(color: context.textoPrimario),
                      dropdownColor: context.bgCard,
                      decoration:
                          const InputDecoration(labelText: 'Ministério *'),
                      items: items
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.nome,
                              child: Text(m.nome),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _ministerio = v;
                        _funcoesSel = [];
                      }),
                      validator: (v) => v == null ? 'Selecione' : null,
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: AppColors.acento),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                if (_ministerio != null) ...[
                  Text(
                    'Funções no ministério',
                    style: AppTextStyles.bodySmall(
                      color: context.textoPrimario,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  funcoesAsync.when(
                    data: (funcs) => funcs.isEmpty
                        ? Text(
                            'Nenhuma função cadastrada neste ministério.',
                            style: AppTextStyles.bodySmall(
                              color: context.textoSecund,
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: funcs.map((f) {
                              final sel = _funcoesSel.contains(f.nomeFuncao);
                              return FilterChip(
                                label: Text(
                                  f.nomeFuncao,
                                  style: AppTextStyles.bodySmall(
                                    color: sel
                                        ? Colors.white
                                        : context.textoPrimario,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                selected: sel,
                                selectedColor: AppColors.acento,
                                backgroundColor: context.bgSubtle,
                                checkmarkColor: Colors.white,
                                side: BorderSide(
                                  color: sel
                                      ? AppColors.acento
                                      : context.bgBorda,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (v) => setState(() {
                                  if (v) {
                                    _funcoesSel.add(f.nomeFuncao);
                                  } else {
                                    _funcoesSel.remove(f.nomeFuncao);
                                  }
                                }),
                              );
                            }).toList(),
                          ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: AppColors.acento),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 18),
                ],

                DropdownButtonFormField<String>(
                  initialValue: _escalaTrab,
                  style: AppTextStyles.body(color: context.textoPrimario),
                  dropdownColor: context.bgCard,
                  decoration:
                      const InputDecoration(labelText: 'Escala de Trabalho'),
                  items: _tiposEscala
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _escalaTrab = v!),
                ),
                const SizedBox(height: 18),

                Text(
                  'Dias indisponíveis na semana',
                  style: AppTextStyles.bodySmall(
                    color: context.textoPrimario,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _diasSemana.map((d) {
                    final sel = _diasIndisp.contains(d);
                    return FilterChip(
                      label: Text(
                        d,
                        style: AppTextStyles.bodySmall(
                          color: sel ? Colors.white : context.textoPrimario,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: sel,
                      selectedColor: AppColors.perigo,
                      backgroundColor: context.bgSubtle,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: sel ? AppColors.perigo : context.bgBorda,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _diasIndisp.add(d);
                        } else {
                          _diasIndisp.remove(d);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                AppButton(
                  label: 'Salvar Integrante',
                  icon: PhosphorIconsBold.check,
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
