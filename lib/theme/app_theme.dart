import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// هوية جاسر البصرية (وفق ملف الهوية) — قاعدة بترولية/كحلية هادئة، لمسة
/// سماوية مميزة لجاسر، بطاقات محايدة، مود فاتح وداكن بقيم دقيقة.
class AppTheme {
  // ── الوضع الداكن ──
  static const dBg = Color(0xFF0B1220);
  static const dSurface = Color(0xFF111C2B); // شريط التنقل/سطح ثانوي
  static const dCard = Color(0xFF162435);
  static const dCardPressed = Color(0xFF1D3045);
  static const dPrimary = Color(0xFF0F8C82);
  static const dPrimaryPressed = Color(0xFF087269);
  static const dAccent = Color(0xFF35C5D8); // سماوي جاسر
  static const dGold = Color(0xFFE7B84B);
  static const dText = Color(0xFFF4F7FB);
  static const dText2 = Color(0xFFAAB7C7);
  static const dBorder = Color(0xFF26384D);
  static const dError = Color(0xFFF05D5E);

  // ── الوضع الفاتح ──
  static const lBg = Color(0xFFF7FAFC);
  static const lSurface = Color(0xFFFFFFFF);
  static const lCard = Color(0xFFFFFFFF);
  static const lHighlight = Color(0xFFEAF8FA);
  static const lPrimary = Color(0xFF087D74);
  static const lPrimaryPressed = Color(0xFF05665F);
  static const lAccent = Color(0xFF0F9DB0);
  static const lGold = Color(0xFFC99222);
  static const lText = Color(0xFF172033);
  static const lText2 = Color(0xFF617087);
  static const lBorder = Color(0xFFDCE5EE);
  static const lError = Color(0xFFD94C4C);

  // أسماء متوافقة مع كود سابق
  static const teal = dPrimary;
  static const tealBright = dAccent;
  static const gold = dGold;
  static const goldBright = dGold;

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: dPrimary,
      onPrimary: Colors.white,
      primaryContainer: dCard,
      onPrimaryContainer: dText,
      secondary: dAccent,
      onSecondary: Color(0xFF04222A),
      surface: dCard,
      onSurface: dText,
      onSurfaceVariant: dText2,
      error: dError,
      onError: Colors.white,
      outline: dBorder,
    );
    return _base(scheme, Brightness.dark, dBg, dSurface, dText2);
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: lPrimary,
      onPrimary: Colors.white,
      primaryContainer: lHighlight,
      onPrimaryContainer: lPrimaryPressed,
      secondary: lAccent,
      onSecondary: Colors.white,
      surface: lCard,
      onSurface: lText,
      onSurfaceVariant: lText2,
      error: lError,
      onError: Colors.white,
      outline: lBorder,
    );
    return _base(scheme, Brightness.light, lBg, lSurface, lText2);
  }

  static ThemeData _base(
      ColorScheme scheme, Brightness b, Color bg, Color navBg, Color text2) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: bg,
    );
    final tt = GoogleFonts.tajawalTextTheme(base.textTheme)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    return base.copyWith(
      textTheme: tt,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: scheme.surface,
      dividerColor: scheme.outline,
      hintColor: text2,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: scheme.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
            fontSize: 22, fontWeight: FontWeight.w700, color: scheme.primary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      listTileTheme: ListTileThemeData(iconColor: scheme.primary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: TextStyle(color: text2),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary, width: 1.5)),
      ),
    );
  }

  /// نمط عنوان وجداني (يُستخدم للتصبيحة/اسم جاسر).
  static TextStyle amiriTitle(BuildContext context, {double size = 22}) =>
      GoogleFonts.tajawal(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );
}
