import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'generic/module_registry.dart';
import 'generic/generic_list_screen.dart';
import 'services_grid_screen.dart';
import 'settings/morning_settings_screen.dart';
import 'settings/app_settings_screen.dart';
import 'login_screen.dart';
import 'chat_page.dart';

/// الشاشة الرئيسية (تبويب "الرئيسية") — ترحيب + بطاقات وصول سريع + مدخل المحادثة،
/// وفق الموكب المعتمد.
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cards = <_Q>[
      _Q('المواعيد', 'تنظيم مواعيدك ومتابعة جدولك', Icons.calendar_today_outlined,
          const Color(0xFF5B8DEF), () => const AppointmentsTabsScreen()),
      _Q('الأدوية', 'تذكيرك بالأدوية ومواعيد الجرعات', Icons.medication_outlined,
          const Color(0xFFF05D5E), () => GenericListScreen(def: ModuleRegistry.meds)),
      _Q('العائلة', 'متابعة شؤون العائلة والأحباء', Icons.people_outline,
          const Color(0xFF0F9DB0), () => GenericListScreen(def: ModuleRegistry.family)),
      _Q('سيارتي', 'خدمات ومعلومات سيارتك', Icons.directions_car_outlined,
          const Color(0xFF2D9CDB), () => GenericListScreen(def: ModuleRegistry.cars)),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('جاسر'),
          actions: [
            IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'الإعدادات',
                onPressed: () => _open(context, const AppSettingsScreen())),
            IconButton(icon: const Icon(Icons.logout), tooltip: 'تسجيل الخروج',
                onPressed: () => _logout(context)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Icon(Icons.auto_awesome, color: cs.primary, size: 20),
              const SizedBox(width: 6),
              Text('مرحبًا بك،',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
            ]),
            const SizedBox(height: 4),
            Text('أنا جاسر، مساعدك الشخصي الذكي', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.12,
              children: cards.map((c) => _card(context, c, cs)).toList(),
            ),
            const SizedBox(height: 12),
            _wide(context, 'رسالة الصباح', 'ملخص يومك وبداية ملهمة', Icons.wb_sunny_outlined,
                const Color(0xFFE7B84B), () => const MorningSettingsScreen(), cs),
            const SizedBox(height: 22),
            Row(children: [
              Icon(Icons.auto_awesome, color: cs.primary, size: 18),
              const SizedBox(width: 6),
              Text('محادثة مع جاسر',
                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
            ]),
            const SizedBox(height: 10),
            _chatEntry(context, cs),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, _Q c, ColorScheme cs) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(context, c.builder()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: c.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(c.icon, color: c.color, size: 24),
            ),
            const Spacer(),
            Text(c.title, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 15.5)),
            const SizedBox(height: 2),
            Text(c.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.3)),
            Align(alignment: AlignmentDirectional.centerStart, child: Icon(Icons.chevron_left, color: cs.primary, size: 20)),
          ]),
        ),
      );

  Widget _wide(BuildContext context, String title, String sub, IconData icon, Color color,
          Widget Function() builder, ColorScheme cs) =>
      InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(context, builder()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 15.5)),
              Text(sub, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            ])),
            Icon(Icons.chevron_left, color: cs.primary),
          ]),
        ),
      );

  Widget _chatEntry(BuildContext context, ColorScheme cs) => InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _open(context, const ChatPage()),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outline),
          ),
          child: Row(children: [
            Icon(Icons.chat_bubble_outline, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('اكتب رسالتك لجاسر...', style: TextStyle(color: cs.onSurfaceVariant))),
            Icon(Icons.send, color: cs.primary),
          ]),
        ),
      );
}

class _Q {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
  _Q(this.title, this.subtitle, this.icon, this.color, this.builder);
}
