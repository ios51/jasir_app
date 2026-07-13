import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// تخزين التقارير الطبية **على الجهاز نفسه** (خصوصية) — بحد أقصى تقريرين
/// لكل ملف طبي (مستشفى). لا تُرفع للسيرفر إطلاقاً. الفهرس محفوظ محلياً.
class MedicalReport {
  final String name;
  final String path;
  const MedicalReport(this.name, this.path);
  Map<String, dynamic> toJson() => {'name': name, 'path': path};
  static MedicalReport fromJson(Map m) =>
      MedicalReport((m['name'] ?? '').toString(), (m['path'] ?? '').toString());
}

class MedicalReportsStore {
  static const int maxPerFile = 2;
  static Map<String, List<MedicalReport>>? _cache;

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/medical_reports');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> _manifest() async {
    final d = await _dir();
    return File('${d.path}/index.json');
  }

  static Future<Map<String, List<MedicalReport>>> _all() async {
    if (_cache != null) return _cache!;
    final map = <String, List<MedicalReport>>{};
    try {
      final f = await _manifest();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        raw.forEach((k, v) {
          map[k] = (v as List).map((e) => MedicalReport.fromJson(e as Map)).toList();
        });
      }
    } catch (_) {}
    _cache = map;
    return map;
  }

  static Future<void> _persist(Map<String, List<MedicalReport>> map) async {
    try {
      final f = await _manifest();
      final out = <String, dynamic>{};
      map.forEach((k, v) => out[k] = v.map((r) => r.toJson()).toList());
      await f.writeAsString(jsonEncode(out));
    } catch (_) {}
  }

  /// تقارير ملف طبي معيّن.
  static Future<List<MedicalReport>> list(String key) async {
    final map = await _all();
    return List<MedicalReport>.from(map[key] ?? const []);
  }

  /// يضيف تقريراً (ينسخ الملف داخل مجلد التطبيق الخاص). يرجع الخطأ نصاً أو null.
  static Future<String?> add(String key, String sourcePath, String displayName) async {
    final map = await _all();
    final cur = map[key] ?? <MedicalReport>[];
    if (cur.length >= maxPerFile) return 'الحد الأقصى تقريران لكل ملف';
    try {
      final d = await _dir();
      final ext = displayName.contains('.') ? displayName.split('.').last : 'dat';
      final dest = '${d.path}/${key}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(sourcePath).copy(dest);
      cur.add(MedicalReport(displayName, dest));
      map[key] = cur;
      await _persist(map);
      return null;
    } catch (e) {
      return 'تعذّر حفظ التقرير';
    }
  }

  /// يحذف تقريراً (الملف + الفهرس).
  static Future<void> remove(String key, MedicalReport r) async {
    final map = await _all();
    final cur = map[key];
    if (cur == null) return;
    cur.removeWhere((x) => x.path == r.path);
    map[key] = cur;
    try {
      final f = File(r.path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await _persist(map);
  }
}
