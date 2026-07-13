import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'services/notification_sync.dart';
import 'services/push_service.dart';
import 'services/chat_prefs.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/jasir_spinner.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// يوجّه الضغط على الإشعار للشاشة المناسبة (دواء → تأكيد، صباح → المحادثة).
/// [attempt]: لو المُنقّل ما جهز بعد (إقلاع بارد بطيء) نعيد المحاولة بدل
/// ما نُسقط الضغطة بصمت — كانت تضيع لو 600ms ما كفت.
void handleNotificationPayload(String payload, [int attempt = 0]) {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) {
    if (attempt < 12) {
      Future.delayed(const Duration(milliseconds: 500),
          () => handleNotificationPayload(payload, attempt + 1));
    }
    return;
  }
  if (payload.startsWith('med|')) {
    final parts = payload.split('|');
    final id = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    // اسم الدواء قد يحتوي «|» — نضم الباقي بدل أخذ الجزء الثالث فقط
    final name = parts.length > 2 ? parts.sublist(2).join('|') : 'دوائك';
    if (id > 0) {
      // يفتح المحادثة نفسها: جاسر يسأل عن الجرعة داخل المحادثة (تبقى في السجل)
      nav.push(MaterialPageRoute(
          builder: (_) => ChatPage(pendingMedId: id, pendingMedName: name)));
    }
  } else if (payload == 'morning') {
    nav.push(MaterialPageRoute(builder: (_) => const ChatPage(forceMorning: true)));
  } else if (payload == 'inbox') {
    // تقرير/رسالة من السيرفر — المحادثة تسحب الوارد الجديد وتعرضه
    nav.push(MaterialPageRoute(builder: (_) => const ChatPage()));
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.init();
  NotificationService.onSelectPayload = handleNotificationPayload;
  ThemeController.instance.load();
  ChatPrefs.load();
  runApp(const JasirApp());
}

class JasirApp extends StatefulWidget {
  const JasirApp({super.key});

  @override
  State<JasirApp> createState() => _JasirAppState();
}

class _JasirAppState extends State<JasirApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // سجّل لحظة مغادرة التطبيق (بداية عدّ الخمول)
      ApiClient.instance.touch();
    } else if (state == AppLifecycleState.resumed) {
      _checkIdleTimeout();
    }
  }

  /// عند العودة للتطبيق: لو مرّت أكثر من 6 ساعات على آخر استخدام → تسجيل خروج.
  Future<void> _checkIdleTimeout() async {
    final hasToken = (await ApiClient.instance.getToken()) != null;
    if (!hasToken) return;
    if (await ApiClient.instance.isSessionExpired()) {
      await ApiClient.instance.logout();
      rootNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ApiClient.instance.touch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;
    return AnimatedBuilder(
      animation: tc,
      builder: (context, _) => MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: 'جاسر',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: tc.mode,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: TextScaler.linear(tc.fontScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const _StartupGate(),
      ),
    );
  }
}

/// يقرر أول شاشة تظهر: تسجيل الدخول أو الشاشة الرئيسية، حسب وجود جلسة صالحة.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> with WidgetsBindingObserver {
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiClient.instance.isLoggedIn().then((v) {
      if (mounted) setState(() => _loggedIn = v);
      // بعد التأكد من الدخول، اطلب إذن التنبيهات وजدولها من بيانات جاسر
      if (v == true) {
        NotificationSync.run();
        // تسجيل جهازك لإشعارات Push من السيرفر (APNs مباشرة) + توجيه ضغطاتها
        PushService.init();
        // لو فُتح التطبيق بالضغط على إشعار (كان مغلقاً) — وجّه للشاشة المناسبة
        NotificationService.handleAppLaunch();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // عند رجوع المستخدم للتطبيق، أعد جدولة التنبيهات لتشمل أي مواعيد/أدوية
    // أُضيفت من الواتساب أو من التطبيق (تنبيهات على التطبيق بدل الواتساب).
    if (state == AppLifecycleState.resumed && _loggedIn == true) {
      NotificationSync.run();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn == null) {
      return const Scaffold(body: Center(child: JasirSpinner(size: 56)));
    }
    return _loggedIn! ? const HomeScreen() : const LoginScreen();
  }
}
