import 'package:flutter/material.dart';
import 'events/events_list_screen.dart';
import 'reminders/reminders_list_screen.dart';
import 'tasks/tasks_list_screen.dart';
import 'generic/module_registry.dart';
import 'generic/generic_list_screen.dart';
import 'settings/morning_settings_screen.dart';
import 'sizes/size_categories_screen.dart';
import 'shopping/shopping_groups_screen.dart';
import 'documents/documents_screen.dart';
import 'links/links_grouped_screen.dart';
import 'worship/worship_screen.dart';
import '../services/services_prefs.dart';
import 'reorder_services_screen.dart';

/// شاشة "الخدمات" — شبكة بطاقات محايدة بأيقونات ملوّنة.
/// الترتيب قابل للتعديل بالسحب (يُحفظ على الجهاز).
class ServicesGridScreen extends StatefulWidget {
  const ServicesGridScreen({super.key});

  @override
  State<ServicesGridScreen> createState() => _ServicesGridScreenState();
}

class _ServicesGridScreenState extends State<ServicesGridScreen> {
  // كل بطاقة بمعرّف ثابت (يُستخدم لحفظ الترتيب)
  List<_ServiceTile> get _allTiles => <_ServiceTile>[
        _ServiceTile('appointments', 'المواعيد والتذكيرات', 'تنظيم مواعيدك ومتابعة جدولك',
            Icons.event_available_outlined, const Color(0xFF5B8DEF), () => const AppointmentsTabsScreen()),
        _ServiceTile('meds', 'الأدوية', 'تذكيرك بالأدوية ومواعيد الجرعات',
            Icons.medication_outlined, const Color(0xFFF05D5E), () => GenericListScreen(def: ModuleRegistry.meds)),
        _ServiceTile('family', 'العائلة', 'متابعة شؤون العائلة والأحباء',
            Icons.family_restroom_outlined, const Color(0xFF0F9DB0), () => GenericListScreen(def: ModuleRegistry.family)),
        _ServiceTile('cars', 'سياراتي', 'خدمات ومعلومات سيارتك',
            Icons.directions_car_outlined, const Color(0xFF2D9CDB), () => GenericListScreen(def: ModuleRegistry.cars)),
        _ServiceTile('measurements', 'القياسات الصحية', 'متابعة قياساتك الصحية',
            Icons.monitor_heart_outlined, const Color(0xFFC05B91), () => GenericListScreen(def: ModuleRegistry.measurements)),
        _ServiceTile('schedule', 'جدولي والمحاضرات', 'جدولك الأسبوعي والمحاضرات',
            Icons.calendar_view_week_outlined, const Color(0xFF7B61D1), () => GenericListScreen(def: ModuleRegistry.schedule)),
        _ServiceTile('documents', 'وثائقي', 'رفع واستعراض وثائقك',
            Icons.description_outlined, const Color(0xFF8B6C61), () => const DocumentsScreen()),
        _ServiceTile('debts', 'الديون', 'ديونك ومستحقاتك',
            Icons.account_balance_wallet_outlined, const Color(0xFF39A96B), () => GenericListScreen(def: ModuleRegistry.debts)),
        _ServiceTile('shopping', 'مشترياتي', 'قوائم مشتركة + الأسعار',
            Icons.shopping_cart_outlined, const Color(0xFFE8A11A), () => const ShoppingGroupsScreen()),
        _ServiceTile('workers', 'عمالتي', 'متابعة العمالة والإقامات',
            Icons.engineering_outlined, const Color(0xFFD98E27), () => GenericListScreen(def: ModuleRegistry.workers)),
        _ServiceTile('sizes', 'مقاساتي', 'قياسات الأشخاص والأماكن',
            Icons.straighten_outlined, const Color(0xFF20B9C5), () => const SizeCategoriesScreen()),
        _ServiceTile('links', 'روابطي', 'مجلدات + تصنيف تلقائي',
            Icons.link_outlined, const Color(0xFF3C9BDF), () => const LinksGroupedScreen()),
        _ServiceTile('morning', 'رسالة الصباح', 'ملخص يومك وبداية ملهمة',
            Icons.wb_sunny_outlined, const Color(0xFFE7B84B), () => const MorningSettingsScreen()),
        _ServiceTile('worship', 'العبادة', 'مواقيت الصلاة والأذكار وفائدة اليوم',
            Icons.mosque_outlined, const Color(0xFF1F8A70), () => const WorshipScreen()),
      ];

  /// البطاقات مرتّبة حسب اختيار المستخدم المحفوظ.
  List<_ServiceTile> get _tiles {
    final all = _allTiles;
    final byId = {for (final t in all) t.id: t};
    final ids = ServicesPrefs.apply(all.map((t) => t.id).toList());
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  Future<void> _openReorder() async {
    final tiles = _tiles;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ReorderServicesScreen(
        items: [for (final t in tiles) ReorderItem(t.id, t.title, t.icon, t.color)],
      ),
    ));
    if (changed == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tiles = _tiles;
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 8),
            child: TextButton.icon(
              onPressed: _openReorder,
              icon: const Icon(Icons.swap_vert, size: 18),
              label: const Text('ترتيب الخدمات'),
            ),
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
          ),
        ),
      ],
    );
  }
}

class _ServiceTile {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
  _ServiceTile(this.id, this.title, this.subtitle, this.icon, this.color, this.builder);
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
