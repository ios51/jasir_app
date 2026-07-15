import 'package:flutter/material.dart';
import 'generic/module_registry.dart';
import 'generic/generic_list_screen.dart';
import 'services_grid_screen.dart';
import 'chat_page.dart';
import 'settings/app_settings_screen.dart';
import 'login_screen.dart';
import 'events/events_list_screen.dart';
import 'reminders/reminders_list_screen.dart';
import 'tasks/tasks_list_screen.dart';
import 'shopping/shopping_groups_screen.dart';
import 'documents/documents_screen.dart';
import 'links/links_grouped_screen.dart';
import 'sizes/size_categories_screen.dart';
import 'worship/worship_screen.dart';
import '../services/auth_service.dart';
import '../services/nav_prefs.dart';

/// خيار تبويب متاح للشريط السفلي — المستخدم يختار ٣ منها (والرئيسية ثابتة).
class NavTabOption {
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;
  const NavTabOption(this.id, this.label, this.icon, this.selectedIcon, this.builder);
}

/// كل الخدمات المتاحة للشريط السفلي (نفس وجهات شبكة الخدمات).
final List<NavTabOption> kNavCatalog = [
  NavTabOption('appointments', 'المواعيد', Icons.calendar_today_outlined,
      Icons.calendar_today, () => const AppointmentsTabsScreen()),
  NavTabOption('meds', 'الأدوية', Icons.medication_outlined, Icons.medication,
      () => GenericListScreen(def: ModuleRegistry.meds)),
  NavTabOption('family', 'العائلة', Icons.people_outline, Icons.people,
      () => GenericListScreen(def: ModuleRegistry.family)),
  NavTabOption('tasks', 'المهام', Icons.checklist_outlined, Icons.checklist,
      () => _titled('المهام', const TasksListScreen())),
  NavTabOption('reminders', 'التذكيرات', Icons.alarm_outlined, Icons.alarm,
      () => _titled('التذكيرات', const RemindersListScreen())),
  NavTabOption('events', 'مواعيدي', Icons.event_outlined, Icons.event,
      () => _titled('مواعيدي', const EventsListScreen())),
  NavTabOption('worship', 'الأذكار', Icons.mosque_outlined, Icons.mosque,
      () => const WorshipScreen()),
  NavTabOption('shopping', 'مشترياتي', Icons.shopping_cart_outlined,
      Icons.shopping_cart, () => const ShoppingGroupsScreen()),
  NavTabOption('documents', 'وثائقي', Icons.description_outlined,
      Icons.description, () => const DocumentsScreen()),
  NavTabOption('cars', 'سياراتي', Icons.directions_car_outlined,
      Icons.directions_car, () => GenericListScreen(def: ModuleRegistry.cars)),
  NavTabOption('workers', 'عمالتي', Icons.engineering_outlined,
      Icons.engineering, () => GenericListScreen(def: ModuleRegistry.workers)),
  NavTabOption('debts', 'الديون', Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      () => GenericListScreen(def: ModuleRegistry.debts)),
  NavTabOption('schedule', 'جدولي', Icons.calendar_view_week_outlined,
      Icons.calendar_view_week,
      () => GenericListScreen(def: ModuleRegistry.schedule)),
  NavTabOption('links', 'روابطي', Icons.link_outlined, Icons.link,
      () => const LinksGroupedScreen()),
  NavTabOption('sizes', 'مقاساتي', Icons.straighten_outlined, Icons.straighten,
      () => const SizeCategoriesScreen()),
  NavTabOption('measurements', 'القياسات', Icons.monitor_heart_outlined,
      Icons.monitor_heart,
      () => GenericListScreen(def: ModuleRegistry.measurements)),
];

/// غلاف بعنوان للشاشات المصممة كتبويبات داخلية (بلا AppBar خاص بها).
Widget _titled(String title, Widget body) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(appBar: AppBar(title: Text(title)), body: body),
    );

NavTabOption? navOptionById(String id) {
  for (final o in kNavCatalog) {
    if (o.id == id) return o;
  }
  return null;
}

/// الشاشة الرئيسية — شريط تنقل سفلي: «الرئيسية» ثابتة + ٣ تبويبات
/// يخصصها المستخدم من الإعدادات (الافتراضي: المواعيد · الأدوية · العائلة).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // نعيد بناء الصفحات فقط عند تغيّر الاختيار (حفاظاً على حالة كل تبويب).
  String _idsKey = '';
  List<NavTabOption> _tabs = [];
  List<Widget> _pages = const [];

  @override
  void initState() {
    super.initState();
    NavPrefs.changed.addListener(_onPrefsChanged);
    _syncPages();
  }

  @override
  void dispose() {
    NavPrefs.changed.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(_syncPages);
  }

  void _syncPages() {
    final ids = NavPrefs.current.join(',');
    if (ids == _idsKey && _pages.isNotEmpty) return;
    _idsKey = ids;
    _tabs = NavPrefs.current
        .map(navOptionById)
        .whereType<NavTabOption>()
        .take(3)
        .toList();
    if (_tabs.isEmpty) {
      _tabs = NavPrefs.defaults
          .map(navOptionById)
          .whereType<NavTabOption>()
          .toList();
    }
    _pages = [const _HomeTab(), for (final t in _tabs) t.builder()];
    if (_index >= _pages.length) _index = 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: cs.surface,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية'),
          for (final t in _tabs)
            NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label),
        ],
      ),
    );
  }
}

/// تبويب «الرئيسية» — شبكة الخدمات المجمّعة دلاليًا داخل سقالة هادئة تحمل
/// الإعدادات وتسجيل الخروج.
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
          // مدخل المحادثة — قلب المنتج. في اليمين (start مع RTL) وأعرض
          // بنصّ أوضح (طلب المستخدم).
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatPage())),
            extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('تواصل مع سكرتيرك جاسر'),
          ),
        ),
      );
}
