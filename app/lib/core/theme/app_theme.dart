import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final text = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: DT.text,
      displayColor: DT.text,
    );

    return base.copyWith(
      scaffoldBackgroundColor: DT.bg,
      colorScheme: const ColorScheme.light(
        primary: DT.brand600,
        onPrimary: Colors.white,
        secondary: DT.brand700,
        onSecondary: Colors.white,
        surface: DT.surface,
        onSurface: DT.text,
        error: DT.err600,
        onError: Colors.white,
      ),
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(fontSize: DT.fsH1, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: text.headlineMedium?.copyWith(fontSize: DT.fsH2, fontWeight: FontWeight.w600),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: DT.fsBody),
        bodySmall: text.bodySmall?.copyWith(fontSize: DT.fsSm, color: DT.text2),
      ),
      dividerColor: DT.divider,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DT.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DT.rSm),
          borderSide: const BorderSide(color: DT.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DT.rSm),
          borderSide: const BorderSide(color: DT.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DT.rSm),
          borderSide: const BorderSide(color: DT.brand500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DT.rSm),
          borderSide: const BorderSide(color: DT.err500),
        ),
        labelStyle: const TextStyle(color: DT.text2, fontSize: DT.fsSm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DT.brand600,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, DT.btnHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rSm)),
          textStyle: const TextStyle(fontSize: DT.fsBody, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DT.text,
          side: const BorderSide(color: DT.border),
          minimumSize: const Size(0, DT.btnHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rSm)),
          textStyle: const TextStyle(fontSize: DT.fsBody, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DT.text2,
          minimumSize: const Size(0, DT.btnHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rSm)),
        ),
      ),
      cardTheme: const CardThemeData(
        color: DT.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DT.surface,
        foregroundColor: DT.text,
        elevation: 0,
        toolbarHeight: DT.topbarHeight,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: DT.text,
        ),
      ),
    );
  }

  static TextStyle mono({double size = 12, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color ?? DT.text);
}
