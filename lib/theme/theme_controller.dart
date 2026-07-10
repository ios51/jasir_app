import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// يحفظ ويبثّ اختيار المستخدم للمظهر (فاتح/داكن/تلقائي) وحجم الخط.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  final FlutterSecureStorage _s = const FlutterSecureStorage();
  ThemeMode mode = ThemeMode.system;
  double fontScale = 1.0;

  Future<void> load() async {
    try {
      final m = await _s.read(key: 'theme_mode');
      mode = m == 'light'
          ? ThemeMode.light
          : m == 'dark'
              ? ThemeMode.dark
              : ThemeMode.system;
      final f = await _s.read(key: 'font_scale');
      fontScale = double.tryParse(f ?? '') ?? 1.0;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    mode = m;
    notifyListeners();
    try {
      await _s.write(
        key: 'theme_mode',
        value: m == ThemeMode.light
            ? 'light'
            : m == ThemeMode.dark
                ? 'dark'
                : 'system',
      );
    } catch (_) {}
  }

  Future<void> setFontScale(double v) async {
    fontScale = v;
    notifyListeners();
    try {
      await _s.write(key: 'font_scale', value: v.toStringAsFixed(2));
    } catch (_) {}
  }
}
