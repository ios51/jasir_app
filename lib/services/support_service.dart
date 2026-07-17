import 'package:dio/dio.dart';
import 'api_client.dart';

/// رسالة تواصل: من المستخدم (اقتراح/شكوى/استفسار بموضوع ومضمون)
/// أو من الإدارة (رد/إعلان/رسالة إدارة — مع صورة اختيارية للبث).
class SupportMessage {
  final int id;
  final String sender; // 'user' | 'admin'
  final String kind; // suggestion|complaint|inquiry|reply|announcement|admin_broadcast
  final String subject;
  final String text;
  final String image; // base64 (فارغة إن لا صورة)
  final String createdAt;

  SupportMessage({required this.id, required this.sender, required this.kind, required this.subject, required this.text, required this.image, required this.createdAt});

  bool get isBroadcast => kind == 'announcement' || kind == 'admin_broadcast';
  bool get isAnnouncement => kind == 'announcement';
  bool get fromAdmin => sender == 'admin';

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: (j['id'] as num).toInt(),
        sender: (j['sender'] ?? 'user').toString(),
        kind: (j['kind'] ?? 'inquiry').toString(),
        subject: (j['subject'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        image: (j['image'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
      );
}

/// نتيجة محاولة الإرسال: نجاح أو متبقي على السماح (حد الـ٢٤ ساعة).
class SendOutcome {
  final bool ok;
  final int remainingMinutes;
  SendOutcome.ok()
      : ok = true,
        remainingMinutes = 0;
  SendOutcome.cooldown(this.remainingMinutes) : ok = false;
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

  Future<SendOutcome> send({required String subject, required String text, String kind = 'inquiry'}) async {
    try {
      await _dio.post('/api/v1/support/messages',
          data: {'subject': subject, 'text': text, 'kind': kind});
      return SendOutcome.ok();
    } on DioException catch (e) {
      if (e.response?.statusCode == 429 && e.response?.data is Map && e.response?.data['error'] == 'cooldown') {
        return SendOutcome.cooldown(((e.response?.data['remainingMinutes'] ?? 0) as num).toInt());
      }
      rethrow;
    }
  }

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

  /// بث عام: kind = 'announcement' (إعلان) أو 'admin_broadcast' (رسالة إدارة).
  Future<int> announce(String text, {String kind = 'announcement', String? imageB64}) async {
    final res = await _dio.post('/api/v1/support/admin/announce', data: {
      'text': text,
      'kind': kind,
      if (imageB64 != null && imageB64.isNotEmpty) 'image': imageB64,
    });
    return ((res.data['pushed'] ?? 0) as num).toInt();
  }
}
