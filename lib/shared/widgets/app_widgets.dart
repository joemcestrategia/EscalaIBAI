import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determina a cor do conteúdo (texto/ícone/loading)
    // Se for outlined, usa a cor de acento.
    // Se for elevado, usa branco no tema claro e preto no tema escuro (conforme AppTheme)
    final foregroundColor = outlined
        ? AppColors.acento
        : (isDark ? Colors.black : Colors.white);

    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foregroundColor),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppTextStyles.button(color: foregroundColor),
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
            side: BorderSide(color: foregroundColor),
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
          foregroundColor: foregroundColor,
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          erro ? Icons.error_outline : Icons.check_circle_outline,
          color: erro ? AppColors.perigo : AppColors.sucesso,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg, style: AppTextStyles.body(color: context.textoPrimario)),
        ),
      ]),
      backgroundColor: context.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: erro ? AppColors.perigo : AppColors.sucesso,
          width: 1,
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
      style: AppTextStyles.body(),
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
      title: Text(titulo, style: AppTextStyles.heading()),
      content: Text(mensagem,
          style: AppTextStyles.body(color: context.textoSecund)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
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
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.acento),
                  if (mensagem != null) ...[
                    const SizedBox(height: 16),
                    Text(mensagem!, style: AppTextStyles.body()),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
