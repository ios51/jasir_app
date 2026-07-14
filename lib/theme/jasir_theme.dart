import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// نظام تصميم جاسر (MASTER) — Material 3، مودان فاتح/داكن، RTL عربي.
///
/// المصدر الوحيد: design-system/MASTER.md. كل الألوان أدوار ColorScheme +
/// امتداد [JasirGroupColors] للمجموعات الأربع الدلالية. لا يُكتب أي Hex داخل
/// الودجت — كل شيء يُقرأ من هنا.
class JasirTheme {
  JasirTheme._();

  // ── الوضع الفاتح: ألوان الهوية (Hex من MASTER) ──────────────────────
  static const _lPrimary = Color(0xFF0E7C6C);
  static const _lOnPrimary = Color(0xFFFFFFFF);
  static const _lPrimaryContainer = Color(0xFFCDEDE3);
  static const _lOnPrimaryContainer = Color(0xFF0B3E38);
  static const _lSecondary = Color(0xFF0B5E57);
  static const _lOnSecondary = Color(0xFFFFFFFF);
  static const _lSecondaryContainer = Color(0xFFDCEFEA);
  static const _lOnSecondaryContainer = Color(0xFF0B3E38);
  static const _lTertiary = Color(0xFFE0A82E);
  static const _lOnTertiary = Color(0xFF3A2A00);
  static const _lTertiaryContainer = Color(0xFFFBF3E0);
  static const _lOnTertiaryContainer = Color(0xFF5A4410);
  static const _lError = Color(0xFFE5484D);
  static const _lOnError = Color(0xFFFFFFFF);
  static const _lSurface = Color(0xFFFFFFFF);
  static const _lSurfaceLowest = Color(0xFFFFFFFF);
  static const _lSurfaceLow = Color(0xFFF5F8F6); // خلفية الشاشة
  static const _lSurfaceContainer = Color(0xFFEEF3F0);
  static const _lSurfaceHigh = Color(0xFFE7F0EC);
  static const _lOnSurface = Color(0xFF14201C);
  static const _lOnSurfaceVariant = Color(0xFF5E6E68);
  static const _lOutline = Color(0xFFC9D6D0);
  static const _lOutlineVariant = Color(0xFFE6ECE9);
  static const _lInverseSurface = Color(0xFF14201C);

  // ── الوضع الداكن: أسود مائل للرمادي (Hex من MASTER) ─────────────────
  static const _dPrimary = Color(0xFF2FBFA3);
  static const _dOnPrimary = Color(0xFF00382F);
  static const _dPrimaryContainer = Color(0xFF12312A);
  static const _dOnPrimaryContainer = Color(0xFF8FE6CE);
  static const _dSecondary = Color(0xFF8FE6CE);
  static const _dOnSecondary = Color(0xFF00382F);
  static const _dSecondaryContainer = Color(0xFF12312A);
  static const _dOnSecondaryContainer = Color(0xFF8FE6CE);
  static const _dTertiary = Color(0xFFFBBF24);
  static const _dOnTertiary = Color(0xFF3A2A00);
  static const _dTertiaryContainer = Color(0xFF3A2E12);
  static const _dOnTertiaryContainer = Color(0xFFF6D99A);
  static const _dError = Color(0xFFFF6369);
  static const _dOnError = Color(0xFF4E0002);
  static const _dSurface = Color(0xFF171E26);
  static const _dSurfaceLowest = Color(0xFF0B0E12);
  static const _dSurfaceLow = Color(0xFF0E1116); // خلفية الشاشة
  static const _dSurfaceContainer = Color(0xFF171E26);
  static const _dSurfaceHigh = Color(0xFF1E2833);
  static const _dOnSurface = Color(0xFFE7EEEC);
  static const _dOnSurfaceVariant = Color(0xFF93A29C);
  static const _dOutline = Color(0xFF3A4A52);
  static const _dOutlineVariant = Color(0xFF24303A);
  static const _dInverseSurface = Color(0xFFE7EEEC);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _lPrimary,
    onPrimary: _lOnPrimary,
    primaryContainer: _lPrimaryContainer,
    onPrimaryContainer: _lOnPrimaryContainer,
    secondary: _lSecondary,
    onSecondary: _lOnSecondary,
    secondaryContainer: _lSecondaryContainer,
    onSecondaryContainer: _lOnSecondaryContainer,
    tertiary: _lTertiary,
    onTertiary: _lOnTertiary,
    tertiaryContainer: _lTertiaryContainer,
    onTertiaryContainer: _lOnTertiaryContainer,
    error: _lError,
    onError: _lOnError,
    surface: _lSurface,
    onSurface: _lOnSurface,
    onSurfaceVariant: _lOnSurfaceVariant,
    surfaceContainerLowest: _lSurfaceLowest,
    surfaceContainerLow: _lSurfaceLow,
    surfaceContainer: _lSurfaceContainer,
    surfaceContainerHigh: _lSurfaceHigh,
    outline: _lOutline,
    outlineVariant: _lOutlineVariant,
    inverseSurface: _lInverseSurface,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _dPrimary,
    onPrimary: _dOnPrimary,
    primaryContainer: _dPrimaryContainer,
    onPrimaryContainer: _dOnPrimaryContainer,
    secondary: _dSecondary,
    onSecondary: _dOnSecondary,
    secondaryContainer: _dSecondaryContainer,
    onSecondaryContainer: _dOnSecondaryContainer,
    tertiary: _dTertiary,
    onTertiary: _dOnTertiary,
    tertiaryContainer: _dTertiaryContainer,
    onTertiaryContainer: _dOnTertiaryContainer,
    error: _dError,
    onError: _dOnError,
    surface: _dSurface,
    onSurface: _dOnSurface,
    onSurfaceVariant: _dOnSurfaceVariant,
    surfaceContainerLowest: _dSurfaceLowest,
    surfaceContainerLow: _dSurfaceLow,
    surfaceContainer: _dSurfaceContainer,
    surfaceContainerHigh: _dSurfaceHigh,
    outline: _dOutline,
    outlineVariant: _dOutlineVariant,
    inverseSurface: _dInverseSurface,
  );

  // ── امتداد المجموعات الدلالية (فاتح/داكن) ───────────────────────────
  static const _lightGroups = JasirGroupColors(
    // صحة — Teal أساسي
    healthContainer: Color(0xFFCDEDE3),
    healthChip: Color(0xFFBCE4D7),
    healthIcon: Color(0xFF0E7C6C),
    // عائلة — ذهبي دافئ
    familyContainer: Color(0xFFFBF3E0),
    familyChip: Color(0xFFF3E4BE),
    familyIcon: Color(0xFFB4820F),
    // شؤون يومية — محايد مصبوغ Teal (ينحسر عمدًا)
    dailyContainer: Color(0xFFEEF3F0),
    dailyChip: Color(0xFFE0E9E4),
    dailyIcon: Color(0xFF3E5149),
    // روحانيات — Teal عميق + ذهبي (خاتمة وجدانية)
    spiritualContainer: Color(0xFF0B5E57),
    spiritualTileSurface: Color(0xFF0E6E64),
    spiritualChip: Color(0xFF15564F),
    spiritualIcon: Color(0xFFFBBF24),
    spiritualOnContainer: Color(0xFFF7F0DC), // كريمي (الحرف على الـTeal)
    spiritualOnContainerMuted: Color(0xFFB9D6CE),
    // أسطح البلاطات داخل المجموعات الفاتحة/المصبوغة
    tileSurface: Color(0xFFFFFFFF),
    // دلالات مخصّصة
    success: Color(0xFF22A06B),
    warning: Color(0xFFE0A82E),
    cream: Color(0xFFF7F0DC),
    // ظل Level 1 (بلاطة) — منخفض مصبوغ Teal
    tileShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x0F0B5E57), // rgba(11,94,87,0.06)
        offset: Offset(0, 2),
        blurRadius: 10,
        spreadRadius: -3,
      ),
      BoxShadow(
        color: Color(0x0A14201C), // rgba(20,32,28,0.04)
        offset: Offset(0, 2),
        blurRadius: 10,
        spreadRadius: -3,
      ),
    ],
    // ظل Level 2 (مرفوع/بطاقة أولوية)
    raisedShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x1A0B5E57), // rgba(11,94,87,0.10)
        offset: Offset(0, 8),
        blurRadius: 24,
        spreadRadius: -6,
      ),
    ],
  );

  static const _darkGroups = JasirGroupColors(
    healthContainer: Color(0xFF12312A),
    healthChip: Color(0xFF17423A),
    healthIcon: Color(0xFF2FBFA3),
    familyContainer: Color(0xFF3A2E12),
    familyChip: Color(0xFF4A3B18),
    familyIcon: Color(0xFFE7B84B),
    dailyContainer: Color(0xFF1E2833),
    dailyChip: Color(0xFF283440),
    dailyIcon: Color(0xFF93A29C),
    spiritualContainer: Color(0xFF0B5E57),
    spiritualTileSurface: Color(0xFF0E6E64),
    spiritualChip: Color(0xFF15564F),
    spiritualIcon: Color(0xFFFBBF24),
    spiritualOnContainer: Color(0xFFF7F0DC),
    spiritualOnContainerMuted: Color(0xFFB9D6CE),
    tileSurface: Color(0xFF1E2833),
    success: Color(0xFF3FBE86),
    warning: Color(0xFFFBBF24),
    cream: Color(0xFFF7F0DC),
    // الداكن: لا ظل — الارتفاع يُعبَّر عنه بلون السطح
    tileShadow: <BoxShadow>[],
    raisedShadow: <BoxShadow>[],
  );

  static ThemeData light() => _build(_lightScheme, _lightGroups, _lSurfaceLow);
  static ThemeData dark() => _build(_darkScheme, _darkGroups, _dSurfaceLow);

  static ThemeData _build(
      ColorScheme scheme, JasirGroupColors groups, Color scaffoldBg) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scaffoldBg,
    );

    final text = _textTheme(base.textTheme, scheme);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      cardColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
      extensions: <ThemeExtension<dynamic>>[groups],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      listTileTheme: ListTileThemeData(iconColor: scheme.primary),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }

  /// سلّم الطباعة من MASTER — Tajawal لكل الواجهة (Amiri يُطبَّق موضعيًا في
  /// الودجت للحظات الوجدانية فقط: التحية والأذكار).
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    final tj = GoogleFonts.tajawalTextTheme(base).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    return tj.copyWith(
      headlineMedium: GoogleFonts.tajawal(
        fontSize: 24, fontWeight: FontWeight.w700, height: 1.35, color: scheme.onSurface),
      titleLarge: GoogleFonts.tajawal(
        fontSize: 18, fontWeight: FontWeight.w700, height: 1.4, color: scheme.onSurface),
      titleMedium: GoogleFonts.tajawal(
        fontSize: 16, fontWeight: FontWeight.w700, height: 1.3, color: scheme.onSurface),
      bodyLarge: GoogleFonts.tajawal(
        fontSize: 16, fontWeight: FontWeight.w400, height: 1.6, color: scheme.onSurface),
      bodyMedium: GoogleFonts.tajawal(
        fontSize: 14, fontWeight: FontWeight.w400, height: 1.55, color: scheme.onSurface),
      bodySmall: GoogleFonts.tajawal(
        fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.35, color: scheme.onSurfaceVariant),
      labelLarge: GoogleFonts.tajawal(
        fontSize: 14, fontWeight: FontWeight.w500, height: 1.2, color: scheme.onSurface),
      labelMedium: GoogleFonts.tajawal(
        fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, color: scheme.onSurfaceVariant),
      labelSmall: GoogleFonts.tajawal(
        fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, color: scheme.onSurfaceVariant),
    );
  }
}

/// ألوان المجموعات الدلالية الأربع (صحة · عائلة · شؤون يومية · روحانيات) +
/// دلالات مخصّصة وظلال مصبوغة. تُقرأ في الشاشة عبر
/// `Theme.of(context).extension<JasirGroupColors>()!`.
@immutable
class JasirGroupColors extends ThemeExtension<JasirGroupColors> {
  // صحة
  final Color healthContainer;
  final Color healthChip;
  final Color healthIcon;
  // عائلة
  final Color familyContainer;
  final Color familyChip;
  final Color familyIcon;
  // شؤون يومية
  final Color dailyContainer;
  final Color dailyChip;
  final Color dailyIcon;
  // روحانيات
  final Color spiritualContainer;
  final Color spiritualTileSurface;
  final Color spiritualChip;
  final Color spiritualIcon;
  final Color spiritualOnContainer;
  final Color spiritualOnContainerMuted;
  // أسطح البلاطات داخل المجموعات الفاتحة
  final Color tileSurface;
  // دلالات مخصّصة
  final Color success;
  final Color warning;
  final Color cream;
  // ظلال
  final List<BoxShadow> tileShadow;
  final List<BoxShadow> raisedShadow;

  const JasirGroupColors({
    required this.healthContainer,
    required this.healthChip,
    required this.healthIcon,
    required this.familyContainer,
    required this.familyChip,
    required this.familyIcon,
    required this.dailyContainer,
    required this.dailyChip,
    required this.dailyIcon,
    required this.spiritualContainer,
    required this.spiritualTileSurface,
    required this.spiritualChip,
    required this.spiritualIcon,
    required this.spiritualOnContainer,
    required this.spiritualOnContainerMuted,
    required this.tileSurface,
    required this.success,
    required this.warning,
    required this.cream,
    required this.tileShadow,
    required this.raisedShadow,
  });

  @override
  JasirGroupColors copyWith({
    Color? healthContainer,
    Color? healthChip,
    Color? healthIcon,
    Color? familyContainer,
    Color? familyChip,
    Color? familyIcon,
    Color? dailyContainer,
    Color? dailyChip,
    Color? dailyIcon,
    Color? spiritualContainer,
    Color? spiritualTileSurface,
    Color? spiritualChip,
    Color? spiritualIcon,
    Color? spiritualOnContainer,
    Color? spiritualOnContainerMuted,
    Color? tileSurface,
    Color? success,
    Color? warning,
    Color? cream,
    List<BoxShadow>? tileShadow,
    List<BoxShadow>? raisedShadow,
  }) {
    return JasirGroupColors(
      healthContainer: healthContainer ?? this.healthContainer,
      healthChip: healthChip ?? this.healthChip,
      healthIcon: healthIcon ?? this.healthIcon,
      familyContainer: familyContainer ?? this.familyContainer,
      familyChip: familyChip ?? this.familyChip,
      familyIcon: familyIcon ?? this.familyIcon,
      dailyContainer: dailyContainer ?? this.dailyContainer,
      dailyChip: dailyChip ?? this.dailyChip,
      dailyIcon: dailyIcon ?? this.dailyIcon,
      spiritualContainer: spiritualContainer ?? this.spiritualContainer,
      spiritualTileSurface: spiritualTileSurface ?? this.spiritualTileSurface,
      spiritualChip: spiritualChip ?? this.spiritualChip,
      spiritualIcon: spiritualIcon ?? this.spiritualIcon,
      spiritualOnContainer: spiritualOnContainer ?? this.spiritualOnContainer,
      spiritualOnContainerMuted:
          spiritualOnContainerMuted ?? this.spiritualOnContainerMuted,
      tileSurface: tileSurface ?? this.tileSurface,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      cream: cream ?? this.cream,
      tileShadow: tileShadow ?? this.tileShadow,
      raisedShadow: raisedShadow ?? this.raisedShadow,
    );
  }

  @override
  JasirGroupColors lerp(ThemeExtension<JasirGroupColors>? other, double t) {
    if (other is! JasirGroupColors) return this;
    return JasirGroupColors(
      healthContainer: Color.lerp(healthContainer, other.healthContainer, t)!,
      healthChip: Color.lerp(healthChip, other.healthChip, t)!,
      healthIcon: Color.lerp(healthIcon, other.healthIcon, t)!,
      familyContainer: Color.lerp(familyContainer, other.familyContainer, t)!,
      familyChip: Color.lerp(familyChip, other.familyChip, t)!,
      familyIcon: Color.lerp(familyIcon, other.familyIcon, t)!,
      dailyContainer: Color.lerp(dailyContainer, other.dailyContainer, t)!,
      dailyChip: Color.lerp(dailyChip, other.dailyChip, t)!,
      dailyIcon: Color.lerp(dailyIcon, other.dailyIcon, t)!,
      spiritualContainer:
          Color.lerp(spiritualContainer, other.spiritualContainer, t)!,
      spiritualTileSurface:
          Color.lerp(spiritualTileSurface, other.spiritualTileSurface, t)!,
      spiritualChip: Color.lerp(spiritualChip, other.spiritualChip, t)!,
      spiritualIcon: Color.lerp(spiritualIcon, other.spiritualIcon, t)!,
      spiritualOnContainer:
          Color.lerp(spiritualOnContainer, other.spiritualOnContainer, t)!,
      spiritualOnContainerMuted: Color.lerp(
          spiritualOnContainerMuted, other.spiritualOnContainerMuted, t)!,
      tileSurface: Color.lerp(tileSurface, other.tileSurface, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      tileShadow: t < 0.5 ? tileShadow : other.tileShadow,
      raisedShadow: t < 0.5 ? raisedShadow : other.raisedShadow,
    );
  }
}
