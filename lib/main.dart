import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'services/notification_sync.dart';
import 'services/push_service.dart';
import 'services/chat_prefs.dart';
import 'theme/jasir_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/jasir_spinner.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/worship/worship_screen.dart';
import 'screens/worship/adhkar_reader_screen.dart';
import 'data/worship_content.dart';
import 'services/worship_prefs.dart';
import 'services/adhan_player.dart';
import 'utils/prayer_times.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// مفتاح مُرسِل السقالة الجذري — لإظهار شريط «إيقاف الأذان» من أي مكان.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// يوجّه الضغط على الإشعار للشاشة المناسبة (دواء → تأكيد، صباح → المحادثة).
/// [attempt]: لو المُنقّل ما جهز بعد (إقلاع بارد بطيء) نعيد المحاولة بدل
/// ما نُسقط الضغطة بصمت — كانت تضيع لو 600ms ما كفت.
/// إزالة ازدواج: نفس الضغطة قد تصل من مسارين (إضافة فلاتر + قناة الجانب
/// الأصلي في AppDelegate) — نتجاهل نفس الحمولة إن تكررت خلال ثوانٍ.
String? _lastHandledPayload;
DateTime? _lastHandledAt;

void handleNotificationPayload(String payload, [int attempt = 0]) {
  if (attempt == 0) {
    final now = DateTime.now();
    if (payload == _lastHandledPayload &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastHandledPayload = payload;
    _lastHandledAt = now;
  }
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
    // افتح صفحة الأذكار نفسها مباشرة (بلا المرور على شاشة العبادة) —
    // الرجوع منها يعيدك للشاشة اللي كنت عليها.
    final morning = payload.split('|').last == 'm';
    nav.push(MaterialPageRoute(
        builder: (_) => AdhkarReaderScreen(
            title: morning ? 'أذكار الصباح' : 'أذكار المساء',
            items: morning ? morningAdhkar : eveningAdhkar)));
  } else if (payload == 'faidah') {
    // فائدة اليوم تُعرض داخل المحادثة (تبقى في السجل)
    nav.push(MaterialPageRoute(builder: (_) => const ChatPage(showFaidah: true)));
  } else if (payload.startsWith('prayer|')) {
    // ضغط إشعار الأذان: افتح شاشة العبادة (نفس السلوك السابق) وشغّل الأذان
    // الكامل لهذه الصلاة (ضغط صريح → يتجاوز نافذة الـ10 دقائق، ويحترم التفضيلات
    // ونفس حارس «مرة لكل صلاة»).
    final name = payload.split('|').last;
    nav.push(MaterialPageRoute(builder: (_) => const WorshipScreen()));
    maybePlayAdhan(prayerName: name);
  }
}

// ── تشغيل الأذان الكامل عند وقت الصلاة ─────────────────────────────
// مسار الفتح/العودة (بلا [prayerName]): لو الآن ضمن 10 دقائق بعد إحدى الصلوات
// الخمس، والمستخدم مفعّل الأذان واختار صوت الأذان — نشغّل الأذان الكامل مرة
// واحدة لكل صلاة (حارس AdhanGuard). مسار ضغط الإشعار يمرّر [prayerName] فيتجاوز
// نافذة الوقت (ضغط صريح) لكن يبقى محكوماً بالتفضيلات ونفس الحارس.
Future<void> maybePlayAdhan({String? prayerName}) async {
  // انتظر اكتمال أول تحميل للتفضيلات — بلا هذا، عند الإقلاع البارد تُقرأ
  // sound='default' الافتراضية قبل وصول القيمة الحقيقية فيسقط الأذان بصمت.
  await WorshipPrefs.ensureLoaded();
  if (!WorshipPrefs.adhanEnabled) return;
  if (WorshipPrefs.sound != 'adhan') return; // فقط عند اختيار «صوت الأذان»

  final now = DateTime.now();
  String? targetName = prayerName;

  if (targetName == null) {
    final city = saudiCities[
        (WorshipPrefs.cityIndex >= 0 && WorshipPrefs.cityIndex < saudiCities.length)
            ? WorshipPrefs.cityIndex
            : 0];
    final pt = PrayerTimes.forDate(
        DateTime(now.year, now.month, now.day), city.lat, city.lng, 3.0);
    final prayers = <String, DateTime>{
      'الفجر': pt.fajr,
      'الظهر': pt.dhuhr,
      'العصر': pt.asr,
      'المغرب': pt.maghrib,
      'العشاء': pt.isha,
    };
    for (final e in prayers.entries) {
      final diffMin = now.difference(e.value).inMinutes; // موجب لو الآن بعد الأذان
      if (diffMin >= 0 && diffMin < 10) {
        targetName = e.key;
        break;
      }
    }
    if (targetName == null) return; // خارج نافذة أي صلاة
  }

  final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  final key = '$dateKey|$targetName';

  // حارس «مرة واحدة لكل صلاة» (يمنع تكرارها من مسارَي الفتح والضغط)
  final last = await AdhanGuard.lastPlayedKey();
  if (last == key) return;

  // لا نخزّن الحارس إلا بعد نجاح بدء التشغيل فعلاً — لو فشل التشغيل تبقى
  // المحاولة متاحة عند الفتح/العودة التالية ضمن النافذة (ملاحظة المدقق).
  final ok = await AdhanPlayer.instance.playFullAdhan();
  if (ok) await AdhanGuard.setLastPlayedKey(key);
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

/// ضمانة فتح الأذكار وقتها — لا تعتمد على ضغطة الإشعار إطلاقاً (نفس أسلوب
/// تأكيد الدواء وmaybePlayAdhan: «الحقيقة من الوقت» بدل توجيه الضغطة غير
/// الموثوق على iOS): لو فُتح التطبيق — بأي طريقة — خلال ١٥ دقيقة بعد وقت
/// أذكار الصباح/المساء، تُفتح صفحة الأذكار تلقائياً مرة واحدة لكل فترة/يوم.
Future<void> maybeOpenAdhkar() async {
  await WorshipPrefs.ensureLoaded();
  if (!WorshipPrefs.adhkarEnabled) return;
  final now = DateTime.now();
  DateTime? parse(String hm) {
    final p = hm.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return DateTime(now.year, now.month, now.day, h, m);
  }
  bool inWindow(DateTime? t) =>
      t != null && !now.isBefore(t) && now.difference(t) < const Duration(minutes: 15);
  String? period;
  if (inWindow(parse(WorshipPrefs.morningTime))) {
    period = 'm';
  } else if (inWindow(parse(WorshipPrefs.eveningTime))) {
    period = 'e';
  }
  if (period == null) return;
  const s = FlutterSecureStorage();
  const key = 'jasir_adhkar_auto_opened';
  final stamp = '${now.year}-${now.month}-${now.day}|$period';
  try {
    if (await s.read(key: key) == stamp) return; // فُتحت لهذه الفترة اليوم
  } catch (_) {}
  try {
    await s.write(key: key, value: stamp);
  } catch (_) {}
  // نفس مسار الإشعار: فيه إزالة الازدواج (لو وصلت الضغطة فعلاً لن تُفتح
  // مرتين) وإعادة المحاولة حتى يجهز المُنقّل.
  handleNotificationPayload('adhkar|$period');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.init();
  NotificationService.onSelectPayload = handleNotificationPayload;
  ThemeController.instance.load();
  ChatPrefs.load();
  WorshipPrefs.ensureLoaded(); // تفضيلات العبادة (مواقيت/أذكار/ذكر/فائدة)
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
    // أظهر/أخفِ شريط «إيقاف الأذان» تبعاً لحالة تشغيل الأذان.
    AdhanPlayer.instance.playing.addListener(_onAdhanPlayingChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdhanPlayer.instance.playing.removeListener(_onAdhanPlayingChanged);
    super.dispose();
  }

  /// يعرض شريط الإيقاف عند تشغيل الأذان ويزيله عند إيقافه/اكتماله.
  void _onAdhanPlayingChanged() {
    final m = rootMessengerKey.currentState;
    if (m == null) return;
    if (AdhanPlayer.instance.playing.value) {
      m.clearMaterialBanners();
      m.showMaterialBanner(MaterialBanner(
        content: const Text('يُرفع الأذان الآن'),
        leading: const Icon(Icons.volume_up),
        actions: [
          TextButton(
            onPressed: () => AdhanPlayer.instance.stop(),
            child: const Text('إيقاف الأذان'),
          ),
        ],
      ));
    } else {
      m.clearMaterialBanners();
    }
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
        scaffoldMessengerKey: rootMessengerKey,
        title: 'جاسر',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: JasirTheme.light(),
        darkTheme: JasirTheme.dark(),
        // ThemeMode.system افتراضًا (tc.mode = system عند عدم اختيار المستخدم)،
        // مع احترام مبدّل المظهر في الإعدادات إن اختار المستخدم فاتح/داكن يدويًا.
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
        // لو الآن ضمن 10 دقائق بعد صلاة والمستخدم مفعّل صوت الأذان — شغّله كاملاً
        maybePlayAdhan();
        // لو الآن وقت أذكار الصباح/المساء — افتح صفحتها (ضمانة بلا ضغطة)
        maybeOpenAdhkar();
      } else {
        // جلسة منتهية (خمول 6 ساعات) والتطبيق فُتح من إشعار: خزّن وجهة
        // الإشعار بدل إسقاطها — OtpScreen يعيد تشغيلها بعد نجاح الدخول.
        NotificationService.stashAppLaunch();
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
      maybePlayAdhan(); // العودة قرب وقت الصلاة → شغّل الأذان الكامل مرة واحدة
      maybeOpenAdhkar(); // العودة وقت الأذكار → افتح صفحتها (مرة لكل فترة/يوم)
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
