import 'package:dio/dio.dart';
import 'api_client.dart';

/// رسالة تواصل: من المستخدم (اقتراح/شكوى/استفسار) أو من الإدارة (رد/إعلان).
class SupportMessage {
  final int id;
  final String sender; // 'user' | 'admin'
  final String kind; // suggestion|complaint|inquiry|reply|announcement
  final String text;
  final String createdAt;

  SupportMessage({required this.id, required this.sender, required this.kind, required this.text, required this.createdAt});

  bool get isAnnouncement => kind == 'announcement';
  bool get fromAdmin => sender == 'admin';

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: (j['id'] as num).toInt(),
        sender: (j['sender'] ?? 'user').toString(),
        kind: (j['kind'] ?? 'inquiry').toString(),
        text: (j['text'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
      );
}

/// محادثة مستخدم في لوحة الدعم (للمالك).
class SupportThread {
  final String userId;
  final String displayName;
  final String lastText;
  final String lastAt;
  final int unseen;

  SupportThread({required this.userId, required this.displayName, required this.lastText, required this.lastAt, required this.unseen});

  factory SupportThread.fromJson(Map<String, dynamic> j) => SupportThread(
        userId: (j['user_id'] ?? '').toString(),
        displayName: (j['display_name'] ?? 'مستخدم').toString(),
        lastText: (j['last_text'] ?? '').toString(),
        lastAt: (j['last_at'] ?? '').toString(),
        unseen: ((j['unseen'] ?? 0) as num).toInt(),
      );
}

class SupportService {
  final Dio _dio = ApiClient.instance.dio;

  /// هل المستخدم الحالي هو المالك؟ (تُظهر بلاطة «لوحة الدعم»)
  Future<bool> isAdmin() async {
    try {
      final res = await _dio.get('/api/v1/support/me');
      return res.data['isAdmin'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<SupportMessage>> myMessages() async {
    final res = await _dio.get('/api/v1/support/messages');
    return (res.data as List).map((e) => SupportMessage.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> send(String text, {String kind = 'inquiry'}) =>
      _dio.post('/api/v1/support/messages', data: {'text': text, 'kind': kind});

  // ── لوحة الدعم (المالك فقط) ──
  Future<List<SupportThread>> adminThreads() async {
    final res = await _dio.get('/api/v1/support/admin/threads');
    return (res.data as List).map((e) => SupportThread.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<SupportMessage>> adminThread(String userId) async {
    final res = await _dio.get('/api/v1/support/admin/threads/${Uri.encodeComponent(userId)}');
    return (res.data as List).map((e) => SupportMessage.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> adminReply(String userId, String text) =>
      _dio.post('/api/v1/support/admin/reply', data: {'userId': userId, 'text': text});

  Future<int> announce(String text) async {
    final res = await _dio.post('/api/v1/support/admin/announce', data: {'text': text});
    return ((res.data['pushed'] ?? 0) as num).toInt();
  }
}
