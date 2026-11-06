import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color bgPrincipal = Color(0xFF0F1117);
  static const Color bgCard = Color(0xFF1A1D27);
  static const Color bgBorda = Color(0xFF2A2D3E);
  static const Color acento = Color(0xFFC9A84C);
  static const Color acentoAzul = Color(0xFF4C7BC9);
  static const Color sucesso = Color(0xFF2ECC71);
  static const Color perigo = Color(0xFFE74C3C);
  
  // Cores Legadas de Texto (Evitar usar, deixar o tema resolver)
  static const Color textoPrimario = Color(0xFFFFFFFF);
  static const Color textoSecund = Color(0xFFB0B3C6);
  static const Color textoMuted = Color(0xFF6B708A);

  // Cores do Tema Claro
  static const Color bgPrincipalLight = Color(0xFFF8F9FA);
  static const Color bgCardLight = Color(0xFFFFFFFF);
  static const Color bgBordaLight = Color(0xFFE9ECEF);
  static const Color textoPrimarioLight = Color(0xFF212529);
  static const Color textoSecundLight = Color(0xFF495057);
  static const Color textoMutedLight = Color(0xFF6C757D);

  static const List<Color> minColors = [
    Color(0xFF4C7BC9),
    Color(0xFF6610F2),
    Color(0xFFD63384),
    Color(0xFFFD7E14),
    Color(0xFF20C997),
    Color(0xFF0DCAF0),
    Color(0xFFADB5BD),
    Color(0xFF343A40),
    Color(0xFFC9A84C),
  ];
}

extension ThemeColors on BuildContext {
  Color get textoPrimario => Theme.of(this).brightness == Brightness.dark ? AppColors.textoPrimario : AppColors.textoPrimarioLight;
  Color get textoSecund => Theme.of(this).brightness == Brightness.dark ? AppColors.textoSecund : AppColors.textoSecundLight;
  Color get bgCard => Theme.of(this).brightness == Brightness.dark ? AppColors.bgCard : AppColors.bgCardLight;
  Color get bgPrincipal => Theme.of(this).brightness == Brightness.dark ? AppColors.bgPrincipal : AppColors.bgPrincipalLight;
  Color get bgBorda => Theme.of(this).brightness == Brightness.dark ? AppColors.bgBorda : AppColors.bgBordaLight;
}
