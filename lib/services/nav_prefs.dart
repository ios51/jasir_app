import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// إشارة تبديل التبويب السفلي: الشاشات المحفوظة في IndexedStack تستمع لها
/// وتعيد التحميل — يحل «المهمة المضافة من المحادثة ما تظهر إلا بالسحب».
final ValueNotifier<int> tabSwitchSignal = ValueNotifier<int>(0);

/// تفضيلات الشريط السفلي (الوصول السريع): المستخدم يختار ٣ خدمات تظهر
/// بجانب تبويب «الرئيسية» الثابت. تُحفظ محلياً كمعرّفات مفصولة بفواصل.
class NavPrefs {
  static const FlutterSecureStorage _s = FlutterSecureStorage();
  static const String _key = 'jasir_nav_tabs';

  /// الافتراضي = ما كان قبل التخصيص: المواعيد · الأدوية · العائلة.
  static const List<String> defaults = ['appointments', 'meds', 'family'];

  static List<String> current = List.of(defaults);

  /// يزيد عند أي تغيير (تحميل أو حفظ) — الشاشة الرئيسية تعيد البناء عليه.
  static final ValueNotifier<int> changed = ValueNotifier(0);

  static Future<void> load() async {
    try {
      final v = await _s.read(key: _key);
      if (v != null && v.trim().isNotEmpty) {
        final ids = v
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (ids.isNotEmpty) current = ids;
      }
    } catch (_) {}
    changed.value++;
  }

  static Future<void> save(List<String> ids) async {
    current = List.of(ids);
    try {
      await _s.write(key: _key, value: ids.join(','));
    } catch (_) {}
    changed.value++;
  }
}
