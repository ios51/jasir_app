import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// تفضيلات وحدة العبادة (تُحفظ على الجهاز):
/// المدينة، تفعيل الصلاة/الأذان/الإقامة، أذكار الصباح/المساء وأوقاتها،
/// الذكر المتكرر وفترته، وفائدة اليوم ووقتها.
class WorshipPrefs {
  static const FlutterSecureStorage _s = FlutterSecureStorage();
  static const _k = 'jasir_worship_';

  // القيم (مع افتراضاتها)
  static int cityIndex = 0; // الرياض
  static bool prayerEnabled = true;
  static bool adhanEnabled = true; // تنبيه الأذان
  static bool iqamaEnabled = true; // تنبيه الإقامة
  static int iqamaDelay = 15; // دقائق بعد الأذان
  static bool adhkarEnabled = true;
  static String morningTime = '06:00'; // أذكار الصباح
  static String eveningTime = '18:00'; // أذكار المساء
  static bool dhikrEnabled = false; // ذكر متكرر
  static int dhikrIntervalHours = 1; // كل ساعة
  static bool faidahEnabled = true; // فائدة اليوم
  static String faidahTime = '09:00';
  static String sound = 'default'; // نغمة التنبيه: default | adhan

  static final ValueNotifier<int> changed = ValueNotifier(0);

  static bool _b(String? v, bool d) => v == null ? d : v == '1';
  static int _i(String? v, int d) => int.tryParse(v ?? '') ?? d;

  /// أول تحميل للتفضيلات (يُخزَّن ليُنتظر). يمنع سباق الإقلاع البارد:
  /// maybePlayAdhan كانت تقرأ sound='default' قبل اكتمال القراءة من التخزين
  /// فيسقط الأذان بصمت. من ينتظر ensureLoaded يضمن اكتمال أول تحميل.
  static Future<void>? _loadFuture;
  static Future<void> ensureLoaded() => _loadFuture ??= load();

  static Future<void> load() async {
    try {
      cityIndex = _i(await _s.read(key: '${_k}city'), 0);
      prayerEnabled = _b(await _s.read(key: '${_k}prayer'), true);
      adhanEnabled = _b(await _s.read(key: '${_k}adhan'), true);
      iqamaEnabled = _b(await _s.read(key: '${_k}iqama'), true);
      iqamaDelay = _i(await _s.read(key: '${_k}iqamaDelay'), 15);
      adhkarEnabled = _b(await _s.read(key: '${_k}adhkar'), true);
      morningTime = (await _s.read(key: '${_k}mTime')) ?? '06:00';
      eveningTime = (await _s.read(key: '${_k}eTime')) ?? '18:00';
      dhikrEnabled = _b(await _s.read(key: '${_k}dhikr'), false);
      dhikrIntervalHours = _i(await _s.read(key: '${_k}dhikrH'), 1);
      faidahEnabled = _b(await _s.read(key: '${_k}faidah'), true);
      faidahTime = (await _s.read(key: '${_k}faidahTime')) ?? '09:00';
      sound = (await _s.read(key: '${_k}sound')) ?? 'default';
    } catch (_) {}
  }

  static Future<void> save() async {
    try {
      await _s.write(key: '${_k}city', value: '$cityIndex');
      await _s.write(key: '${_k}prayer', value: prayerEnabled ? '1' : '0');
      await _s.write(key: '${_k}adhan', value: adhanEnabled ? '1' : '0');
      await _s.write(key: '${_k}iqama', value: iqamaEnabled ? '1' : '0');
      await _s.write(key: '${_k}iqamaDelay', value: '$iqamaDelay');
      await _s.write(key: '${_k}adhkar', value: adhkarEnabled ? '1' : '0');
      await _s.write(key: '${_k}mTime', value: morningTime);
      await _s.write(key: '${_k}eTime', value: eveningTime);
      await _s.write(key: '${_k}dhikr', value: dhikrEnabled ? '1' : '0');
      await _s.write(key: '${_k}dhikrH', value: '$dhikrIntervalHours');
      await _s.write(key: '${_k}faidah', value: faidahEnabled ? '1' : '0');
      await _s.write(key: '${_k}faidahTime', value: faidahTime);
      await _s.write(key: '${_k}sound', value: sound);
    } catch (_) {}
    changed.value++;
  }
}
