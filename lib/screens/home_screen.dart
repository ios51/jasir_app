import 'package:flutter/material.dart';
import 'generic/module_registry.dart';
import 'generic/generic_list_screen.dart';
import 'services_grid_screen.dart';
import 'home_dashboard.dart';
import '../theme/app_theme.dart';

/// الشاشة الرئيسية — شريط تنقل سفلي من 5 عناصر (وفق الموكب):
/// الرئيسية · المواعيد · الأدوية · العائلة · المزيد.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  late final List<Widget> _pages = [
    const HomeDashboard(),
    const AppointmentsTabsScreen(),
    GenericListScreen(def: ModuleRegistry.meds),
    GenericListScreen(def: ModuleRegistry.family),
    const _MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: dark ? AppTheme.dSurface : AppTheme.lSurface,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'المواعيد'),
          NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'الأدوية'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'العائلة'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'المزيد'),
        ],
      ),
    );
  }
}

/// تبويب "المزيد" — كل الخدمات في شبكة بطاقات.
class _MoreScreen extends StatelessWidget {
  const _MoreScreen();
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('الخدمات')),
          body: const ServicesGridScreen(),
        ),
      );
}
