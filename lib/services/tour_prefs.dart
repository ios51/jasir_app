import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// حالة الجولة التعريفية: تُعرض مرة واحدة، ولو انقطعت تُستأنف من مكانها.
class TourPrefs {
  static const _doneKey = 'jasir_tour_done';
  static const _stepKey = 'jasir_tour_step';
  static const FlutterSecureStorage _s = FlutterSecureStorage();

  static Future<bool> isDone() async {
    try {
      return await _s.read(key: _doneKey) == '1';
    } catch (_) {
      return true; // عند أي خلل تخزين لا نحبس المستخدم في جولة متكررة
    }
  }

  static Future<int> savedStep() async {
    try {
      return int.tryParse(await _s.read(key: _stepKey) ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> saveStep(int step) async {
    try {
      await _s.write(key: _stepKey, value: '$step');
    } catch (_) {}
  }

  static Future<void> markDone() async {
    try {
      await _s.write(key: _doneKey, value: '1');
      await _s.delete(key: _stepKey);
    } catch (_) {}
  }
}
