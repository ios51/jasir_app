import 'package:flutter/material.dart';
import 'generic/module_registry.dart';
import 'generic/generic_list_screen.dart';
import 'services_grid_screen.dart';
import 'chat_page.dart';
import 'settings/app_settings_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

/// الشاشة الرئيسية — شريط تنقل سفلي من 4 عناصر (وفق الموكب):
/// الرئيسية · المواعيد · الأدوية · العائلة.
/// تبويب «الرئيسية» يعرض الآن شبكة الخدمات المجمّعة دلاليًا (ServicesGridScreen)
/// وفق design-system/MASTER.md — حلّ محلّ HomeDashboard القديمة، وأُزيل تبويب
/// «المزيد» الذي كان يكرّر نفس الشبكة.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  late final List<Widget> _pages = [
    const _HomeTab(),
    const AppointmentsTabsScreen(),
    GenericListScreen(def: ModuleRegistry.meds),
    GenericListScreen(def: ModuleRegistry.family),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: cs.surface,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'المواعيد'),
          NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'الأدوية'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'العائلة'),
        ],
      ),
    );
  }
}

/// تبويب «الرئيسية» — شبكة الخدمات المجمّعة دلاليًا داخل سقالة هادئة تحمل
/// الإعدادات وتسجيل الخروج (نفس مدخلَي HomeDashboard السابقة حفاظًا على السلوك).
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  Future<void> _logout(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    // تأكيد قبل الخروج (يمنع الخروج بالغلط)
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('متأكد أنك تبي تسجّل خروج؟ بتحتاج ترسل رمز تحقق جديد للدخول مرة ثانية.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('خروج', style: TextStyle(color: cs.error)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await AuthService().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('جاسر'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'الإعدادات',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AppSettingsScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'تسجيل الخروج',
                onPressed: () => _logout(context),
              ),
            ],
          ),
          body: const ServicesGridScreen(),
          // مدخل المحادثة اليدوي — قلب المنتج (كان بطاقة _chatEntry في
          // HomeDashboard المحذوفة؛ بدونه لا تُفتح المحادثة إلا من الإشعارات).
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatPage())),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('كلّم جاسر'),
          ),
        ),
      );
}
