import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Superfícies — Modo Escuro Suave (Palco / Culto)
  static const Color bgPrincipal = Color(0xFF0E1116);
  static const Color bgCard = Color(0xFF171C24);
  static const Color bgSubtle = Color(0xFF212834);
  static const Color bgBorda = Color(0xFF262F3D);

  // Identidade Safira & Semânticas
  static const Color acento = Color(0xFF2563EB);
  static const Color acentoDark = Color(0xFF3B82F6);
  static const Color acentoAzul = Color(0xFF0EA5E9);
  static const Color sucesso = Color(0xFF059669);
  static const Color alerta = Color(0xFFD97706);
  static const Color perigo = Color(0xFFDC2626);

  // Cores de Texto — Modo Escuro
  static const Color textoPrimario = Color(0xFFF8FAFC);
  static const Color textoSecund = Color(0xFF94A3B8);
  static const Color textoMuted = Color(0xFF64748B);

  // Superfícies & Texto — Modo Claro Editorial (Dia)
  static const Color bgPrincipalLight = Color(0xFFF4F6F9);
  static const Color bgCardLight = Color(0xFFFFFFFF);
  static const Color bgSubtleLight = Color(0xFFEEF2F6);
  static const Color bgBordaLight = Color(0xFFE2E8F0);
  static const Color textoPrimarioLight = Color(0xFF0F172A);
  static const Color textoSecundLight = Color(0xFF475569);
  static const Color textoMutedLight = Color(0xFF64748B);

  // Gradientes Hero Safira
  static const LinearGradient heroGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
  );

  static const List<Color> minColors = [
    Color(0xFF2563EB), // Safira
    Color(0xFF7C3AED), // Violeta
    Color(0xFF059669), // Esmeralda
    Color(0xFFEA580C), // Terracota
    Color(0xFFDB2777), // Rosa Profundo
    Color(0xFF0891B2), // Ciano Escuro
    Color(0xFF4F46E5), // Índigo
    Color(0xFFD97706), // Âmbar
    Color(0xFF0D9488), // Teal
  ];
}

extension ThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get textoPrimario =>
      isDark ? AppColors.textoPrimario : AppColors.textoPrimarioLight;
  Color get textoSecund =>
      isDark ? AppColors.textoSecund : AppColors.textoSecundLight;
  Color get textoMuted =>
      isDark ? AppColors.textoMuted : AppColors.textoMutedLight;

  Color get bgCard => isDark ? AppColors.bgCard : AppColors.bgCardLight;
  Color get bgPrincipal =>
      isDark ? AppColors.bgPrincipal : AppColors.bgPrincipalLight;
  Color get bgSubtle => isDark ? AppColors.bgSubtle : AppColors.bgSubtleLight;
  Color get bgBorda => isDark ? AppColors.bgBorda : AppColors.bgBordaLight;

  Color get corPrimaria => isDark ? AppColors.acentoDark : AppColors.acento;
  Color get acentoSuave => isDark
      ? const Color(0xFF3B82F6).withValues(alpha: 0.16)
      : const Color(0xFFDBEAFE);
  Color get acentoTexto =>
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);

  LinearGradient get heroGradient =>
      isDark ? AppColors.heroGradientDark : AppColors.heroGradientLight;

  List<BoxShadow> get cardShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];
}
