import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Baloo 2 = display/headline font, Inter = body/UI font (matches the source design).
class AppFonts {
  AppFonts._();

  static TextStyle baloo({
    required double size,
    FontWeight weight = FontWeight.w800,
    Color color = Colors.white,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.baloo2(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle inter({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color color = Colors.white,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
