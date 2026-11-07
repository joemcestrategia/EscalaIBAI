import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_widgets.dart';

class ModalAddEscala extends ConsumerStatefulWidget {
  final DateTime? initialData;
  final String? initialHorario;
  final String? initialTema;
  
  const ModalAddEscala({
    super.key, 
    this.initialData, 
    this.initialHorario,
    this.initialTema,
  });

  @override
  ConsumerState<ModalAddEscala> createState() => _ModalAddEscalaState();
}

class _ModalAddEscalaState extends ConsumerState<ModalAddEscala> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _data;
  late String _horario;
  String? _ministerio;
  String? _membro;
  List<String> _funcoesSel = [];
  late TextEditingController _temaController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData ?? DateTime.now();
    _horario = widget.initialHorario ?? '19:30';
    _temaController = TextEditingController(text: widget.initialTema ?? '');
  }

  @override
  void dispose() {
    _temaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ministeriosAsync = ref.watch(ministeriosProvider);
    final membrosAsync = ref.watch(membrosProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: context.bgCard,
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
                      color: context.bgBorda,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Adicionar à Escala', style: AppTextStyles.heading()),
                const SizedBox(height: 20),

                if (widget.initialHorario == null) ...[
                  // Data
                  AppTextField(
                    label: 'Data',
                    readOnly: true,
                    controller: TextEditingController(
                        text: DateFormat('dd/MM/yyyy').format(_data)),
                    onTap: widget.initialData != null ? null : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _data,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                        builder: (c, w) => Theme(
                          data: Theme.of(context),
                          child: w!,
                        ),
                      );
                      if (d != null) setState(() => _data = d);
                    },
                    suffixIcon: widget.initialData != null ? null : const Icon(Icons.calendar_today,
                        color: AppColors.acento, size: 18),
                  ),
                  const SizedBox(height: 12),

                  // Horário
                  AppTextField(
                    label: 'Horário',
                    controller: TextEditingController(text: _horario),
                    readOnly: widget.initialHorario != null,
                    onTap: widget.initialHorario != null ? null : () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(_horario.split(':')[0]),
                          minute: int.parse(_horario.split(':')[1]),
                        ),
                      );
                      if (t != null) {
                        setState(() => _horario = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                      }
                    },
                    suffixIcon: widget.initialHorario != null ? null : const Icon(Icons.access_time,
                        color: AppColors.acento, size: 18),
                  ),
                  const SizedBox(height: 12),
                ],

                // Ministério
                ministeriosAsync.when(
                  data: (mins) => DropdownButtonFormField<String>(
                    initialValue: _ministerio,
                    style: AppTextStyles.body(),
                    dropdownColor: context.bgCard,
                    decoration: const InputDecoration(labelText: 'Ministério'),
                    items: mins
                        .map((m) => DropdownMenuItem(value: m.nome, child: Text(m.nome)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _ministerio = v;
                      _membro = null;
                      _funcoesSel = [];
                    }),
                    validator: (v) => v == null ? 'Selecione' : null,
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 12),

                // Membro
                membrosAsync.when(
                  data: (lista) {
                    final filtrada = _ministerio != null
                        ? lista
                            .where((m) => m.ministerio == _ministerio)
                            .toList()
                        : lista;
                    return DropdownButtonFormField<String>(
                      initialValue: _membro,
                      style: AppTextStyles.body(),
                      dropdownColor: context.bgCard,
                      decoration: const InputDecoration(labelText: 'Membro'),
                      items: filtrada
                          .map((m) => DropdownMenuItem(
                              value: m.nome, child: Text(m.nome)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _membro = v;
                        _funcoesSel = [];
                      }),
                      validator: (v) => v == null ? 'Selecione' : null,
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                ),
                
                // Funções (Dinâmico)
                if (_membro != null) ...[
                  const SizedBox(height: 16),
                  Text('Funções do Membro *', style: AppTextStyles.label(color: AppColors.acento)),
                  const SizedBox(height: 8),
                  membrosAsync.when(
                    data: (lista) {
                      final membroObj = lista.firstWhere((m) => m.nome == _membro);
                      final funcs = membroObj.funcoes;
                      if (funcs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Nenhuma função cadastrada para este membro.', 
                              style: AppTextStyles.bodySmall(color: context.textoSecund)),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: funcs.map((f) {
                          final selecionada = _funcoesSel.contains(f);
                          return FilterChip(
                            label: Text(
                              f,
                              style: AppTextStyles.bodySmall(
                                color: selecionada
                                    ? Colors.white
                                    : context.textoPrimario,
                                fontWeight: selecionada
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            selected: selecionada,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _funcoesSel.add(f);
                                } else {
                                  _funcoesSel.remove(f);
                                }
                              });
                            },
                            selectedColor: AppColors.acento,
                            backgroundColor: context.bgSubtle,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: selecionada
                                    ? AppColors.acento
                                    : context.bgBorda,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
                const SizedBox(height: 12),

                if (widget.initialHorario == null) ...[
                  // Tema
                  AppTextField(
                    label: 'Tema do Culto',
                    controller: _temaController,
                  ),
                  const SizedBox(height: 24),
                ],

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
    if (_funcoesSel.isEmpty) {
      AppSnackbar.show(context, 'Selecione ao menos uma função.', erro: true);
      return;
    }
    
    setState(() => _loading = true);
    try {
      final diaNome = [
        'Domingo',
        'Segunda',
        'Terça',
        'Quarta',
        'Quinta',
        'Sexta',
        'Sábado'
      ][_data.weekday % 7];
      
      final horaFormatada = _horario.contains(':') 
          ? (_horario.split(':').length == 2 ? '$_horario:00' : _horario)
          : '$_horario:00:00';

      await ref.read(escalaRepoProvider).inserir({
        'data': _data.toIso8601String().split('T')[0],
        'dia_semana': diaNome,
        'horario': horaFormatada,
        'ministerio': _ministerio ?? '',
        'nome': _membro ?? '',
        'funcao': _funcoesSel.join(', '),
        'tema': _temaController.text.trim(),
        'status_convite': '',
      });
      
      ref.invalidate(escalaDoMesProvider);
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
