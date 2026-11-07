import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_widgets.dart';
import 'quem_sou_eu_screen.dart';

class RoleSelectionScreen extends ConsumerWidget {
  final VoidCallback onRoleSelected;

  const RoleSelectionScreen({
    super.key,
    required this.onRoleSelected,
  });

  Future<bool?> _mostrarDialogSenhaLider(BuildContext context) {
    final senhaController = TextEditingController();
    bool obscure = true;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ctx.acentoSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  PhosphorIconsBold.shieldCheck,
                  color: ctx.acentoTexto,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Acesso do Líder',
                  style: AppTextStyles.heading(color: ctx.textoPrimario),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digite a senha administrativa para liberar a gestão de escalas e membros.',
                style: AppTextStyles.bodySmall(color: ctx.textoSecund),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: senhaController,
                obscureText: obscure,
                autofocus: true,
                style: AppTextStyles.body(color: ctx.textoPrimario),
                decoration: InputDecoration(
                  hintText: 'Senha do Líder',
                  prefixIcon: Icon(
                    PhosphorIconsRegular.lockKey,
                    color: ctx.textoSecund,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? PhosphorIconsRegular.eye
                          : PhosphorIconsRegular.eyeSlash,
                      color: ctx.textoSecund,
                    ),
                    onPressed: () => setModalState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: ctx.textoSecund),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (senhaController.text == 'CristoVive@2026') {
                  Navigator.pop(ctx, true);
                } else {
                  AppSnackbar.show(ctx, 'Senha incorreta!', erro: true);
                }
              },
              child: const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.bgPrincipal,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: context.heroGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: context.corPrimaria.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.church_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bem-vindo ao Escala',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(color: context.textoPrimario),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escolha como você deseja acessar o aplicativo',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: context.textoSecund),
                  ),
                  const SizedBox(height: 36),

                  // Card Membro (fluxo mais frequente com leitura clara)
                  _buildRoleCard(
                    context: context,
                    icon: PhosphorIconsBold.user,
                    title: 'Membro / Voluntário',
                    description:
                        'Consulte suas escalas, ouça o repertório, veja cifras e receba lembretes.',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuemSouEuScreen(
                            onMemberSelected: onRoleSelected,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Card Líder
                  _buildRoleCard(
                    context: context,
                    icon: PhosphorIconsBold.shieldCheck,
                    title: 'Líder de Ministério',
                    description:
                        'Acesso completo às configurações, montagem de escalas e gestão da equipe.',
                    onTap: () async {
                      final senhaValida =
                          await _mostrarDialogSenhaLider(context);
                      if (senhaValida == true && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuemSouEuScreen(
                              role: UserRole.lider,
                              onMemberSelected: onRoleSelected,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.acentoSuave,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              size: 28,
              color: context.acentoTexto,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.subheading(color: context.textoPrimario)
                      .copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall(color: context.textoSecund),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            PhosphorIconsBold.caretRight,
            color: context.textoMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
