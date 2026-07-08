import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_client.dart';

/// رد واحد من جاسر — إما نص، أو وسائط (صورة/PDF) مثل صورة وثيقة محفوظة.
class ChatReply {
  final bool isMedia;
  final String? text;
  final String? mimetype;
  final Uint8List? bytes;
  final String? filename;
  final String? caption;

  ChatReply.text(this.text)
      : isMedia = false, mimetype = null, bytes = null, filename = null, caption = null;

  ChatReply.media({required this.mimetype, required this.bytes, this.filename, this.caption})
      : isMedia = true, text = null;
}

/// يرسل رسالة نصية أو وسائط (صورة/PDF/صوت) لنفس محرك الذكاء الاصطناعي
/// في جاسر ويرجع ردوده — بنفس منطق واتساب بالضبط.
class ChatService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<ChatReply>> sendMessage(String text) async {
    final res = await _dio.post('/api/v1/chat/message', data: {'message': text});
    final data = res.data as Map<String, dynamic>;
    return _extractReplies(data);
  }

  /// يرسل ملف (صورة/PDF/صوت) كـ base64 مع تعليق اختياري.
  Future<List<ChatReply>> sendMedia({
    required Uint8List bytes,
    required String mimetype,
    String? caption,
  }) async {
    final res = await _dio.post('/api/v1/chat/media', data: {
      'mimetype': mimetype,
      'data': base64Encode(bytes),
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    });
    final data = res.data as Map<String, dynamic>;
    return _extractReplies(data);
  }

  List<ChatReply> _extractReplies(Map<String, dynamic> data) {
    final list = data['replies'] as List? ?? [];
    return list.map<ChatReply>((e) {
      if (e is Map) {
        final type = e['type']?.toString();
        if (type == 'media') {
          final b64 = e['data']?.toString();
          Uint8List? bytes;
          try {
            if (b64 != null) bytes = base64Decode(b64);
          } catch (_) {}
          return ChatReply.media(
            mimetype: e['mimetype']?.toString() ?? 'application/octet-stream',
            bytes: bytes ?? Uint8List(0),
            filename: e['filename']?.toString(),
            caption: e['caption']?.toString(),
          );
        }
        return ChatReply.text(e['text']?.toString() ?? '');
      }
      // توافقية قديمة: عنصر نصي مباشر
      return ChatReply.text(e.toString());
    }).toList();
  }
}
