import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// مشغّل الأذان الكامل — غلاف مفرد (singleton) حول [AudioPlayer].
/// يشغّل ملف `assets/sounds/adhan_full.m4a` (مدة ~4:52) داخل التطبيق عند
/// دخول وقت الصلاة (فتح/عودة التطبيق أو الضغط على إشعار الصلاة).
///
/// - [playFullAdhan] يحرس ضد التشغيل المزدوج عبر [_isPlaying].
/// - [stop] يوقف ويصفّر الحالة.
/// - [playing] مُنبّه لتحديث الواجهة (شريط «إيقاف الأذان»).
/// - على iOS تستخدم audioplayers فئة الجلسة `playback` (تُعاد فرضها قبل كل
///   تشغيل) فيُسمع الأذان حتى مع مفتاح الصامت، ومع UIBackgroundModes: audio
///   في Info.plist يكمل الأذان حتى لو قُفلت الشاشة أثناء تشغيله.
class AdhanPlayer {
  AdhanPlayer._() {
    // اشتراك واحد يدوم مع المفرد (بلا تسريب): يصفّر الحالة عند اكتمال الأذان.
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      playing.value = false;
    });
  }
  static final AdhanPlayer instance = AdhanPlayer._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  /// هل الأذان قيد التشغيل الآن؟
  bool get isPlaying => _isPlaying;

  /// يتغيّر إلى true عند بدء التشغيل وfalse عند الإيقاف/الاكتمال — تستمع له
  /// الواجهة لإظهار/إخفاء شريط الإيقاف.
  final ValueNotifier<bool> playing = ValueNotifier<bool>(false);

  /// يشغّل الأذان الكامل مرة واحدة. لو كان يعمل بالفعل → تجاهُل (حارس مزدوج).
  /// يُرجع true عند نجاح بدء التشغيل (أو إن كان يعمل بالفعل)، وfalse عند
  /// الفشل — حتى لا يُخزَّن حارس «مرة لكل صلاة» لأذانٍ لم يُسمَع فعلاً.
  Future<bool> playFullAdhan() async {
    if (_isPlaying) return true;
    _isPlaying = true;
    playing.value = true;
    try {
      // إعادة فرض فئة playback صراحةً قبل كل تشغيل: تسجيل رسالة صوتية في
      // المحادثة (record) يحوّل جلسة iOS إلى playAndRecord فيخرج الأذان من
      // سماعة الأذن خافتاً أو لا يتجاوز الصامت. هذا يعيده لمكبّر الصوت.
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {},
        ),
      ));
      await _player.stop(); // نظافة أي جلسة سابقة عالقة
      await _player.play(AssetSource('sounds/adhan_full.m4a'));
      return true;
    } catch (_) {
      // فشل التشغيل (ملف مفقود/جلسة صوت) — صفّر الحالة بأمان.
      _isPlaying = false;
      playing.value = false;
      return false;
    }
  }

  /// يوقف الأذان فوراً ويصفّر الحالة.
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    _isPlaying = false;
    playing.value = false;
  }
}

/// حارس «مرة واحدة لكل صلاة» — يخزّن آخر مفتاح صلاة شُغّل (`YYYY-MM-DD|اسم`)
/// عبر [FlutterSecureStorage] بنفس أسلوب `worship_prefs.dart`، فلا يتكرر الأذان
/// لنفس الصلاة في نفس اليوم من مسارَي الفتح والضغط على الإشعار.
class AdhanGuard {
  static const FlutterSecureStorage _s = FlutterSecureStorage();
  static const String _key = 'jasir_adhan_last_played';

  /// آخر مفتاح صلاة شُغّل (أو null).
  static Future<String?> lastPlayedKey() async {
    try {
      return await _s.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  /// يخزّن مفتاح الصلاة الحالي بعد تشغيلها.
  static Future<void> setLastPlayedKey(String value) async {
    try {
      await _s.write(key: _key, value: value);
    } catch (_) {}
  }
}
