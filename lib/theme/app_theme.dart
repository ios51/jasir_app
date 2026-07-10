import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// هوية جاسر البصرية كثيم فلاتر — ألوان Teal + ذهبي، خطوط Amiri + Tajawal،
/// مود فاتح وداكن.
class AppTheme {
  static const Color teal = Color(0xFF0E7C6C);
  static const Color tealBright = Color(0xFF2FBFA3);
  static const Color gold = Color(0xFFE0A82E);
  static const Color goldBright = Color(0xFFFBBF24);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
    ).copyWith(primary: teal, secondary: gold);
    return _base(scheme, Brightness.light, const Color(0xFFF5F8F6));
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.dark,
    ).copyWith(
      primary: tealBright,
      secondary: goldBright,
      surface: const Color(0xFF171E26),
    );
    return _base(scheme, Brightness.dark, const Color(0xFF0E1116));
  }

  static ThemeData _base(ColorScheme scheme, Brightness b, Color bg) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: bg,
    );
    final onPrimary = Colors.white;
    return base.copyWith(
      textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: teal, // نفس لون أيقونة جاسر في المودين
        foregroundColor: onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.amiri(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: onPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: onPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  /// نمط عنوان وجداني بخط Amiri (للتصبيحة والأدعية واسم جاسر).
  static TextStyle amiriTitle(BuildContext context, {double size = 22}) =>
      GoogleFonts.amiri(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );
}
