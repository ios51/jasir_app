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
import 'screens/worship/worship_screen.dart';
import 'services/worship_prefs.dart';
import 'services/services_prefs.dart';

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
    // توجيه ضغط الإشعار غير موثوق على iOS — نعتمد على الحقيقة من السيرفر:
    // نفتح المحادثة على الجرعة المستحقّة فعلاً (نفس المسار الموحّد).
    // بلا force: الحارس _lastPendingMedKey يمنع فتحها مرتين لو سبقها فحص
    // الإقلاع (كان force يسبّب فتح شاشتين عند الإقلاع البارد).
    openChatIfPendingMed();
  } else if (payload == 'morning') {
    nav.push(MaterialPageRoute(builder: (_) => const ChatPage(forceMorning: true)));
  } else if (payload == 'inbox') {
    // تقرير/رسالة من السيرفر — المحادثة تسحب الوارد الجديد وتعرضه
    nav.push(MaterialPageRoute(builder: (_) => const ChatPage()));
  } else if (payload == 'worship') {
    nav.push(MaterialPageRoute(builder: (_) => const WorshipScreen()));
  } else if (payload.startsWith('adhkar|')) {
    final t = payload.split('|').last; // m | e
    nav.push(MaterialPageRoute(builder: (_) => WorshipScreen(openTarget: t)));
  } else if (payload == 'faidah') {
    // فائدة اليوم تُعرض داخل المحادثة (تبقى في السجل)
    nav.push(MaterialPageRoute(builder: (_) => const ChatPage(showFaidah: true)));
  }
}

// ── فتح المحادثة تلقائياً عند وجود جرعة مستحقّة غير مؤكّدة ──────────
// الحل الموثوق لعطل «ضغط إشعار الدواء يوديني للأدوية بدل المحادثة»:
// بدل الاعتماد على توجيه الإشعار (يفشل على iOS)، نسأل السيرفر عن أي جرعة
// حان وقتها ولم تؤكَّد، ونفتح المحادثة عليها — عند الإقلاع/الرجوع أو ضغط
// إشعار الدواء. الحارس _lastPendingMedKey يمنع فتحها أكثر من مرة للجرعة.
bool _pendingMedNavigating = false;
String? _lastPendingMedKey;
Future<void> openChatIfPendingMed({bool force = false}) async {
  if (_pendingMedNavigating) return;
  _pendingMedNavigating = true;
  try {
    final res = await ApiClient.instance.dio.get('/api/v1/meds/pending-confirm');
    final list = (res.data is List) ? res.data as List : [];
    if (list.isEmpty) { _lastPendingMedKey = null; return; }
    final m = Map<String, dynamic>.from(list.first as Map);
    final id = int.tryParse((m['medId'] ?? '').toString()) ?? 0;
    final name = (m['name'] ?? 'دوائك').toString();
    final key = '$id|${m['schedTime']}';
    if (id <= 0) return;
    if (!force && key == _lastPendingMedKey) return; // فُتحت لهذه الجرعة سابقاً
    _lastPendingMedKey = key;
    void go([int attempt = 0]) {
      final nav = rootNavigatorKey.currentState;
      if (nav == null) {
        if (attempt < 12) Future.delayed(const Duration(milliseconds: 500), () => go(attempt + 1));
        return;
      }
      nav.push(MaterialPageRoute(
          builder: (_) => ChatPage(pendingMedId: id, pendingMedName: name)));
    }
    go();
  } catch (_) {/* بلا شبكة — يُعاد عند الفتح القادم */}
  finally { _pendingMedNavigating = false; }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.init();
  NotificationService.onSelectPayload = handleNotificationPayload;
  ThemeController.instance.load();
  ChatPrefs.load();
  WorshipPrefs.load(); // تفضيلات العبادة (مواقيت/أذكار/ذكر/فائدة)
  ServicesPrefs.load(); // ترتيب بطاقات الخدمات المختار
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
        // لو فيه جرعة مستحقّة الآن — افتح المحادثة عليها تلقائياً
        openChatIfPendingMed();
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
      openChatIfPendingMed(); // جرعة حان وقتها والتطبيق بالخلفية → افتح المحادثة
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
