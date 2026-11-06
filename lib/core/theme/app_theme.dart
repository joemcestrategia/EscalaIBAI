import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Classe responsável por gerenciar os temas do aplicativo.
/// Implementa o Material 3 e garante acessibilidade (contraste WCAG AA).
class AppTheme {
  AppTheme._();

  // Cor semente (Seed Color) elegante e acessível
  static const Color _seedColor = AppColors.acento;

  /// Tema Escuro (Dark Theme)
  static ThemeData get dark {
    // O ColorScheme.fromSeed gera uma paleta harmoniosa a partir da cor semente
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      surface: AppColors.bgCard, // Mantendo a consistência visual do app
      primary: AppColors.acento,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgPrincipal,
      colorScheme: colorScheme,
      iconTheme: const IconThemeData(color: AppColors.textoPrimario),
      
      // Estilos de Texto
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.cinzel(color: AppColors.textoPrimario),
        displayMedium: GoogleFonts.cinzel(color: AppColors.textoPrimario),
        headlineLarge: GoogleFonts.cinzel(color: AppColors.textoPrimario),
        headlineMedium: GoogleFonts.cinzel(color: AppColors.textoPrimario),
      ),

      // AppBar protegida e legível
      // A cor 'onSurface' garante o contraste do texto sobre o fundo da AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgPrincipal,
        foregroundColor: AppColors.textoPrimario,
        elevation: 0,
        centerTitle: false,
      ),

      // Barra de Navegação
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        indicatorColor: AppColors.acento.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.acento,
              fontWeight: FontWeight.w600,
            );
          }
          return GoogleFonts.dmSans(
            fontSize: 11,
            color: AppColors.textoSecund,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.acento);
          }
          return const IconThemeData(color: AppColors.textoSecund);
        }),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgBorda, width: 1),
        ),
      ),

      // Botão Elevado (ElevatedButton) - Um dos mais problemáticos
      // 'backgroundColor' define a cor de fundo (primary)
      // 'foregroundColor' define a cor do texto/ícone (onPrimary), garantindo contraste
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acento,
          foregroundColor: Colors.black, // Contraste garantido sobre o dourado
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),

      // Botão Contornado
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.acento,
          side: const BorderSide(color: AppColors.acento),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // Botão de Texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.acento,
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // Decoração de Inputs (Campos de Texto)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgBorda),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgBorda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.acento, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.perigo),
        ),
        labelStyle: GoogleFonts.dmSans(color: AppColors.textoSecund, fontSize: 14),
        hintStyle: GoogleFonts.dmSans(color: AppColors.textoMuted, fontSize: 14),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.acento,
        foregroundColor: Colors.black,
        elevation: 4,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.bgBorda,
        thickness: 1,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.acento, width: 1),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgBorda,
        labelStyle: GoogleFonts.dmSans(color: AppColors.textoPrimario, fontSize: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  /// Tema Claro (Light Theme)
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      surface: AppColors.bgCardLight,
      primary: AppColors.acento,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgPrincipalLight,
      colorScheme: colorScheme,
      iconTheme: const IconThemeData(color: AppColors.textoPrimarioLight),

      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.cinzel(color: AppColors.textoPrimarioLight),
        displayMedium: GoogleFonts.cinzel(color: AppColors.textoPrimarioLight),
        headlineLarge: GoogleFonts.cinzel(color: AppColors.textoPrimarioLight),
        headlineMedium: GoogleFonts.cinzel(color: AppColors.textoPrimarioLight),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgPrincipalLight,
        foregroundColor: AppColors.textoPrimarioLight,
        elevation: 0,
        centerTitle: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgCardLight,
        indicatorColor: AppColors.acento.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.acento,
              fontWeight: FontWeight.w600,
            );
          }
          return GoogleFonts.dmSans(
            fontSize: 11,
            color: AppColors.textoSecundLight,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.acento);
          }
          return const IconThemeData(color: AppColors.textoSecundLight);
        }),
      ),

      cardTheme: CardThemeData(
        color: AppColors.bgCardLight,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgBordaLight, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acento,
          foregroundColor: Colors.white, // Contraste para o modo claro
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.acento,
          side: const BorderSide(color: AppColors.acento),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCardLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgBordaLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgBordaLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.acento, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.perigo),
        ),
        labelStyle: GoogleFonts.dmSans(color: AppColors.textoSecundLight, fontSize: 14),
        hintStyle: GoogleFonts.dmSans(color: AppColors.textoMutedLight, fontSize: 14),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgCardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
