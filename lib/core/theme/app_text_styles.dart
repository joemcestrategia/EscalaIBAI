import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: fontWeight ?? FontWeight.w800,
        color: color,
        letterSpacing: -0.5,
        height: 1.2,
      );

  static TextStyle heading({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: fontWeight ?? FontWeight.w700,
        color: color,
        letterSpacing: -0.3,
        height: 1.25,
      );

  static TextStyle subheading({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: fontWeight ?? FontWeight.w700,
        color: color,
        letterSpacing: -0.2,
        height: 1.3,
      );

  static TextStyle body({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15.5,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color,
        height: 1.4,
      );

  static TextStyle bodySmall({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color,
        height: 1.35,
      );

  static TextStyle label({
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: fontWeight ?? FontWeight.w600,
        color: color,
        letterSpacing: letterSpacing ?? 0.2,
      );

  static TextStyle mono({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: fontWeight ?? FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle monoSmall({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: fontWeight ?? FontWeight.w600,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle button({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: fontWeight ?? FontWeight.w700,
        color: color,
        letterSpacing: 0.1,
      );
}
