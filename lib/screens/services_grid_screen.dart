import 'package:flutter/material.dart';
import 'events/events_list_screen.dart';
import 'reminders/reminders_list_screen.dart';
import 'tasks/tasks_list_screen.dart';
import 'generic/module_registry.dart';
import 'generic/generic_list_screen.dart';
import 'settings/morning_settings_screen.dart';
import 'sizes/size_categories_screen.dart';
import 'shopping/shopping_groups_screen.dart';

/// شاشة "الخدمات" — شبكة بطاقات محايدة بأيقونات ملوّنة (وفق ملف الهوية):
/// اللون للأيقونة فقط، البطاقة محايدة، عنوان + وصف مختصر.
class ServicesGridScreen extends StatelessWidget {
  const ServicesGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <_ServiceTile>[
      _ServiceTile('المواعيد والتذكيرات', 'تنظيم مواعيدك ومتابعة جدولك',
          Icons.event_available_outlined, const Color(0xFF5B8DEF), () => const AppointmentsTabsScreen()),
      _ServiceTile('الأدوية', 'تذكيرك بالأدوية ومواعيد الجرعات',
          Icons.medication_outlined, const Color(0xFFF05D5E), () => GenericListScreen(def: ModuleRegistry.meds)),
      _ServiceTile('العائلة', 'متابعة شؤون العائلة والأحباء',
          Icons.family_restroom_outlined, const Color(0xFF0F9DB0), () => GenericListScreen(def: ModuleRegistry.family)),
      _ServiceTile('سياراتي', 'خدمات ومعلومات سيارتك',
          Icons.directions_car_outlined, const Color(0xFF2D9CDB), () => GenericListScreen(def: ModuleRegistry.cars)),
      _ServiceTile('أطباء ومستشفيات', 'جهات الرعاية الصحية',
          Icons.local_hospital_outlined, const Color(0xFF5F89A8), () => GenericListScreen(def: ModuleRegistry.contacts)),
      _ServiceTile('القياسات الصحية', 'متابعة قياساتك الصحية',
          Icons.monitor_heart_outlined, const Color(0xFFC05B91), () => GenericListScreen(def: ModuleRegistry.measurements)),
      _ServiceTile('جدولي والمحاضرات', 'جدولك الأسبوعي والمحاضرات',
          Icons.calendar_view_week_outlined, const Color(0xFF7B61D1), () => GenericListScreen(def: ModuleRegistry.schedule)),
      _ServiceTile('وثائقي', 'وثائقك ومستنداتك المهمة',
          Icons.description_outlined, const Color(0xFF8B6C61), () => GenericListScreen(def: ModuleRegistry.documents)),
      _ServiceTile('الديون', 'ديونك ومستحقاتك',
          Icons.account_balance_wallet_outlined, const Color(0xFF39A96B), () => GenericListScreen(def: ModuleRegistry.debts)),
      _ServiceTile('مشترياتي', 'قوائم مشتركة + الأسعار',
          Icons.shopping_cart_outlined, const Color(0xFFE8A11A), () => const ShoppingGroupsScreen()),
      _ServiceTile('عمالتي', 'متابعة العمالة والإقامات',
          Icons.engineering_outlined, const Color(0xFFD98E27), () => GenericListScreen(def: ModuleRegistry.workers)),
      _ServiceTile('مقاساتي', 'قياسات الأشخاص والأماكن',
          Icons.straighten_outlined, const Color(0xFF20B9C5), () => const SizeCategoriesScreen()),
      _ServiceTile('روابطي', 'روابطك المحفوظة',
          Icons.link_outlined, const Color(0xFF3C9BDF), () => GenericListScreen(def: ModuleRegistry.links)),
      _ServiceTile('رسالة الصباح', 'ملخص يومك وبداية ملهمة',
          Icons.wb_sunny_outlined, const Color(0xFFE7B84B), () => const MorningSettingsScreen()),
    ];

    final cs = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.08,
      children: tiles.map((t) {
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => t.builder())),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: t.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(t.icon, size: 26, color: t.color),
                ),
                const Spacer(),
                Text(t.title,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
                const SizedBox(height: 3),
                Text(t.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.3, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ServiceTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
  _ServiceTile(this.title, this.subtitle, this.icon, this.color, this.builder);
}

/// تبويبات المواعيد/التذكيرات/المهام في شاشة واحدة.
class AppointmentsTabsScreen extends StatelessWidget {
  const AppointmentsTabsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المواعيد والتذكيرات والمهام'),
          bottom: const TabBar(tabs: [
            Tab(text: 'المواعيد', icon: Icon(Icons.event_outlined)),
            Tab(text: 'التذكيرات', icon: Icon(Icons.alarm_outlined)),
            Tab(text: 'المهام', icon: Icon(Icons.checklist_outlined)),
          ]),
        ),
        body: const TabBarView(children: [
          EventsListScreen(),
          RemindersListScreen(),
          TasksListScreen(),
        ]),
      ),
    );
  }
}
