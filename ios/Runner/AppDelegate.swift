import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// قناة تمرير توكن APNs وضغطات إشعارات الـPush إلى فلاتر
  static var pushChannel: FlutterMethodChannel?
  /// التوكن قد يصل من أبل قبل جاهزية فلاتر — نخزنه ونسلمه عند الطلب
  static var pendingToken: String?
  /// ضغطة إشعار فتحت التطبيق وهو مغلق — تُسلَّم عند الطلب
  static var pendingTap: String?
  /// وقت الضغطة — نسقطها إن تجاوزت ١٠ دقائق (تطابق مهلة جانب فلاتر)
  static var pendingTapAt: Date?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // تسجيل الجهاز لدى أبل (إذن الإشعارات نفسه يُطلب من جهة فلاتر)
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "JasirPush") {
      let channel = FlutterMethodChannel(name: "jasir/push", binaryMessenger: registrar.messenger())
      AppDelegate.pushChannel = channel
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "getToken":
          result(AppDelegate.pendingToken)
        case "getPendingTap":
          var tap = AppDelegate.pendingTap
          if let at = AppDelegate.pendingTapAt, Date().timeIntervalSince(at) > 600 {
            tap = nil
          }
          AppDelegate.pendingTap = nil
          AppDelegate.pendingTapAt = nil
          result(tap)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  // توكن APNs وصل من أبل → نمرره لفلاتر ليسجله في سيرفر جاسر
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    AppDelegate.pendingToken = token
    AppDelegate.pushChannel?.invokeMethod("onToken", arguments: token)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // عرض كل إشعارات جاسر حتى والتطبيق مفتوح في المقدمة.
  // إصلاح: كان يعرض فقط إشعارات Push (التي تحمل مفتاح "jasir")، فكانت
  // الإشعارات المحلية — ومنها زر «جرّب تنبيهاً الآن» — تُكتم على iOS وهو
  // بالمقدمة فيبدو أن الزر «ما يسوي شي». الآن نعرضها كلها.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // ضغط المستخدم على أي إشعار → نمرر الوجهة لفلاتر (محادثة/أذكار/صلاة...)
  // Push من السيرفر يحمل الوجهة في userInfo["jasir"]["payload"]،
  // والإشعار المحلي (flutter_local_notifications) يحملها في userInfo["payload"].
  // كنا نمرر Push فقط، فكانت ضغطة الإشعار المحلي تضيع عند الإقلاع البارد
  // (سباق تسجيل الإضافة) ويفتح التطبيق على الرئيسية. الآن نلتقطها هنا
  // بشكل حتمي ونسلمها عبر نفس القناة — وفلاتر يزيل أي ازدواج.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    var payload: String?
    if let jasir = userInfo["jasir"] as? [String: Any],
       let p = jasir["payload"] as? String {
      payload = p
    } else if let p = userInfo["payload"] as? String, !p.isEmpty {
      payload = p
    }
    if let p = payload {
      AppDelegate.pendingTap = p
      AppDelegate.pendingTapAt = Date()
      AppDelegate.pushChannel?.invokeMethod("onPushTap", arguments: p)
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
