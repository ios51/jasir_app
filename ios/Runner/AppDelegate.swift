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
          let tap = AppDelegate.pendingTap
          AppDelegate.pendingTap = nil
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

  // عرض إشعارات جاسر حتى والتطبيق مفتوح في المقدمة
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.content.userInfo["jasir"] != nil {
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .sound])
      } else {
        completionHandler([.alert, .sound])
      }
      return
    }
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  // ضغط المستخدم على إشعار Push → نمرر الوجهة لفلاتر (محادثة/صباح...)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    if let jasir = userInfo["jasir"] as? [String: Any],
       let payload = jasir["payload"] as? String {
      AppDelegate.pendingTap = payload
      AppDelegate.pushChannel?.invokeMethod("onPushTap", arguments: payload)
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
