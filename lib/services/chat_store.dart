import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/chat_message.dart';

/// حفظ محادثة جاسر على الجهاز حتى لا تضيع عند إغلاق التطبيق.
/// يُخزَّن آخر [_maxKept] رسالة نصية فقط (بدون بايتات الوسائط) بشكل آمن.
class ChatStore {
  static const _key = 'jasir_chat_history_v1';
  static const _maxKept = 120;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<List<ChatMessage>> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<ChatMessage> messages) async {
    try {
      final kept = messages.length > _maxKept
          ? messages.sublist(messages.length - _maxKept)
          : messages;
      final data = kept.map((m) => m.toJson()).toList();
      await _storage.write(key: _key, value: jsonEncode(data));
    } catch (_) {
      // تجاهل أخطاء الحفظ حتى لا تعطّل المحادثة
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
