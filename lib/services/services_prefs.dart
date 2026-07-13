import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ترتيب بطاقات «الخدمات» الذي يختاره المستخدم (يُحفظ على الجهاز).
class ServicesPrefs {
  static const _key = 'jasir_services_order';
  static const FlutterSecureStorage _s = FlutterSecureStorage();

  /// قائمة معرّفات البطاقات بالترتيب المختار (فارغة = الترتيب الافتراضي).
  static List<String> order = [];
  static final ValueNotifier<int> changed = ValueNotifier(0);

  static Future<void> load() async {
    try {
      final v = await _s.read(key: _key);
      if (v != null && v.isNotEmpty) order = v.split(',');
    } catch (_) {}
  }

  static Future<void> save(List<String> ids) async {
    order = ids;
    try { await _s.write(key: _key, value: ids.join(',')); } catch (_) {}
    changed.value++;
  }

  /// يرتّب [ids] الافتراضية حسب اختيار المستخدم؛ أي معرّف جديد (لم يكن وقت
  /// الحفظ) يُلحق في نهايته حتى لا تختفي خدمة أُضيفت لاحقاً.
  static List<String> apply(List<String> defaultIds) {
    if (order.isEmpty) return defaultIds;
    final known = order.where(defaultIds.contains).toList();
    final extras = defaultIds.where((id) => !known.contains(id));
    return [...known, ...extras];
  }
}
