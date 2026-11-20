import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle displayLarge = GoogleFonts.playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static TextStyle displayMedium = GoogleFonts.playfairDisplay(
    fontSize: 26,
    fontWeight: FontWeight.w700,
  );

  static TextStyle headline = GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  static TextStyle title = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle button = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static TextStyle username = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static TextStyle subtle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
}
