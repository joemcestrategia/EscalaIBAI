import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.cinzel(
        fontSize: 26,
        fontWeight: fontWeight ?? FontWeight.w700,
        color: color,
        letterSpacing: 1.2,
      );

  static TextStyle heading({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.cinzel(
        fontSize: 20,
        fontWeight: fontWeight ?? FontWeight.w600,
        color: color,
        letterSpacing: 0.8,
      );

  static TextStyle subheading({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: fontWeight ?? FontWeight.w600,
        color: color,
      );

  static TextStyle body({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: fontWeight ?? FontWeight.w400,
        color: color,
      );

  static TextStyle bodySmall({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: fontWeight ?? FontWeight.w400,
        color: color,
      );

  static TextStyle label({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle mono({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.robotoMono(
        fontSize: 13,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color,
      );

  static TextStyle monoSmall({Color? color, FontWeight? fontWeight}) =>
      GoogleFonts.robotoMono(
        fontSize: 11,
        fontWeight: fontWeight ?? FontWeight.w400,
        color: color,
      );

  static TextStyle button({Color? color, FontWeight? fontWeight}) => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: fontWeight ?? FontWeight.w700,
        color: color,
        letterSpacing: 0.3,
      );
}
