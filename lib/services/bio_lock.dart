import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// قفل التطبيق بالوجه/البصمة — اختياري (مطفأ افتراضياً، يُفعَّل من الإعدادات).
/// لا يغني عن الجلسة: هو طبقة إضافية أمام فتح التطبيق فقط.
class BioLock {
  static const FlutterSecureStorage _s = FlutterSecureStorage();
  static const String _key = 'jasir_bio_lock';

  static bool enabled = false;

  static Future<void> load() async {
    try {
      enabled = (await _s.read(key: _key)) == '1';
    } catch (_) {}
  }

  static Future<void> setEnabled(bool v) async {
    enabled = v;
    try {
      await _s.write(key: _key, value: v ? '1' : '0');
    } catch (_) {}
  }

  /// هل الجهاز يدعم البصمة/الوجه أصلاً؟
  static Future<bool> deviceSupported() async {
    try {
      final a = LocalAuthentication();
      return await a.isDeviceSupported() || await a.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// يطلب المصادقة. true = نجحت (أو الجهاز لا يدعمها أصلاً — لا نحبس
  /// المستخدم خارج تطبيقه بسبب عطل نظام).
  static Future<bool> authenticate() async {
    try {
      final a = LocalAuthentication();
      if (!await a.isDeviceSupported()) return true;
      return await a.authenticate(
        localizedReason: 'افتح جاسر بالوجه أو البصمة',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return true; // عطل في خدمة النظام — الجلسة نفسها ما زالت تحمي الدخول
    }
  }
}
