import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/membro.dart';

class QuemSouEuScreen extends ConsumerStatefulWidget {
  final VoidCallback onMemberSelected;

  const QuemSouEuScreen({
    super.key,
    required this.onMemberSelected,
  });

  @override
  ConsumerState<QuemSouEuScreen> createState() => _QuemSouEuScreenState();
}

class _QuemSouEuScreenState extends ConsumerState<QuemSouEuScreen> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final membrosAsync = ref.watch(membrosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Quem é você?', style: AppTextStyles.heading(color: Colors.white).copyWith(fontSize: 20)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Volta para a seleção de perfil (Líder/Membro) desfazendo a escolha
            ref.read(sharedPreferencesProvider).remove('has_selected_role');
            ref.read(sharedPreferencesProvider).remove('user_role');
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: TextField(
                  style: AppTextStyles.body(color: Colors.white),
                  onChanged: (val) => setState(() => _busca = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Buscar seu nome...',
                    hintStyle: AppTextStyles.body(color: Colors.white54),
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1E293B).withValues(alpha: 0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: membrosAsync.when(
                  data: (membros) {
                    final filtrados = membros.where((m) => m.nome.toLowerCase().contains(_busca)).toList();
                    filtrados.sort((a, b) => a.nome.compareTo(b.nome));

                    if (filtrados.isEmpty) {
                      return Center(
                        child: Text('Nenhum membro encontrado.', style: AppTextStyles.body(color: Colors.white54)),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: filtrados.length,
                      itemBuilder: (ctx, i) {
                        final membro = filtrados[i];
                        return Card(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: context.bgBorda.withValues(alpha: 0.3)),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.acento.withValues(alpha: 0.2),
                              child: Text(
                                membro.nome.substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: AppColors.acento, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(membro.nome, style: AppTextStyles.subheading(color: Colors.white)),
                            subtitle: Text(membro.ministerio, style: AppTextStyles.bodySmall(color: Colors.white54)),
                            trailing: const Icon(PhosphorIconsRegular.caretRight, color: Colors.white54),
                            onTap: () async {
                              await ref.read(userRoleProvider.notifier).setRole(
                                UserRole.membro, 
                                membroId: membro.id, 
                                membroNome: membro.nome
                              );
                              widget.onMemberSelected();
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acento)),
                  error: (err, stack) => Center(child: Text('Erro ao carregar membros', style: AppTextStyles.body(color: Colors.red))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
