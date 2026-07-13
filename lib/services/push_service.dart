import 'package:flutter/services.dart';
import 'api_client.dart';
import 'notification_service.dart';

/// خدمة إشعارات الـPush (APNs مباشرة — بدون Firebase):
/// - تستلم توكن الجهاز من الجانب الأصلي (Swift) وتسجله في سيرفر جاسر.
/// - توجه ضغطات إشعارات الـPush لنفس مسار توجيه الإشعارات المحلية.
class PushService {
  PushService._();
  static const _channel = MethodChannel('jasir/push');
  static bool _inited = false;

  /// تُستدعى بعد تسجيل الدخول (تسجيل التوكن يحتاج جلسة صالحة).
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onToken':
          await _registerToken(call.arguments as String?);
          break;
        case 'onPushTap':
          final p = call.arguments as String?;
          if (p != null && p.isNotEmpty) {
            NotificationService.onSelectPayload?.call(p);
          }
          break;
      }
    });

    // التوكن قد يكون وصل من أبل قبل تهيئة فلاتر — نطلبه صراحة
    try {
      final t = await _channel.invokeMethod<String>('getToken');
      await _registerToken(t);
    } catch (_) {}

    // ضغطة إشعار فتحت التطبيق وهو مغلق تماماً — نوجهها بعد جاهزية الواجهة
    try {
      final tap = await _channel.invokeMethod<String>('getPendingTap');
      if (tap != null && tap.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 600),
            () => NotificationService.onSelectPayload?.call(tap));
      }
    } catch (_) {}
  }

  static Future<void> _registerToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await ApiClient.instance.dio
          .post('/api/v1/push/token', data: {'token': token});
    } catch (_) {
      // فشل التسجيل (سيرفر/شبكة) — يُعاد تلقائياً مع أول إقلاع قادم
    }
  }
}
