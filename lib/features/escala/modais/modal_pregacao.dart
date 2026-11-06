import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/models/escala_item.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_widgets.dart';

class ModalPregacao extends ConsumerStatefulWidget {
  final EscalaItem item;
  const ModalPregacao({super.key, required this.item});

  @override
  ConsumerState<ModalPregacao> createState() => _ModalPregacaoState();
}

class _ModalPregacaoState extends ConsumerState<ModalPregacao> {
  late TextEditingController _tituloCtrl;
  late TextEditingController _textoCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tituloCtrl = TextEditingController(text: widget.item.tituloMensagem);
    _textoCtrl = TextEditingController(text: widget.item.textoBiblico);
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _textoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Pregação', style: AppTextStyles.heading()),
              Text('Pregador: ${widget.item.nome}',
                  style: AppTextStyles.body(color: context.textoSecund)),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Título da Mensagem',
                controller: _tituloCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Texto Bíblico',
                controller: _textoCtrl,
                maxLines: 3,
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
    );
  }

  Future<void> _salvar() async {
    setState(() => _loading = true);
    try {
      await ref.read(escalaRepoProvider).atualizar(widget.item.id, {
        'titulo_mensagem': _tituloCtrl.text.trim(),
        'texto_biblico': _textoCtrl.text.trim(),
      });
      if (mounted) {
        AppSnackbar.show(context, 'Pregação salva!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Erro: $e', erro: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
