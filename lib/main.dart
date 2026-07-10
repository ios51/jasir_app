import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'services/notification_sync.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/jasir_spinner.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.init();
  ThemeController.instance.load();
  runApp(const JasirApp());
}

class JasirApp extends StatelessWidget {
  const JasirApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;
    return AnimatedBuilder(
      animation: tc,
      builder: (context, _) => MaterialApp(
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

/// يقرر أول شاشة تظهر: تسجيل الدخول أو الشاشة الرئيسية، حسب وجود جلسة محفوظة.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.isLoggedIn().then((v) {
      if (mounted) setState(() => _loggedIn = v);
      // بعد التأكد من الدخول، اطلب إذن التنبيهات وجدولها من بيانات جاسر
      if (v == true) {
        NotificationSync.run();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn == null) {
      return const Scaffold(body: Center(child: JasirSpinner(size: 56)));
    }
    return _loggedIn! ? const HomeScreen() : const LoginScreen();
  }
}
