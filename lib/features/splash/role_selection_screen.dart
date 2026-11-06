import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import 'quem_sou_eu_screen.dart';

class RoleSelectionScreen extends ConsumerWidget {
  final VoidCallback onRoleSelected;

  const RoleSelectionScreen({
    super.key,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ícone e Título
                const Icon(
                  Icons.church,
                  size: 64,
                  color: AppColors.acento,
                ),
                const SizedBox(height: 24),
                Text(
                  'Bem-vindo ao Escala',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(color: Colors.white).copyWith(fontSize: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  'Identifique seu perfil de acesso',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall(color: context.textoSecund),
                ),
                const SizedBox(height: 48),

                // Card Líder
                _buildRoleCard(
                  context: context,
                  icon: PhosphorIconsBold.shieldCheck,
                  title: 'Líder',
                  description: 'Acesso total às configurações, escalas e gestão de membros.',
                  onTap: () async {
                    final senhaController = TextEditingController();
                    final senhaValida = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: Text('Acesso Restrito', style: AppTextStyles.heading(color: Colors.white)),
                        content: TextField(
                          controller: senhaController,
                          obscureText: true,
                          style: AppTextStyles.body(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Digite a senha do Líder',
                            hintStyle: AppTextStyles.body(color: Colors.white54),
                            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.acento)),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.acento)),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () {
                              if (senhaController.text == 'CristoVive@2026') {
                                Navigator.pop(ctx, true);
                              } else {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Senha incorreta!', style: TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.red,
                                  )
                                );
                              }
                            },
                            child: const Text('Entrar', style: TextStyle(color: AppColors.acento, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );

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
                const SizedBox(height: 20),

                // Card Membro
                _buildRoleCard(
                  context: context,
                  icon: PhosphorIconsBold.user,
                  title: 'Membro',
                  description: 'Visualização de escalas, adicionar músicas e exportar agendas.',
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
              ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.bgBorda.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.acento.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppColors.acento,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.subheading(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall(color: context.textoSecund),
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIconsBold.caretRight,
                color: context.textoSecund,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
