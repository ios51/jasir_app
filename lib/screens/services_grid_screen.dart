import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'events/events_list_screen.dart';
import 'reminders/reminders_list_screen.dart';
import 'tasks/tasks_list_screen.dart';
import 'generic/module_registry.dart';
import 'generic/generic_list_screen.dart';
import 'settings/morning_settings_screen.dart';
import 'sizes/size_categories_screen.dart';
import 'shopping/shopping_groups_screen.dart';
import 'documents/documents_screen.dart';
import 'debts/debts_screen.dart';
import 'links/links_grouped_screen.dart';
import 'sports/sports_screen.dart';
import 'support/admin_support_screen.dart';
import 'support/support_screen.dart';
import 'worship/worship_screen.dart';
import '../services/support_service.dart';
import '../theme/jasir_theme.dart';

/// شاشة الخدمات — إعادة تصميم «Calm Bento» وفق design-system/MASTER.md:
/// منطقة ترحيب هادئة + أربع مجموعات دلالية (صحة · عائلة · شؤون يومية) +
/// خاتمة روحانية بمعالجة متميّزة (Teal عميق + ذهبي + Amiri).
/// كل الألوان من Theme/JasirGroupColors — صفر Hex داخل الودجت.
class ServicesGridScreen extends StatefulWidget {
  const ServicesGridScreen({super.key});

  @override
  State<ServicesGridScreen> createState() => _ServicesGridScreenState();
}

/// أنواع المجموعات الدلالية الأربع.
enum _GroupKind { health, family, daily, spiritual }

class _ServicesGridScreenState extends State<ServicesGridScreen>
    with SingleTickerProviderStateMixin {
  // ── الحركة: ظهور متتابع للأقسام (280ms/قسم + 40ms تتابع) ──
  static const int _sectionMs = 280;
  static const int _staggerMs = 40;
  // 5 أقسام تدخل بالتتابع: الترحيب + 4 مجموعات.
  static const int _sections = 5;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _sectionMs + _staggerMs * (_sections - 1)),
  );
  bool _entranceStarted = false;

  /// «لوحة الدعم» تظهر للمالك فقط — تُفحص مرة عند الفتح (فشل الشبكة = مخفية).
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    SupportService().isAdmin().then((v) {
      if (mounted && v) setState(() => _isAdmin = true);
    });
  }

  // ── المجموعات: نفس الوجهات الأصلية للبلاطات الأربع عشرة بالضبط ──
  List<_ServiceGroup> get _groups => <_ServiceGroup>[
        // صحة — الأدوية · القياسات · المواعيد
        _ServiceGroup('صحة', _GroupKind.health, <_ServiceTile>[
          _ServiceTile('meds', 'الأدوية', 'تذكيرك بالأدوية ومواعيد الجرعات',
              Icons.medication_outlined,
              () => GenericListScreen(def: ModuleRegistry.meds)),
          _ServiceTile('measurements', 'القياسات الصحية', 'متابعة قياساتك الصحية',
              Icons.monitor_heart_outlined,
              () => GenericListScreen(def: ModuleRegistry.measurements)),
          _ServiceTile('appointments', 'المواعيد والتذكيرات',
              'تنظيم مواعيدك ومتابعة جدولك', Icons.event_available_outlined,
              () => const AppointmentsTabsScreen()),
        ]),
        // عائلة — العائلة · العمال · المقاسات
        _ServiceGroup('عائلة', _GroupKind.family, <_ServiceTile>[
          _ServiceTile('family', 'العائلة', 'متابعة شؤون العائلة والأحباء',
              Icons.family_restroom_outlined,
              () => GenericListScreen(def: ModuleRegistry.family)),
          _ServiceTile('workers', 'عمالتي', 'متابعة العمالة والإقامات',
              Icons.engineering_outlined,
              () => GenericListScreen(def: ModuleRegistry.workers)),
          _ServiceTile('sizes', 'مقاساتي', 'قياسات الأشخاص والأماكن',
              Icons.straighten_outlined, () => const SizeCategoriesScreen()),
        ]),
        // شؤون يومية — السيارات · الوثائق · الديون · التسوق · الجدول · الروابط
        _ServiceGroup('شؤون يومية', _GroupKind.daily, <_ServiceTile>[
          _ServiceTile('cars', 'سياراتي', 'خدمات ومعلومات سيارتك',
              Icons.directions_car_outlined,
              () => GenericListScreen(def: ModuleRegistry.cars)),
          _ServiceTile('documents', 'وثائقي', 'رفع واستعراض وثائقك',
              Icons.description_outlined, () => const DocumentsScreen()),
          _ServiceTile('debts', 'الديون', 'ديونك ومستحقاتك',
              Icons.account_balance_wallet_outlined,
              () => const DebtsScreen()),
          _ServiceTile('shopping', 'مشترياتي', 'قوائم مشتركة + الأسعار',
              Icons.shopping_cart_outlined, () => const ShoppingGroupsScreen()),
          _ServiceTile('schedule', 'جدولي والمحاضرات', 'جدولك الأسبوعي والمحاضرات',
              Icons.calendar_view_week_outlined,
              () => GenericListScreen(def: ModuleRegistry.schedule)),
          _ServiceTile('links', 'روابطي', 'مجلدات + تصنيف تلقائي',
              Icons.link_outlined, () => const LinksGroupedScreen()),
          _ServiceTile('sports', 'الرياضة', 'نتائج وترتيب فرقك المفضلة',
              Icons.sports_soccer_outlined, () => const SportsScreen()),
          _ServiceTile('support', 'تواصل معنا', 'اقتراحاتك وشكاويك تصلنا هنا',
              Icons.forum_outlined, () => const SupportScreen()),
          if (_isAdmin)
            _ServiceTile('support_admin', 'لوحة الدعم', 'رسائل المستخدمين والإعلانات',
                Icons.admin_panel_settings_outlined, () => const AdminSupportScreen()),
        ]),
        // روحانيات — رسالة الصباح · أذكار المؤمن (خاتمة وجدانية)
        _ServiceGroup('روحانيات', _GroupKind.spiritual, <_ServiceTile>[
          _ServiceTile('morning', 'رسالة الصباح', 'ملخص يومك وبداية ملهمة',
              Icons.wb_sunny_outlined, () => const MorningSettingsScreen()),
          _ServiceTile('worship', 'أذكار المؤمن',
              'مواقيت الصلاة والأذكار وفائدة اليوم', Icons.mosque_outlined,
              () => const WorshipScreen()),
        ]),
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    // احترام «تقليل الحركة»: أظهر المحتوى فورًا دون أي حركة دخول.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _open(Widget Function() builder) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => builder()));

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      children: [
        _Entrance(
          controller: _entrance,
          index: 0,
          total: _sections,
          child: const _GreetingZone(),
        ),
        for (int i = 0; i < groups.length; i++) ...[
          const SizedBox(height: 18),
          _Entrance(
            controller: _entrance,
            index: i + 1,
            total: _sections,
            child: groups[i].kind == _GroupKind.spiritual
                ? _SpiritualGroupCard(group: groups[i], onOpen: _open)
                : _GroupCard(group: groups[i], onOpen: _open),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────── منطقة الترحيب ───────────────────────────

/// ترحيب هادئ على سطح الشاشة (لا هيدر Teal ثقيل): تحية Amiri + سطر التاريخ
/// Tajawal بالأرقام العربية-الهندية. البيانات محلّية — بلا جلب جديد.
class _GreetingZone extends StatelessWidget {
  const _GreetingZone();

  static const _days = <String>[
    'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
  ];
  static const _months = <String>[
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static String _arDigits(String s) {
    const w = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const e = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(w[i], e[i]);
    }
    return s;
  }

  String _formatDate(DateTime d) {
    final wd = _days[d.weekday - 1];
    final mo = _months[d.month - 1];
    return '$wd، ${_arDigits(d.day.toString())} $mo ${_arDigits(d.year.toString())}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // لمسة ذهبية دافئة (شمس الهوية) — إبراز نادر (10%).
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(Icons.wb_sunny_outlined,
                color: cs.tertiary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً',
                  style: GoogleFonts.amiri(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(DateTime.now()),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── مجموعة Bento قياسية ─────────────────────────

/// حاوية مجموعة (radius 24) بلون تِنت المجموعة، عنوان 18/700، وبلاطات
/// متجاوبة داخلها. الأعمدة: 2 هاتف · 3 لوح صغير · 4 لوح كبير.
class _GroupCard extends StatelessWidget {
  final _ServiceGroup group;
  final void Function(Widget Function() builder) onOpen;
  const _GroupCard({required this.group, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    final tt = Theme.of(context).textTheme;
    // إطار بلون المجموعة بدل الخلفية الملونة (طلب المستخدم) —
    // السطح محايد والهوية اللونية في الحد.
    final borderColor = switch (group.kind) {
      _GroupKind.health => g.healthIcon,
      _GroupKind.family => g.familyIcon,
      _GroupKind.daily => g.dailyIcon,
      _GroupKind.spiritual => g.spiritualIcon,
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: borderColor.withValues(alpha: 0.55), width: 1.6),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
            child: Text(group.title, style: tt.titleLarge),
          ),
          LayoutBuilder(
            builder: (context, c) {
              const spacing = 12.0;
              final w = c.maxWidth;
              final cols = w >= 900 ? 4 : (w >= 560 ? 3 : 2);
              final itemW = (w - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final t in group.tiles)
                    SizedBox(
                      width: itemW,
                      child: _ServiceTileCard(
                        tile: t,
                        kind: group.kind,
                        onTap: () => onOpen(t.builder),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// بلاطة خدمة عمودية: شريحة أيقونة (radius 12) + عنوان 16/700 + وصف 12.5/400.
class _ServiceTileCard extends StatelessWidget {
  final _ServiceTile tile;
  final _GroupKind kind;
  final VoidCallback onTap;
  const _ServiceTileCard(
      {required this.tile, required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    final tt = Theme.of(context).textTheme;
    final (chipColor, iconColor) = switch (kind) {
      _GroupKind.health => (g.healthChip, g.healthIcon),
      _GroupKind.family => (g.familyChip, g.familyIcon),
      _GroupKind.daily => (g.dailyChip, g.dailyIcon),
      _GroupKind.spiritual => (g.spiritualChip, g.spiritualIcon),
    };

    return _Pressable(
      onTap: onTap,
      radius: BorderRadius.circular(18),
      splash: cs.primary.withValues(alpha: 0.08),
      semanticLabel: tile.title,
      decoration: BoxDecoration(
        color: g.tileSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: g.tileShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tile.icon, size: 24, color: iconColor),
            ),
            const SizedBox(height: 14),
            Text(tile.title, style: tt.titleMedium),
            const SizedBox(height: 3),
            Text(
              tile.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── خاتمة الروحانيات المميّزة ───────────────────────

/// معالجة متميّزة: خلفية Teal عميق، أكسنت ذهبي، عناوين Amiri، إيقاع صفّي
/// كامل العرض (يختلف بصريًا عن مجموعات الشبكة أعلاه).
class _SpiritualGroupCard extends StatelessWidget {
  final _ServiceGroup group;
  final void Function(Widget Function() builder) onOpen;
  const _SpiritualGroupCard({required this.group, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    // إطار ذهبي بدل الخلفية الملونة (توحيداً مع بقية المجموعات) —
    // البلاطات الداخلية تحتفظ بسطحها الداكن المميز فتبقى ألوانها مقروءة.
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: g.spiritualIcon.withValues(alpha: 0.55), width: 1.6),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 22,
                  decoration: BoxDecoration(
                    color: g.spiritualIcon,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  group.title,
                  style: GoogleFonts.tajawal(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: cs.onSurface, // على سطح محايد الآن (بعد الإطار)
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < group.tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _SpiritualTileRow(
              tile: group.tiles[i],
              onTap: () => onOpen(group.tiles[i].builder),
            ),
          ],
        ],
      ),
    );
  }
}

/// بلاطة روحانية صفّية: شريحة ذهبية + عنوان Amiri كريمي + وصف مكتوم.
class _SpiritualTileRow extends StatelessWidget {
  final _ServiceTile tile;
  final VoidCallback onTap;
  const _SpiritualTileRow({required this.tile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return _Pressable(
      onTap: onTap,
      radius: BorderRadius.circular(18),
      splash: g.spiritualIcon.withValues(alpha: 0.12),
      semanticLabel: tile.title,
      decoration: BoxDecoration(
        color: g.spiritualTileSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: g.spiritualChip,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tile.icon, size: 24, color: g.spiritualIcon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tile.title,
                    style: GoogleFonts.amiri(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: g.spiritualOnContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tile.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.tajawal(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      color: g.spiritualOnContainerMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: g.spiritualOnContainerMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── لبنات مشتركة ───────────────────────────

/// غلاف تفاعل قابل للضغط: انكماش scale 0.97 @180ms easeOutCubic + ريبل،
/// يحترم «تقليل الحركة» (مدة صفر عندها). الظل خارج قصّ الريبل ليبقى ظاهرًا.
class _Pressable extends StatefulWidget {
  final VoidCallback onTap;
  final BorderRadius radius;
  final BoxDecoration decoration;
  final EdgeInsetsGeometry padding;
  final Color splash;
  final String semanticLabel;
  final Widget child;
  const _Pressable({
    required this.onTap,
    required this.radius,
    required this.decoration,
    required this.padding,
    required this.splash,
    required this.semanticLabel,
    required this.child,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: (_pressed && !reduce) ? 0.97 : 1.0,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Semantics(
        button: true,
        label: widget.semanticLabel,
        child: DecoratedBox(
          decoration: widget.decoration,
          child: Material(
            color: Colors.transparent,
            borderRadius: widget.radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              splashColor: widget.splash,
              highlightColor: Colors.transparent,
              onHighlightChanged: (v) {
                if (mounted) setState(() => _pressed = v);
              },
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// ظهور متتابع لقسم: تلاشٍ + انزلاق لأعلى 280ms بمنحنى Emphasized-Decelerate،
/// بتأخير 40ms لكل قسم. عند «تقليل الحركة» يكون controller ثابتًا عند 1.
class _Entrance extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final int total;
  final Widget child;
  const _Entrance({
    required this.controller,
    required this.index,
    required this.total,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const sectionMs = 280;
    const staggerMs = 40;
    final totalMs = (sectionMs + staggerMs * (total - 1)).toDouble();
    final begin = (index * staggerMs) / totalMs;
    final end = ((index * staggerMs) + sectionMs) / totalMs;
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: const Cubic(0.05, 0.7, 0.1, 1.0)),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

// ─────────────────────────── نماذج البيانات ───────────────────────────

class _ServiceGroup {
  final String title;
  final _GroupKind kind;
  final List<_ServiceTile> tiles;
  _ServiceGroup(this.title, this.kind, this.tiles);
}

class _ServiceTile {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() builder;
  _ServiceTile(this.id, this.title, this.subtitle, this.icon, this.builder);
}

/// تبويبات المواعيد/التذكيرات/المهام في شاشة واحدة.
/// (تُستخدم أيضًا من home_screen.dart — يبقى الاسم كما هو.)
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
