import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Baloo 2 = display/headline font, Inter = body/UI font (matches the source design).
class AppFonts {
  AppFonts._();

  static TextStyle baloo({
    required double size,
    FontWeight weight = FontWeight.w800,
    Color color = Colors.white,
    // TextStyle forbids setting `color` and `foreground` at the same time
    // (e.g. a gradient stroke Paint) — so when `foreground` is passed, we
    // drop `color` rather than sending both.
    Paint? foreground,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.baloo2(
      fontSize: size,
      fontWeight: weight,
      color: foreground == null ? color : null,
      foreground: foreground,
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
