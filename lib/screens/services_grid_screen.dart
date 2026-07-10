import 'package:flutter/material.dart';
import 'events/events_list_screen.dart';
import 'reminders/reminders_list_screen.dart';
import 'tasks/tasks_list_screen.dart';
import 'generic/module_registry.dart';
import 'generic/generic_list_screen.dart';
import 'generic/field_def.dart';
import 'settings/morning_settings_screen.dart';

/// شاشة "الخدمات" — شبكة تعرض كل خدمات جاسر الـ 12، كل بطاقة تفتح شاشتها.
class ServicesGridScreen extends StatelessWidget {
  const ServicesGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // الخدمات الثلاث الأصلية (لها شاشاتها الخاصة) + الموديولات العامة
    final tiles = <_ServiceTile>[
      _ServiceTile('المواعيد والتذكيرات', Icons.event_available_outlined, Colors.indigo,
          () => const _MultiTab()),
      _ServiceTile('الأدوية', Icons.medication_outlined, Colors.red,
          () => GenericListScreen(def: ModuleRegistry.meds)),
      _ServiceTile('القياسات الصحية', Icons.monitor_heart_outlined, Colors.pink,
          () => GenericListScreen(def: ModuleRegistry.measurements)),
      _ServiceTile('جدولي والمحاضرات', Icons.calendar_view_week_outlined, Colors.deepPurple,
          () => GenericListScreen(def: ModuleRegistry.schedule)),
      _ServiceTile('وثائقي', Icons.description_outlined, Colors.brown,
          () => GenericListScreen(def: ModuleRegistry.documents)),
      _ServiceTile('العائلة', Icons.family_restroom_outlined, Colors.teal,
          () => GenericListScreen(def: ModuleRegistry.family)),
      _ServiceTile('أطباء ومستشفيات', Icons.local_hospital_outlined, Colors.blueGrey,
          () => GenericListScreen(def: ModuleRegistry.contacts)),
      _ServiceTile('سياراتي', Icons.directions_car_outlined, Colors.blue,
          () => GenericListScreen(def: ModuleRegistry.cars)),
      _ServiceTile('الديون', Icons.account_balance_wallet_outlined, Colors.green,
          () => GenericListScreen(def: ModuleRegistry.debts)),
      _ServiceTile('مشترياتي', Icons.shopping_cart_outlined, Colors.orange,
          () => GenericListScreen(def: ModuleRegistry.shopping)),
      _ServiceTile('عمالتي', Icons.engineering_outlined, Colors.amber.shade800,
          () => GenericListScreen(def: ModuleRegistry.workers)),
      _ServiceTile('مقاساتي', Icons.straighten_outlined, Colors.cyan,
          () => GenericListScreen(def: ModuleRegistry.sizes)),
      _ServiceTile('روابطي', Icons.link_outlined, Colors.lightBlue,
          () => GenericListScreen(def: ModuleRegistry.links)),
      _ServiceTile('رسالة الصباح', Icons.wb_sunny_outlined, Colors.deepOrange,
          () => const MorningSettingsScreen()),
    ];

    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(12),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: tiles.map((t) {
        return InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => t.builder())),
          child: Card(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.icon, size: 36, color: t.color),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(t.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                ),
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
  final IconData icon;
  final Color color;
  final Widget Function() builder;
  _ServiceTile(this.title, this.icon, this.color, this.builder);
}

/// تبويبات المواعيد/التذكيرات/المهام في شاشة واحدة.
class _MultiTab extends StatelessWidget {
  const _MultiTab();
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
