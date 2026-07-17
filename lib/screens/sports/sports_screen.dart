import 'package:flutter/material.dart';
import '../../services/sports_service.dart';
import '../../theme/jasir_theme.dart';
import '../../widgets/jasir_spinner.dart';

/// «الرياضة» — خفيفة عمداً: متابعة أي فريق عالمياً (بحث TheSportsDB عبر
/// السيرفر مع كاش هناك)، ولكل فريق: آخر النتائج، القادمة، وترتيب دوريه.
class SportsScreen extends StatefulWidget {
  const SportsScreen({super.key});

  @override
  State<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends State<SportsScreen> {
  final _service = SportsService();
  List<SportsTeam> _teams = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final t = await _service.followed();
      if (!mounted) return;
      setState(() {
        _teams = t;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _openSearch() async {
    final followedIds = _teams.map((t) => t.id).toSet();
    await showSearch<bool?>(
      context: context,
      delegate: _TeamSearchDelegate(_service, followedIds),
    );
    // ننعش دائماً: الرجوع بالسحب على iOS يرجع null حتى لو أُضيف فريق
    _reload();
  }

  Future<void> _unfollow(SportsTeam t) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إلغاء متابعة ${t.name}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إلغاء المتابعة')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await _service.unfollow(t.id);
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر الحذف — تحقق من الاتصال')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرياضة'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch, tooltip: 'ابحث عن فريق'),
        ],
      ),
      body: _loading
          ? const Center(child: JasirSpinner())
          : _error
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('تعذر التحميل', style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      OutlinedButton(
                          onPressed: () {
                            setState(() => _loading = true);
                            _reload();
                          },
                          child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _teams.isEmpty
                  ? _empty(context)
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _teams.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _teamCard(_teams[i]),
                      ),
                    ),
    );
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: g.dailyContainer, shape: BoxShape.circle),
            child: Icon(Icons.sports_soccer_outlined, size: 44, color: cs.onSurfaceVariant.withOpacity(0.6)),
          ),
          const SizedBox(height: 12),
          Text('تابع فرقك المفضلة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('ابحث عن أي فريق في العالم وأضِفه',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
            label: const Text('ابحث عن فريق'),
          ),
        ],
      ),
    );
  }

  Widget _teamCard(SportsTeam t) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    // league مخزنة بصيغة "اسم الدوري|معرفه"
    final leagueName = t.league.split('|').first;
    // حذف بطريقتين: سحب البطاقة، أو زر النجمة — كلاهما بتأكيد
    return Dismissible(
      key: ValueKey('team_${t.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final sure = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('إلغاء متابعة ${t.name}؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إلغاء المتابعة')),
            ],
          ),
        );
        if (sure != true) return false;
        try {
          await _service.unfollow(t.id);
          return true;
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('تعذر الحذف — تحقق من الاتصال')));
          }
          return false;
        }
      },
      onDismissed: (_) => setState(() => _teams.removeWhere((x) => x.id == t.id)),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(18)),
        child: Icon(Icons.delete_outline, color: cs.onError),
      ),
      child: _teamCardBody(t, cs, g, leagueName),
    );
  }

  Widget _teamCardBody(SportsTeam t, ColorScheme cs, JasirGroupColors g, String leagueName) {
    return Container(
      decoration: BoxDecoration(
        color: g.tileSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: g.tileShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TeamDetailScreen(team: t)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: g.dailyChip,
                  child: Icon(Icons.shield_outlined, color: g.dailyIcon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: Theme.of(context).textTheme.titleMedium),
                      if (leagueName.isNotEmpty)
                        Text(leagueName,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.star, color: cs.tertiary),
                  onPressed: () => _unfollow(t),
                  tooltip: 'إلغاء المتابعة',
                ),
                Icon(Icons.chevron_left, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// بحث عالمي عن فريق — نتيجة الإغلاق true تعني تمت إضافة فريق.
class _TeamSearchDelegate extends SearchDelegate<bool?> {
  final SportsService service;
  final Set<String> followedIds;

  _TeamSearchDelegate(this.service, this.followedIds)
      : super(searchFieldLabel: 'اسم الفريق (مثال: الهلال، Real Madrid)');

  bool _added = false;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => close(context, _added));

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);

  @override
  Widget buildResults(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (query.trim().length < 2) {
      return Center(
        child: Text('اكتب اسم الفريق للبحث', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return FutureBuilder<List<SportsTeam>>(
      future: service.search(query.trim()),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: JasirSpinner());
        }
        final teams = snap.data ?? [];
        if (teams.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'ما لقينا الفريق — جرّب الاسم بالإنجليزي',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          );
        }
        return StatefulBuilder(
          builder: (context, setSheet) => ListView.builder(
            itemCount: teams.length,
            itemBuilder: (context, i) {
              final t = teams[i];
              final followed = followedIds.contains(t.id);
              return ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(t.name),
                subtitle: Text(t.league),
                trailing: IconButton(
                  icon: Icon(
                    followed ? Icons.star : Icons.star_border,
                    color: followed ? Theme.of(context).colorScheme.tertiary : null,
                  ),
                  onPressed: followed
                      ? null
                      : () async {
                          // نلتقط الـ messenger قبل await — قد يُغلق البحث أثناء الطلب
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          try {
                            await service.follow(t);
                            followedIds.add(t.id);
                            _added = true;
                            setSheet(() {});
                            messenger?.showSnackBar(SnackBar(content: Text('تُتابع الآن ${t.name} ⭐')));
                          } catch (_) {
                            messenger?.showSnackBar(const SnackBar(content: Text('تعذرت الإضافة')));
                          }
                        },
                ),
              );
            },
          ),
        );
      },
    );
  }

}

/// تفاصيل فريق: ٣ تبويبات كسولة — النتائج/القادمة/الترتيب.
class TeamDetailScreen extends StatelessWidget {
  final SportsTeam team;
  const TeamDetailScreen({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(team.name),
          bottom: const TabBar(tabs: [
            Tab(text: 'النتائج'),
            Tab(text: 'القادمة'),
            Tab(text: 'الترتيب'),
          ]),
        ),
        body: TabBarView(children: [
          _MatchesTab(team: team, upcoming: false),
          _MatchesTab(team: team, upcoming: true),
          _TableTab(team: team),
        ]),
      ),
    );
  }
}

class _MatchesTab extends StatefulWidget {
  final SportsTeam team;
  final bool upcoming;
  const _MatchesTab({required this.team, required this.upcoming});

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<_MatchesTab> with AutomaticKeepAliveClientMixin {
  late Future<List<SportsMatch>> _future;

  @override
  bool get wantKeepAlive => true; // تحميل كسول: مرة واحدة لكل تبويب

  @override
  void initState() {
    super.initState();
    _future = widget.upcoming
        ? SportsService().nextMatches(widget.team.id)
        : SportsService().lastMatches(widget.team.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return FutureBuilder<List<SportsMatch>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: JasirSpinner());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('تعذر التحديث', style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _future = widget.upcoming
                        ? SportsService().nextMatches(widget.team.id)
                        : SportsService().lastMatches(widget.team.id);
                  }),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }
        final matches = snap.data ?? [];
        if (matches.isEmpty) {
          return Center(
            child: Text(
              widget.upcoming ? 'لا مباريات قادمة معلنة' : 'لا نتائج حديثة',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: matches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final m = matches[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: g.tileSurface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: g.tileShadow,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(m.home, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: g.dailyChip, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          m.played ? '${m.homeScore} - ${m.awayScore}' : 'vs',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Expanded(child: Text(m.away, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.upcoming) ...[
                        Icon(Icons.schedule, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${m.date}${m.time.isNotEmpty ? '  •  ${m.time.substring(0, m.time.length >= 5 ? 5 : m.time.length)}' : ''}${m.league.isNotEmpty ? '  •  ${m.league}' : ''}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TableTab extends StatefulWidget {
  final SportsTeam team;
  const _TableTab({required this.team});

  @override
  State<_TableTab> createState() => _TableTabState();
}

class _TableTabState extends State<_TableTab> with AutomaticKeepAliveClientMixin {
  Future<(String, List<TableRow_>)>? _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // من معرف الفريق دائماً — السيرفر يحل الدوري بنفسه (يصلح الفرق القديمة)
    _future = SportsService().teamTable(widget.team.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    if (_future == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'الترتيب غير متاح لهذا الفريق — أعد إضافته من البحث لتحديث بيانات دوريه',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    return FutureBuilder<(String, List<TableRow_>)>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: JasirSpinner());
        }
        final (season, rows) = snap.data ?? ('', <TableRow_>[]);
        if (rows.isEmpty) {
          return Center(
            child: Text('الترتيب غير متاح حالياً', style: TextStyle(color: cs.onSurfaceVariant)),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (season.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('موسم $season',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              ),
            Container(
              decoration: BoxDecoration(
                color: g.tileSurface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: g.tileShadow,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(width: 28, child: Text('#', style: Theme.of(context).textTheme.labelMedium)),
                        Expanded(child: Text('الفريق', style: Theme.of(context).textTheme.labelMedium)),
                        SizedBox(width: 40, child: Text('لعب', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium)),
                        SizedBox(width: 44, child: Text('نقاط', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium)),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: cs.outlineVariant),
                  for (final r in rows)
                    Container(
                      color: r.team == widget.team.name ? g.dailyContainer : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(width: 28, child: Text('${r.rank}')),
                          Expanded(
                            child: Text(
                              r.team,
                              style: TextStyle(
                                fontWeight: r.team == widget.team.name ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                          SizedBox(width: 40, child: Text('${r.played}', textAlign: TextAlign.center)),
                          SizedBox(width: 44, child: Text('${r.points}', textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
