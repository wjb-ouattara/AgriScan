import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg       = Color(0xFFF2F6ED);
  static const Color surface  = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFEAF0E3);
  static const Color surface3 = Color(0xFFDDE8D3);

  // Brand Greens — haut contraste pour plein soleil
  static const Color g900 = Color(0xFF1A3D1C);
  static const Color g800 = Color(0xFF234F26);
  static const Color g700 = Color(0xFF2D6530); // Primary
  static const Color g600 = Color(0xFF3A7D3E);
  static const Color g500 = Color(0xFF4A9050);
  static const Color g300 = Color(0xFFA8D5AC);
  static const Color g100 = Color(0xFFDCF0DE);
  static const Color g50  = Color(0xFFF0F9F1);


  static const Color amber  = Color(0xFFE8920A);
  static const Color amber2 = Color(0xFFFEF0D6);
  static const Color amber3 = Color(0xFFFCD280);

  // Alertes
  static const Color red   = Color(0xFFC0321A);
  static const Color red2  = Color(0xFFFEE8E4);
  static const Color red3  = Color(0xFFF9BCB4);

  // Succès
  static const Color green  = Color(0xFF1D6B2A);
  static const Color green2 = Color(0xFFD8F0DC);


  static const Color t1 = Color(0xFF1A2E1B); // Primary (ratio 12.3:1)
  static const Color t2 = Color(0xFF3B5C3E); // Secondary
  static const Color t3 = Color(0xFF6B8E6F); // Tertiary
  static const Color t4 = Color(0xFFA0BCAA); // Disabled

  // Bordures
  static const Color border  = Color(0xFFC8DCC0);
  static const Color border2 = Color(0xFFB0CDB8);
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.g700,
      brightness: Brightness.light,
      primary: AppColors.g700,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.t1,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: _textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.t1,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: AppColors.g900,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 58),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: GoogleFonts.nunito(
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
    ),
  );

  static TextTheme get _textTheme => TextTheme(
    displayLarge: GoogleFonts.nunito(
      fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.g900,
    ),
    displayMedium: GoogleFonts.nunito(
      fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.g900,
    ),
    headlineLarge: GoogleFonts.nunito(
      fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.g900,
    ),
    headlineMedium: GoogleFonts.nunito(
      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.g900,
    ),
    headlineSmall: GoogleFonts.nunito(
      fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.g900,
    ),
    titleLarge: GoogleFonts.nunito(
      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.t1,
    ),
    titleMedium: GoogleFonts.nunito(
      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.t1,
    ),
    bodyLarge: GoogleFonts.nunitoSans(
      fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.t2,
    ),
    bodyMedium: GoogleFonts.nunitoSans(
      fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.t2,
    ),
    bodySmall: GoogleFonts.nunitoSans(
      fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.t3,
    ),
    labelLarge: GoogleFonts.nunito(
      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.t1,
    ),
    labelMedium: GoogleFonts.nunito(
      fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.t3,
      letterSpacing: 1.2,
    ),
  );
}

// ── Radius constants ─────────────────────────────────────
class AppRadius {
  AppRadius._();
  static const double sm   = 10;
  static const double md   = 16;
  static const double lg   = 24;
  static const double xl   = 32;
  static const double pill = 100;
}


class AppShadows {
  AppShadows._();
  static List<BoxShadow> get sm => [
    BoxShadow(color: const Color(0xFF1E461E).withOpacity(0.08),
        blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> get md => [
    BoxShadow(color: const Color(0xFF1E461E).withOpacity(0.12),
        blurRadius: 16, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> get lg => [
    BoxShadow(color: const Color(0xFF1E461E).withOpacity(0.14),
        blurRadius: 32, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> get green => [
    BoxShadow(color: AppColors.g700.withOpacity(0.35),
        blurRadius: 16, offset: const Offset(0, 4)),
  ];
}
