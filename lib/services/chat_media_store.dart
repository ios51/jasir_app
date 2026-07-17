import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// تخزين وسائط المحادثة (صور البث وصور جاسر) كملفات دائمة على الجهاز —
/// داخل حاوية التطبيق الخاصة (لا تظهر في استوديو الصور، وتُحذف مع التطبيق).
/// السجل يحفظ المسار فقط؛ التنظيف يتم مع تقليم السجل (أقدم من ١٢٠ رسالة).
class ChatMediaStore {
  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/chat_media');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// يحفظ بايتات صورة ويرجع مسار الملف (null عند الفشل — تُعرض من الذاكرة فقط).
  static Future<String?> save(Uint8List bytes, {String ext = 'jpg'}) async {
    try {
      final dir = await _dir();
      final f = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}.$ext');
      await f.writeAsBytes(bytes, flush: true);
      return f.path;
    } catch (_) {
      return null;
    }
  }

  /// يحذف كل ملف لم يعد له رسالة في السجل (بعد تقليم الـ١٢٠ رسالة).
  static Future<void> cleanupExcept(Set<String> keptPaths) async {
    try {
      final dir = await _dir();
      await for (final f in dir.list()) {
        if (f is File && !keptPaths.contains(f.path)) {
          try { await f.delete(); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// مسح كامل (مع مسح المحادثة).
  static Future<void> clearAll() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
