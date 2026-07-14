import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// خدمة التنبيهات المحلية لجاسر — تطلب الإذن وتجدول تنبيهات
/// المواعيد والمهام ورسالة الصباح على الجهاز (بتوقيت الرياض).
class NotificationService {
  NotificationService._();
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  /// يُستدعى عند الضغط على إشعار — يمرّر الـpayload (main.dart يوجّه الشاشة).
  static void Function(String payload)? onSelectPayload;

  /// آخر حمولة إشعار (ضغطة/إقلاع) + وقتها — تُعاد بعد الدخول لو ضاعت
  /// بسبب انتهاء الجلسة (خمول 6 ساعات → شاشة الدخول تبتلع التوجيه).
  static String? _pendingPayload;
  static DateTime? _pendingAt;
  static void _stash(String p) { _pendingPayload = p; _pendingAt = DateTime.now(); }

  /// يسترجع الحمولة المعلّقة إن كانت حديثة (≤ 10 دقائق — تكفي رحلة OTP
  /// كاملة حتى لو تأخّر رمز الواتساب) ويمسحها — تُستدعى بعد نجاح الدخول
  /// لإعادة التوجيه الضائع. الحدّ الزمني يمنع إعادة تشغيل حمولة قديمة
  /// عند دخولٍ لاحق لا علاقة له بالإشعار.
  static String? takePendingPayload() {
    final p = _pendingPayload;
    final t = _pendingAt;
    _pendingPayload = null;
    _pendingAt = null;
    if (p == null || t == null) return null;
    if (DateTime.now().difference(t) > const Duration(minutes: 10)) return null;
    return p;
  }

  /// نقطة تسليم موحّدة لأي ضغطة إشعار (محلي أو Push، من فلاتر أو من
  /// الجانب الأصلي): تخزّن الحمولة (للاستعادة بعد الدخول لو ضاعت بسبب
  /// انتهاء الجلسة) ثم توجّه. إزالة الازدواج تتم في handleNotificationPayload.
  static void deliverPayload(String p) {
    _stash(p);
    onSelectPayload?.call(p);
  }

  static void _handleResponse(NotificationResponse r) {
    final p = r.payload;
    if (p != null && p.isNotEmpty) deliverPayload(p);
  }

  static Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    } catch (_) {}
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: _handleResponse,
    );
    _inited = true;
  }

  static bool _launchHandled = false;

  /// لو فُتح التطبيق من إشعار (كان مغلقاً تماماً) — وجّه بعد الإقلاع.
  /// _launchHandled: على أندرويد قد تبقى نية الإقلاع محفوظة، فإعادة إنشاء
  /// النشاط (من قائمة «الأخيرة») كانت تعيد فتح نفس الشاشة مرة ثانية.
  static Future<void> handleAppLaunch() async {
    if (_launchHandled) return;
    _launchHandled = true;
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      final p = details?.notificationResponse?.payload;
      if (p != null && p.isNotEmpty) {
        _stash(p);
        // تأخير بسيط حتى يجهز المُنقّل (main.dart يعيد المحاولة لو ما جهز)
        Future.delayed(const Duration(milliseconds: 600), () => deliverPayload(p));
      }
    }
  }

  /// مثل [handleAppLaunch] لكن يخزّن الحمولة فقط بلا توجيه — يُستدعى عند
  /// الإقلاع على شاشة الدخول (جلسة منتهية): التوجيه الفوري بلا فائدة لأن
  /// الدخول سيمسح المكدّس، فتُحفظ الحمولة وتُعاد بعد نجاح الدخول (OTP).
  static Future<void> stashAppLaunch() async {
    if (_launchHandled) return;
    _launchHandled = true;
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      final p = details?.notificationResponse?.payload;
      if (p != null && p.isNotEmpty) _stash(p);
    }
  }

  /// يطلب إذن التنبيهات صراحةً (يظهر مربّع السماح على iOS/Android).
  static Future<void> requestPermission() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'jasir_reminders',
      'تذكيرات جاسر',
      channelDescription: 'تنبيهات المواعيد والمهام ورسالة الصباح',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// هل رُكِّبت ملفات صوت الأذان في التطبيق؟ (تُضبط true لما توفّر الملفات:
  /// iOS: adhan.caf ضمن الحزمة، Android: res/raw/adhan). حتى ذلك الحين
  /// نستخدم النغمة الافتراضية بأمان بدل الإشارة لملف غير موجود.
  static const bool _adhanBundled = true;

  /// تفاصيل التنبيه حسب الصوت المطلوب:
  /// 'adhan' → صوت الأذان (إن رُكِّب)، وإلا/‏'default' → الافتراضي.
  static NotificationDetails _detailsForSound(String? sound) {
    if (sound == 'adhan' && _adhanBundled) {
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          'jasir_adhan',
          'أذان الصلاة',
          channelDescription: 'تنبيه الأذان بصوته',
          importance: Importance.max,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('adhan'),
        ),
        iOS: DarwinNotificationDetails(sound: 'adhan.caf'),
      );
    }
    return _details;
  }

  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// يلغي تنبيهاً واحداً بمعرّفه.
  static Future<void> cancelId(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// يلغي فقط التنبيهات التي تملكها المزامنة (id أقل من 50000).
  /// إصلاح: cancelAll كانت تمسح أيضاً تنبيه «أعطني ١٠ دقائق»
  /// (id = 50000+medId) لو فتح المستخدم التطبيق خلال العشر دقائق —
  /// فيضيع التذكير الموعود بصمت.
  static Future<void> cancelSyncOwned() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id < 50000) await _plugin.cancel(p.id);
    }
  }

  static Future<void> showNow(int id, String title, String body, {String? payload, String? sound}) async {
    await init();
    await _plugin.show(id, title, body, _detailsForSound(sound), payload: payload);
  }

  /// يجدول تنبيهاً في وقت محدد. daily=true يكرّره يومياً في نفس الساعة.
  /// payload يُمرَّر عند الضغط (مثل "med|3|فلازول" أو "morning").
  /// sound='adhan' لتنبيه الأذان بصوته (إن رُكِّبت ملفاته).
  static Future<void> scheduleAt(
      int id, String title, String body, DateTime when,
      {bool daily = false, String? payload, String? sound}) async {
    await init();
    if (!daily && when.isBefore(DateTime.now())) return;
    final tzTime = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      _detailsForSound(sound),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: daily ? DateTimeComponents.time : null,
      payload: payload,
    );
  }
}
