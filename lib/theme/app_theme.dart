import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flat dark palette: near-black ground, rose accent, quiet translucent cards.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0C0A0B);
  static const surface = Color(0xFF161214);

  static const accent = Color(0xFFE5466F);
  static const accentSoft = Color(0xFFFF9DB6);

  static const text = Color(0xFFF5EEF0);
  static const muted = Color(0xFFB0A0A5);
  static const dark = Color(0xFF1A1114);

  static const navSurface = Color(0xFF171214);
  static const glass = Color(0x0EFFFFFF); // ~5.5% white
  static const glassStrong = Color(0x14FFFFFF); // ~8% white
  static const stroke = Color(0x14FFFFFF);
  static const strokeStrong = Color(0x1FFFFFFF);

  static const rumour = Color(0xFFFFB46B);
  static const unverified = Color(0xFF8AB4FF);
  static const verified = Color(0xFF4FD1A1);
  static const error = Color(0xFFFF8A8A);
}

class AppTheme {
  AppTheme._();

  /// Inter type scale. Larger sizes get tighter tracking, as Inter's
  /// designers recommend; body text keeps generous line height.
  static TextTheme _textTheme({required bool useGoogleFonts}) {
    TextStyle s(double size, FontWeight weight, double height, double tracking, [Color color = AppColors.text]) =>
        TextStyle(fontSize: size, fontWeight: weight, height: height, letterSpacing: tracking, color: color);

    final theme = TextTheme(
      displaySmall: s(32, FontWeight.w700, 1.15, -0.9),
      headlineSmall: s(26, FontWeight.w600, 1.2, -0.6), // screen titles
      titleLarge: s(22, FontWeight.w600, 1.25, -0.45), // card / sheet titles
      titleMedium: s(17, FontWeight.w600, 1.3, -0.25), // section headings
      titleSmall: s(15, FontWeight.w500, 1.35, -0.15), // list item titles
      bodyLarge: s(16, FontWeight.w400, 1.5, -0.15),
      bodyMedium: s(14, FontWeight.w400, 1.5, -0.08),
      bodySmall: s(12.5, FontWeight.w400, 1.4, 0, AppColors.muted), // captions
      labelLarge: s(15, FontWeight.w600, 1.2, -0.1), // buttons
      labelMedium: s(13, FontWeight.w500, 1.2, -0.05), // chips, segments
      labelSmall: s(11.5, FontWeight.w500, 1.2, 0.1), // badges, fine print
    );
    return useGoogleFonts ? GoogleFonts.interTextTheme(theme) : theme;
  }

  /// [useGoogleFonts] is off in widget tests, where fonts can't be fetched.
  static ThemeData dark({bool useGoogleFonts = true}) {
    final textTheme = _textTheme(useGoogleFonts: useGoogleFonts);
    final fontFamily = useGoogleFonts ? GoogleFonts.inter().fontFamily : null;

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentSoft,
        surface: AppColors.background,
        onSurface: AppColors.text,
        onPrimary: Colors.white,
        error: AppColors.error,
      ),
      splashFactory: InkRipple.splashFactory,
      iconTheme: const IconThemeData(color: AppColors.text, size: 22),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.dark,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.strokeStrong),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: textTheme.labelMedium?.copyWith(color: AppColors.dark),
        decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentSoft,
          minimumSize: const Size(44, 44),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: textTheme.labelMedium,
        backgroundColor: AppColors.glass,
        side: const BorderSide(color: AppColors.stroke),
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: AppColors.muted),
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.error),
      ),
    );
  }
}

/// Named text roles so every screen uses the same scale.
class AppText {
  AppText._();

  static TextTheme _t(BuildContext c) => Theme.of(c).textTheme;

  /// Screen titles.
  static TextStyle title(BuildContext c) => _t(c).headlineSmall!;

  /// Card and sheet titles.
  static TextStyle cardTitle(BuildContext c) => _t(c).titleLarge!;

  /// Section headings.
  static TextStyle heading(BuildContext c) => _t(c).titleMedium!;

  /// Titles inside list rows and tiles.
  static TextStyle itemTitle(BuildContext c) => _t(c).titleSmall!;

  static TextStyle body(BuildContext c) => _t(c).bodyMedium!;

  /// Secondary, muted text.
  static TextStyle caption(BuildContext c) => _t(c).bodySmall!;

  /// Chips, segmented controls, button glyphs.
  static TextStyle label(BuildContext c) => _t(c).labelMedium!;

  /// Badges and fine print.
  static TextStyle small(BuildContext c) => _t(c).labelSmall!;

  /// Numbers that change in place (counts, stats) keep a fixed width.
  static TextStyle numeric(TextStyle s) => s.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
