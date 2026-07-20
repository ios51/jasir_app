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

  /// مسار ملف الوسائط المحفوظ على الجهاز — يبقى بعد إعادة تشغيل التطبيق
  /// (بايتات الذاكرة لا تُخزَّن في السجل، الملف هو الدائم).
  final String? mediaPath;

  /// صورة من أصول التطبيق (assets) — تستخدمها الجولة التعريفية لصور الأقسام.
  final String? assetImage;

  ChatMessage({
    required this.text,
    required this.isMe,
    DateTime? time,
    this.mediaBytes,
    this.mediaMimetype,
    this.mediaFilename,
    this.mediaPath,
    this.assetImage,
  }) : time = time ?? DateTime.now();

  bool get hasMedia =>
      assetImage != null || ((mediaBytes != null || mediaPath != null) && mediaMimetype != null);
  bool get isImage => assetImage != null || mediaMimetype?.startsWith('image/') == true;
  bool get isPdf => mediaMimetype == 'application/pdf';

  /// للحفظ على الجهاز — النص والاتجاه والوقت، ومسار ملف الوسائط إن وُجد
  /// (البايتات نفسها لا تدخل السجل حتى لا يتضخم).
  Map<String, dynamic> toJson() => {
        't': (hasMedia && text.isEmpty) ? (mediaFilename ?? '📎 مرفق') : text,
        'me': isMe,
        'ts': time.toIso8601String(),
        if (mediaPath != null) 'mp': mediaPath,
        if (mediaPath != null && mediaMimetype != null) 'mm': mediaMimetype,
        if (assetImage != null) 'ai': assetImage,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: (j['t'] as String?) ?? '',
        isMe: (j['me'] as bool?) ?? false,
        time: DateTime.tryParse((j['ts'] as String?) ?? ''),
        mediaPath: j['mp'] as String?,
        mediaMimetype: j['mm'] as String?,
        assetImage: j['ai'] as String?,
      );
}
