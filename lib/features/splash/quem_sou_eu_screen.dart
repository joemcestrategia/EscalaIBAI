import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../shared/widgets/app_widgets.dart';

class QuemSouEuScreen extends ConsumerStatefulWidget {
  final VoidCallback onMemberSelected;
  final UserRole role;
  final bool isReconfiguration;

  const QuemSouEuScreen({
    super.key,
    required this.onMemberSelected,
    this.role = UserRole.membro,
    this.isReconfiguration = false,
  });

  @override
  ConsumerState<QuemSouEuScreen> createState() => _QuemSouEuScreenState();
}

class _QuemSouEuScreenState extends ConsumerState<QuemSouEuScreen> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final membrosAsync = ref.watch(membrosProvider);
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: context.bgPrincipal,
      appBar: AppBar(
        title: Text(
          'Quem é você?',
          style: AppTextStyles.heading(color: context.textoPrimario),
        ),
        automaticallyImplyLeading: canPop,
        leading: canPop
            ? IconButton(
                icon: Icon(
                  PhosphorIconsBold.arrowLeft,
                  color: context.textoPrimario,
                ),
                onPressed: () {
                  if (!widget.isReconfiguration) {
                    ref
                        .read(sharedPreferencesProvider)
                        .remove('has_selected_role');
                    ref.read(sharedPreferencesProvider).remove('user_role');
                  }
                  Navigator.pop(context);
                },
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Text(
                'Selecione seu nome para receber lembretes pessoais da sua escala e jejum:',
                style: AppTextStyles.body(color: context.textoSecund),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                style: AppTextStyles.body(color: context.textoPrimario),
                onChanged: (val) => setState(() => _busca = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar seu nome...',
                  prefixIcon: Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    color: context.textoSecund,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: membrosAsync.when(
                data: (membros) {
                  final filtrados = membros
                      .where((m) => m.nome.toLowerCase().contains(_busca))
                      .toList();
                  filtrados.sort((a, b) => a.nome.compareTo(b.nome));

                  if (filtrados.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhum membro encontrado.',
                        style: AppTextStyles.body(color: context.textoSecund),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final membro = filtrados[i];
                      return AppSurfaceCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        onTap: () async {
                          // Inicia o registro do Push antes dos awaits para manter o user gesture no Safari iOS
                          final pushFuture =
                              PushNotificationService.registerAndSaveToken(
                            membro.id,
                          );

                          await ref.read(userRoleProvider.notifier).setRole(
                                widget.role,
                                membroId: membro.id,
                                membroNome: membro.nome,
                              );

                          ref.invalidate(
                            compromissosDoMembroProvider(membro.nome),
                          );
                          ref
                              .read(escalaRepoProvider)
                              .getByMembro(membro.nome)
                              .then((itens) {
                            NotificationService.agendarNotificacoesEscala(
                              itens,
                            );
                          });

                          widget.onMemberSelected();
                          if (context.mounted && Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          await pushFuture;
                        },
                        child: Row(
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
                                      color: ctx.textoPrimario,
                                    ),
                                  ),
                                  if (membro.ministerio.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      membro.ministerio,
                                      style: AppTextStyles.bodySmall(
                                        color: ctx.textoSecund,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              PhosphorIconsBold.caretRight,
                              color: ctx.textoMuted,
                              size: 18,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: context.corPrimaria),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    'Erro ao carregar membros',
                    style: AppTextStyles.body(color: AppColors.perigo),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
