import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// خيار خلفية المحادثة.
class ChatBg {
  final String id;
  final String name;
  final List<Color>? colors; // تدرّج
  final Color? solid;
  const ChatBg(this.id, this.name, {this.colors, this.solid});
}

const List<ChatBg> chatBackgrounds = [
  ChatBg('default', 'افتراضي'),
  ChatBg('petrol', 'بترولي', colors: [Color(0xFF0E2A2E), Color(0xFF0B1220)]),
  ChatBg('navy', 'كحلي', solid: Color(0xFF0B1220)),
  ChatBg('slate', 'رمادي أزرق', colors: [Color(0xFF243447), Color(0xFF162435)]),
  ChatBg('cream', 'كريمي', solid: Color(0xFFF3EEE2)),
  ChatBg('sky', 'سماوي هادئ', colors: [Color(0xFFE6F4F7), Color(0xFFF7FAFC)]),
];

/// تفضيلات المحادثة: خلفية مختارة + إشارة مسح المحادثة (تُحفظ على الجهاز).
class ChatPrefs {
  static const _bgKey = 'jasir_chat_bg';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// معرّف الخلفية الحالية (يستمع له شاشة المحادثة).
  static final ValueNotifier<String> background = ValueNotifier('default');

  /// إشارة مسح: كل زيادة تعني "امسح المحادثة".
  static final ValueNotifier<int> clearSignal = ValueNotifier(0);

  static Future<void> load() async {
    try {
      final v = await _storage.read(key: _bgKey);
      if (v != null && v.isNotEmpty) background.value = v;
    } catch (_) {}
  }

  static Future<void> setBackground(String id) async {
    background.value = id;
    try { await _storage.write(key: _bgKey, value: id); } catch (_) {}
  }

  static void requestClear() => clearSignal.value++;

  /// زخرفة الخلفية للمعرّف المعطى (null = استخدم خلفية الثيم الافتراضية).
  static BoxDecoration? decoration(String id) {
    final bg = chatBackgrounds.firstWhere((b) => b.id == id,
        orElse: () => chatBackgrounds.first);
    if (bg.id == 'default') return null;
    if (bg.colors != null) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bg.colors!,
        ),
      );
    }
    return BoxDecoration(color: bg.solid);
  }
}
