import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Avatar moderno com iniciais automáticas e paleta suave consistente.
class AppAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? accentColor;
  final bool circular;

  const AppAvatar({
    super.key,
    required this.name,
    this.size = 42,
    this.accentColor,
    this.circular = false,
  });

  static String initialsOf(String raw) {
    final parts = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && !p.startsWith('['))
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final baseColor =
        accentColor ?? AppColors.minColors[hash % AppColors.minColors.length];
    final bg = baseColor.withValues(alpha: context.isDark ? 0.18 : 0.12);
    final fg = context.isDark
        ? Color.lerp(baseColor, Colors.white, 0.25)!
        : Color.lerp(baseColor, Colors.black, 0.12)!;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(size * 0.34),
      ),
      child: Text(
        initialsOf(name),
        style: AppTextStyles.bodySmall(
          color: fg,
          fontWeight: FontWeight.w800,
        ).copyWith(fontSize: size * 0.35),
      ),
    );
  }
}

/// Seletor de abas em formato de pílula (Segmented Control estilo iOS/Nubank).
class AppSegmentedTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> tabs;
  final TabController? controller;
  final EdgeInsetsGeometry margin;

  const AppSegmentedTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.margin = const EdgeInsets.fromLTRB(16, 4, 16, 10),
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: margin,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.bgSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.bgBorda.withValues(alpha: 0.7)),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(10),
        indicator: BoxDecoration(
          color: context.bgCard,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: context.textoPrimario,
        unselectedLabelColor: context.textoSecund,
        labelStyle: AppTextStyles.bodySmall(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            AppTextStyles.bodySmall(fontWeight: FontWeight.w600),
        tabs: tabs,
      ),
    );
  }
}

/// Card editorial limpo com sombra suave no modo claro e borda sutil.
class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double borderRadius;

  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: context.bgBorda),
        boxShadow: context.cardShadow,
      ),
      child: child,
    );

    if (onTap == null) {
      return Container(margin: margin, child: content);
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: context.bgBorda),
        boxShadow: context.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool loading;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.outlined = false,
    this.loading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    // Sobre o Azul Safira, o contraste ideal de texto/ícone é sempre branco puro
    final foregroundColor = outlined ? context.corPrimaria : Colors.white;

    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: foregroundColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: foregroundColor),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button(color: foregroundColor),
                ),
              ),
            ],
          );

    if (outlined) {
      return SizedBox(
        width: width,
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor,
            side: BorderSide(color: context.corPrimaria.withValues(alpha: 0.5)),
          ),
          child: child,
        ),
      );
    }
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acento,
          foregroundColor: Colors.white,
        ),
        child: child,
      ),
    );
  }
}

class AppSnackbar {
  static void show(
    BuildContext context,
    String msg, {
    bool erro = false,
  }) {
    final accent = erro ? AppColors.perigo : AppColors.sucesso;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          erro ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: accent,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            msg,
            style: AppTextStyles.body(color: context.textoPrimario),
          ),
        ),
      ]),
      backgroundColor: context.bgCard,
      elevation: 6,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: accent.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      duration: const Duration(seconds: 3),
    ));
  }
}

class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? hint;
  final bool enabled;
  final Widget? suffixIcon;
  final Widget? prefixIcon;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.readOnly = false,
    this.enabled = true,
    this.onTap,
    this.hint,
    this.suffixIcon,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      enabled: enabled,
      onTap: onTap,
      style: AppTextStyles.body(color: context.textoPrimario),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
      ),
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final String labelConfirmar;
  final bool perigo;

  const ConfirmDialog({
    super.key,
    required this.titulo,
    required this.mensagem,
    this.labelConfirmar = 'Confirmar',
    this.perigo = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    String labelConfirmar = 'Confirmar',
    bool perigo = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmDialog(
            titulo: titulo,
            mensagem: mensagem,
            labelConfirmar: labelConfirmar,
            perigo: perigo,
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titulo, style: AppTextStyles.heading(color: context.textoPrimario)),
      content: Text(
        mensagem,
        style: AppTextStyles.body(color: context.textoSecund),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: context.textoSecund),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: perigo ? AppColors.perigo : AppColors.acento,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(labelConfirmar),
        ),
      ],
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool loading;
  final Widget child;
  final String? mensagem;

  const LoadingOverlay({
    super.key,
    required this.loading,
    required this.child,
    this.mensagem,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (loading)
          Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                  color: context.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.bgBorda),
                  boxShadow: context.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: context.corPrimaria),
                    if (mensagem != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        mensagem!,
                        style: AppTextStyles.body(color: context.textoPrimario),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
