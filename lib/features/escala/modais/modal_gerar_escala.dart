import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_widgets.dart';

class ModalGerarEscala extends ConsumerStatefulWidget {
  const ModalGerarEscala({super.key});

  @override
  ConsumerState<ModalGerarEscala> createState() => _ModalGerarEscalaState();
}

class _ModalGerarEscalaState extends ConsumerState<ModalGerarEscala> {
  int _mes = DateTime.now().month;
  int _ano = DateTime.now().year;
  String? _ministerioAlvo;
  bool _loading = false;
  bool _gerarJejum = true;

  @override
  Widget build(BuildContext context) {
    final ministeriosAsync = ref.watch(ministeriosProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: LoadingOverlay(
        loading: _loading,
        mensagem: 'Gerando escala automática...',
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text('Gerar Escala Automática', style: AppTextStyles.heading()),
              const SizedBox(height: 8),
              Text(
                'Irá limpar a escala do mês selecionado e gerar automaticamente com base nas regras.',
                style: AppTextStyles.body(color: context.textoSecund),
              ),
              const SizedBox(height: 20),

              // Mês e ano
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _mes,
                    style: AppTextStyles.body(color: context.textoPrimario),
                    dropdownColor: context.bgCard,
                    decoration: const InputDecoration(labelText: 'Mês'),
                    items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text([
                                'Jan',
                                'Fev',
                                'Mar',
                                'Abr',
                                'Mai',
                                'Jun',
                                'Jul',
                                'Ago',
                                'Set',
                                'Out',
                                'Nov',
                                'Dez'
                              ][i]),
                            )),
                    onChanged: (v) => setState(() => _mes = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _ano,
                    style: AppTextStyles.body(color: context.textoPrimario),
                    dropdownColor: context.bgCard,
                    decoration: const InputDecoration(labelText: 'Ano'),
                    items: List.generate(
                        5,
                        (i) => DropdownMenuItem(
                              value: DateTime.now().year + i - 1,
                              child: Text('${DateTime.now().year + i - 1}'),
                            )),
                    onChanged: (v) => setState(() => _ano = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Ministério (opcional)
              ministeriosAsync.when(
                data: (mins) => DropdownButtonFormField<String>(
                  initialValue: _ministerioAlvo,
                  style: AppTextStyles.body(color: context.textoPrimario),
                  dropdownColor: context.bgCard,
                  decoration: const InputDecoration(
                      labelText: 'Ministério (opcional — todos se vazio)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...mins
                        .map((m) => DropdownMenuItem(value: m.nome, child: Text(m.nome))),
                  ],
                  onChanged: (v) => setState(() => _ministerioAlvo = v),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.perigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.perigo.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber,
                      color: AppColors.perigo, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta ação irá sobrescrever a escala existente do mês.',
                      style: AppTextStyles.bodySmall(color: AppColors.perigo),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text('Gerar Escala de Jejum', style: AppTextStyles.body()),
                subtitle: Text(
                  'Escala diária de jejum para os membros.',
                  style: AppTextStyles.bodySmall(color: context.textoSecund),
                ),
                activeThumbColor: AppColors.acento,
                value: _gerarJejum,
                onChanged: (v) => setState(() => _gerarJejum = v),
              ),
              const SizedBox(height: 20),

              AppButton(
                label: 'Gerar Escala',
                loading: _loading,
                onPressed: _gerar,
                width: double.infinity,
                icon: Icons.auto_awesome,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _gerar() async {
    setState(() => _loading = true);
    try {
      // Pré-verificação de pendências de acúmulo
      final membros = await ref.read(membrosProvider.future);
      final compatibilidades = await ref.read(compatibilidadesProvider.future);
      bool temPendencias = false;

      for (final m in membros) {
        if (m.funcoes.length > 1 && m.ministerio.isNotEmpty) {
          for (int i = 0; i < m.funcoes.length; i++) {
            for (int j = i + 1; j < m.funcoes.length; j++) {
              final pair = [m.funcoes[i].trim(), m.funcoes[j].trim()]..sort();
              final f1 = pair[0];
              final f2 = pair[1];

              final comp = compatibilidades.where(
                (c) => c.ministerio == m.ministerio && c.funcao1 == f1 && c.funcao2 == f2
              ).firstOrNull;

              if (comp == null || comp.status == 'pendente') {
                temPendencias = true;
                if (comp == null) {
                  await ref.read(compatibilidadesRepoProvider).inserirComStatus(
                    ministerio: m.ministerio,
                    funcao1: f1,
                    funcao2: f2,
                    status: 'pendente',
                  );
                }
              }
            }
          }
        }
      }

      if (temPendencias) {
        setState(() => _loading = false);
        ref.invalidate(compatibilidadesProvider);
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: context.bgCard,
              title: Text('Pendências de Acúmulo', style: AppTextStyles.heading(color: AppColors.perigo)),
              content: Text(
                'Existem membros com múltiplas funções sem regra de acúmulo definida.\n\nPara evitar erros na geração da escala, por favor vá em Configurações > Revisar Acúmulos de Função e resolva as pendências antes de continuar.',
                style: AppTextStyles.body(),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final regras = await ref.read(regrasProvider.future);
      if (regras.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: context.bgCard,
              title: Text('Nenhuma Regra Encontrada', style: AppTextStyles.heading(color: AppColors.perigo)),
              content: Text(
                'Você precisa cadastrar regras de escala antes de gerar a escala automática.\n\nVá em Configurações > Regras de Escala.',
                style: AppTextStyles.body(),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      final temEscala = await ref.read(escalaRepoProvider).temEscalaRegistrada(
            ano: _ano,
            mes: _mes,
            ministerio: _ministerioAlvo,
          );
      
      setState(() => _loading = false);
      
      if (!mounted) return;
      
      final ok = await ConfirmDialog.show(
        context,
        titulo: temEscala ? 'Sobrescrever Escala?' : 'Confirmar Geração',
        mensagem: temEscala
            ? 'Já existe escala cadastrada para $_mes/$_ano${_ministerioAlvo != null ? " no ministério $_ministerioAlvo" : ""}. Deseja sobrescrever?'
            : 'Gerar escala automática para $_mes/$_ano?',
        labelConfirmar: temEscala ? 'Sobrescrever' : 'Gerar',
        perigo: temEscala,
      );
      if (!ok) return;

      setState(() => _loading = true);
      await ref.read(escalaRepoProvider).gerarEscalaAuto(
            mes: _mes,
            ano: _ano,
            alvoMinisterio: _ministerioAlvo,
            gerarJejum: _gerarJejum,
          );
      if (mounted) {
        AppSnackbar.show(context, 'Escala gerada com sucesso!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
