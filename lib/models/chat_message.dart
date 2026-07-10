import 'dart:typed_data';

/// رسالة واحدة داخل محادثة جاسر — من المستخدم أو رد من الذكاء الاصطناعي.
/// قد تكون نصية عادية، أو وسائط (صورة/PDF) يرسلها جاسر (مثلاً صورة وثيقة محفوظة).
class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime time;

  /// إذا كانت الرسالة تحتوي ملف (صورة أو PDF) مرسل من جاسر
  final Uint8List? mediaBytes;
  final String? mediaMimetype;
  final String? mediaFilename;

  ChatMessage({
    required this.text,
    required this.isMe,
    DateTime? time,
    this.mediaBytes,
    this.mediaMimetype,
    this.mediaFilename,
  }) : time = time ?? DateTime.now();

  bool get hasMedia => mediaBytes != null && mediaMimetype != null;
  bool get isImage => mediaMimetype?.startsWith('image/') == true;
  bool get isPdf => mediaMimetype == 'application/pdf';

  /// للحفظ على الجهاز — نحفظ النص والاتجاه والوقت فقط (بدون بايتات الوسائط
  /// حتى لا تتضخّم الذاكرة)؛ رسالة الوسائط تُحفظ كسطر نصّي بوصفها.
  Map<String, dynamic> toJson() => {
        't': (hasMedia && text.isEmpty) ? (mediaFilename ?? '📎 مرفق') : text,
        'me': isMe,
        'ts': time.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: (j['t'] as String?) ?? '',
        isMe: (j['me'] as bool?) ?? false,
        time: DateTime.tryParse((j['ts'] as String?) ?? ''),
      );
}
