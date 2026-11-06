import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/models/escala_item.dart';
import '../../../core/models/membro.dart';
import '../../../shared/widgets/app_widgets.dart';

class ModalEditEscala extends ConsumerStatefulWidget {
  final EscalaItem item;

  const ModalEditEscala({super.key, required this.item});

  @override
  ConsumerState<ModalEditEscala> createState() => _ModalEditEscalaState();
}

class _ModalEditEscalaState extends ConsumerState<ModalEditEscala> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _data;
  late String _ministerio;
  late String _membro;
  late String _funcao;
  late List<String> _funcoesSel;
  late final TextEditingController _temaCtrl;
  late TimeOfDay _hora;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _data = DateTime.tryParse(widget.item.data) ?? DateTime.now();
    _ministerio = widget.item.ministerio;
    _membro = widget.item.nome;
    _funcao = widget.item.funcao;
    _funcoesSel = widget.item.funcao
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    _temaCtrl = TextEditingController(text: widget.item.tema);

    final hParts = widget.item.horario.split(':');
    if (hParts.length >= 2) {
      _hora =
          TimeOfDay(hour: int.parse(hParts[0]), minute: int.parse(hParts[1]));
    } else {
      _hora = const TimeOfDay(hour: 0, minute: 0);
    }
  }

  @override
  void dispose() {
    _temaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ministeriosAsync = ref.watch(ministeriosProvider);
    final membrosAsync = ref.watch(membrosProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
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
          mensagem: 'Atualizando...',
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
                Text('Editar Escala', style: AppTextStyles.heading()),
                const SizedBox(height: 20),

                // Data e Hora
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        label: 'Data',
                        readOnly: true,
                        controller: TextEditingController(
                            text: DateFormat('dd/MM/yyyy').format(_data)),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _data,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                            builder: (c, w) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                    primary: AppColors.acento),
                              ),
                              child: w!,
                            ),
                          );
                          if (d != null) setState(() => _data = d);
                        },
                        suffixIcon: const Icon(Icons.calendar_today,
                            color: AppColors.acento, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'Horário',
                        readOnly: true,
                        controller:
                            TextEditingController(text: _hora.format(context)),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _hora,
                            builder: (c, w) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                    primary: AppColors.acento),
                              ),
                              child: w!,
                            ),
                          );
                          if (t != null) setState(() => _hora = t);
                        },
                        suffixIcon: const Icon(Icons.access_time,
                            color: AppColors.acento, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Ministério
                ministeriosAsync.when(
                  data: (mins) {
                    final items = mins.map((m) => m.nome).toList();
                    if (!items.contains(_ministerio)) items.add(_ministerio);

                    return DropdownButtonFormField<String>(
                      initialValue: _ministerio,
                      style: AppTextStyles.body(),
                      dropdownColor: context.bgCard,
                      decoration:
                          const InputDecoration(labelText: 'Ministério'),
                      items: items
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _ministerio = v!;
                      }),
                      validator: (v) => v == null ? 'Selecione' : null,
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 12),

                // Membro
                membrosAsync.when(
                  data: (lista) {
                    final filtrada = lista
                        .where((m) => m.ministerio == _ministerio)
                        .toList();
                    // Garante que o membro atual continue selecionável mesmo se o filtro ocultá-lo
                    final membrosNomes = filtrada.map((e) => e.nome).toList();
                    if (!membrosNomes.contains(_membro) && _membro.isNotEmpty) {
                      membrosNomes.add(_membro);
                    }
                    if (!membrosNomes.contains('[FALTA]')) {
                      membrosNomes.add('[FALTA]');
                    }

                    return DropdownButtonFormField<String>(
                      initialValue:
                          membrosNomes.contains(_membro) ? _membro : null,
                      style: AppTextStyles.body(),
                      dropdownColor: context.bgCard,
                      decoration: const InputDecoration(labelText: 'Membro'),
                      items: membrosNomes
                          .map(
                              (n) => DropdownMenuItem(value: n, child: Text(n)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _membro = v!;
                        _funcoesSel = [];
                        _funcao = '';
                      }),
                      validator: (v) => v == null ? 'Selecione' : null,
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 12),

                // Funções
                if (_membro.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Funções *', style: AppTextStyles.label(color: AppColors.acento)),
                  const SizedBox(height: 8),
                  membrosAsync.when(
                    data: (listaMembros) {
                      final membroObj = listaMembros.firstWhere(
                        (m) => m.nome == _membro,
                        orElse: () => Membro(id: '', nome: '', ministerio: '', funcao: '', diasIndisponiveis: '', escalaTrabaho: '', email: '', createdAt: DateTime.now()),
                      );

                      return ref.watch(funcoesDoMinisterioProvider(_ministerio)).when(
                        data: (funcoesMin) {
                          final funcsMinNomes = funcoesMin.map((f) => f.nomeFuncao).toList();
                          
                          List<String> funcsDisponiveis = [];
                          if (_membro == '[FALTA]') {
                            funcsDisponiveis = funcsMinNomes;
                          } else {
                            funcsDisponiveis = membroObj.funcoes;
                            if (funcsDisponiveis.isEmpty) {
                              funcsDisponiveis = funcsMinNomes;
                            }
                          }

                          if (funcsDisponiveis.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Nenhuma função disponível para este ministério/membro.', 
                                  style: AppTextStyles.bodySmall(color: context.textoSecund)),
                            );
                          }

                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: funcsDisponiveis.map((f) {
                              final selecionada = _funcoesSel.contains(f);
                              return FilterChip(
                                label: Text(f, style: AppTextStyles.bodySmall(
                                  color: selecionada ? Colors.black : context.textoPrimario
                                )),
                                selected: selecionada,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _funcoesSel.add(f);
                                    } else {
                                      _funcoesSel.remove(f);
                                    }
                                    _funcao = _funcoesSel.join(', ');
                                  });
                                },
                                selectedColor: AppColors.acento,
                                backgroundColor: context.bgBorda.withValues(alpha: 0.3),
                                checkmarkColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: selecionada ? AppColors.acento : context.bgBorda,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const SizedBox(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
                const SizedBox(height: 12),

                // Tema
                AppTextField(
                  label: 'Tema do Culto',
                  controller: _temaCtrl,
                ),
                const SizedBox(height: 24),

                AppButton(
                  label: 'Salvar Alterações',
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

      final horaStr =
          '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';

      await ref.read(escalaRepoProvider).atualizar(widget.item.id, {
        'data': _data.toIso8601String().split('T')[0],
        'dia_semana': diaNome,
        'horario': horaStr,
        'ministerio': _ministerio,
        'nome': _membro,
        'funcao': _funcao,
        'tema': _temaCtrl.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
