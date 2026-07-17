import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/sports_service.dart';
import '../../theme/jasir_theme.dart';
import '../../widgets/jasir_spinner.dart';

/// «الرياضة» — متابعة الفرق **والدوريات** عالمياً:
/// قسم «مباشر الآن» (يتحدث كل دقيقة أثناء فتح الشاشة)، فرقي، دورياتي،
/// وبحث موحد يرجع دوريات وفرقاً معاً. الأسماء معربة من السيرفر.
class SportsScreen extends StatefulWidget {
  const SportsScreen({super.key});

  @override
  State<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends State<SportsScreen> {
  final _service = SportsService();
  List<SportsTeam> _teams = [];
  List<SportsLeague> _leagues = [];
  List<LiveMatch> _live = [];
  bool _loading = true;
  bool _error = false;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _reload();
    // المباشر يتحدث كل دقيقة ما دامت الشاشة مفتوحة (المزود يحدّث كل دقيقتين)
    _liveTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshLive());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final (teams, leagues) = await _service.followedAll();
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _leagues = leagues;
        _loading = false;
        _error = false;
      });
      _refreshLive();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _refreshLive() async {
    if (_teams.isEmpty) {
      if (_live.isNotEmpty && mounted) setState(() => _live = []);
      return;
    }
    try {
      final live = await _service.live();
      if (mounted) setState(() => _live = live);
    } catch (_) {/* المباشر كماليّ */}
  }

  Future<void> _openSearch() async {
    await showSearch<bool?>(
      context: context,
      delegate: _SportsSearchDelegate(
        _service,
        _teams.map((t) => t.id).toSet(),
        _leagues.map((l) => l.id).toSet(),
      ),
    );
    _reload(); // ننعش دائماً — الرجوع بالسحب يرجع null
  }

  Future<bool> _confirm(String title) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إلغاء المتابعة')),
        ],
      ),
    );
    return sure == true;
  }

  Future<void> _unfollowTeam(SportsTeam t) async {
    if (!await _confirm('إلغاء متابعة ${t.name}؟')) return;
    try {
      await _service.unfollow(t.id);
      _reload();
    } catch (_) {
      _netError();
    }
  }

  Future<void> _unfollowLeague(SportsLeague l) async {
    if (!await _confirm('إلغاء متابعة ${l.name}؟')) return;
    try {
      await _service.unfollowLeague(l.id);
      _reload();
    } catch (_) {
      _netError();
    }
  }

  void _netError() {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر التنفيذ — تحقق من الاتصال')));
    }
  }

  /// إعداد تنبيهات الأهداف: بدون / المهمة فقط (قمة 6 أو 10) / كل مباريات فرقي
  Future<void> _openAlertSettings() async {
    var mode = await _service.alertsMode();
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget option(String value, String title, String subtitle, IconData icon) => RadioListTile<String>(
                value: value,
                groupValue: mode,
                onChanged: (v) => setSheet(() => mode = v!),
                title: Row(children: [
                  Icon(icon, size: 20, color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title),
                ]),
                subtitle: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 28),
                  child: Text(subtitle),
                ),
              );
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('تنبيهات الأهداف',
                      textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleMedium),
                ),
                const SizedBox(height: 6),
                option('all', 'كل مباريات فرقي', 'هدف في أي مباراة لفرقك المتابعة', Icons.sports_soccer),
                option('important6', 'المهمة فقط — قمة الـ٦', 'فقط عندما يلتقي فريقان من أول ٦ بالترتيب', Icons.local_fire_department_outlined),
                option('important10', 'المهمة فقط — قمة الـ١٠', 'فقط عندما يلتقي فريقان من أول ١٠ بالترتيب', Icons.local_fire_department_outlined),
                option('off', 'بدون تنبيهات', 'الرياضة بلا أي إشعارات', Icons.notifications_off_outlined),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, mode),
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await _service.setAlertsMode(picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حُفظ إعداد التنبيهات ✅')));
      }
    } catch (_) {
      _netError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرياضة'),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: _openAlertSettings,
              tooltip: 'تنبيهات الأهداف'),
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch, tooltip: 'ابحث عن فريق أو دوري'),
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
              : (_teams.isEmpty && _leagues.isEmpty)
                  ? _empty(context)
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (_live.isNotEmpty) ...[
                            _sectionTitle('مباشر الآن 🔴'),
                            for (final m in _live) _liveCard(m),
                            const SizedBox(height: 10),
                          ],
                          if (_teams.isNotEmpty) ...[
                            _sectionTitle('فرقي'),
                            for (final t in _teams) _teamCard(t),
                            const SizedBox(height: 10),
                          ],
                          if (_leagues.isNotEmpty) ...[
                            _sectionTitle('دورياتي'),
                            for (final l in _leagues) _leagueCard(l),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 6, top: 4, bottom: 6),
        child: Text(t,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

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
          Text('تابع فرقك ودورياتك المفضلة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('ابحث عن أي فريق أو دوري في العالم',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
            label: const Text('ابحث'),
          ),
        ],
      ),
    );
  }

  // ── بطاقة مباراة مباشرة ──
  Widget _liveCard(LiveMatch m) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: g.tileSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withOpacity(0.5)),
        boxShadow: g.tileShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(m.home, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
                child: Text('${m.homeScore} - ${m.awayScore}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onErrorContainer)),
              ),
              Expanded(child: Text(m.away, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [if (m.progress.isNotEmpty) m.progress, if (m.league.isNotEmpty) m.league].join('  •  '),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ── بطاقة فريق ──
  Widget _teamCard(SportsTeam t) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    final leagueName = t.league.split('|').first;
    return Dismissible(
      key: ValueKey('team_${t.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        if (!await _confirm('إلغاء متابعة ${t.name}؟')) return false;
        try {
          await _service.unfollow(t.id);
          return true;
        } catch (_) {
          _netError();
          return false;
        }
      },
      onDismissed: (_) => setState(() => _teams.removeWhere((x) => x.id == t.id)),
      background: _swipeBg(cs),
      child: _card(
        leading: CircleAvatar(backgroundColor: g.dailyChip, child: Icon(Icons.shield_outlined, color: g.dailyIcon)),
        title: t.name,
        subtitle: leagueName,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamDetailScreen(team: t))),
        trailing: IconButton(
          icon: Icon(Icons.star, color: cs.tertiary),
          onPressed: () => _unfollowTeam(t),
          tooltip: 'إلغاء المتابعة',
        ),
      ),
    );
  }

  // ── بطاقة دوري ──
  Widget _leagueCard(SportsLeague l) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return Dismissible(
      key: ValueKey('league_${l.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        if (!await _confirm('إلغاء متابعة ${l.name}؟')) return false;
        try {
          await _service.unfollowLeague(l.id);
          return true;
        } catch (_) {
          _netError();
          return false;
        }
      },
      onDismissed: (_) => setState(() => _leagues.removeWhere((x) => x.id == l.id)),
      background: _swipeBg(cs),
      child: _card(
        leading: CircleAvatar(backgroundColor: g.dailyChip, child: Icon(Icons.emoji_events_outlined, color: g.dailyIcon)),
        title: l.name,
        subtitle: '',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeagueDetailScreen(league: l))),
        trailing: IconButton(
          icon: Icon(Icons.star, color: cs.tertiary),
          onPressed: () => _unfollowLeague(l),
          tooltip: 'إلغاء المتابعة',
        ),
      ),
    );
  }

  Widget _swipeBg(ColorScheme cs) => Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(18)),
        child: Icon(Icons.delete_outline, color: cs.onError),
      );

  Widget _card({required Widget leading, required String title, required String subtitle, required VoidCallback onTap, required Widget trailing}) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: g.tileSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: g.tileShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                trailing,
                Icon(Icons.chevron_left, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// بحث موحد: دوريات + فرق.
class _SportsSearchDelegate extends SearchDelegate<bool?> {
  final SportsService service;
  final Set<String> followedTeamIds;
  final Set<String> followedLeagueIds;

  _SportsSearchDelegate(this.service, this.followedTeamIds, this.followedLeagueIds)
      : super(searchFieldLabel: 'فريق أو دوري (الهلال، الدوري الإنجليزي…)');

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => close(context, null));

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);

  @override
  Widget buildResults(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (query.trim().length < 2) {
      return Center(child: Text('اكتب اسم الفريق أو الدوري', style: TextStyle(color: cs.onSurfaceVariant)));
    }
    final q = query.trim();
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        service.searchLeagues(q).catchError((_) => <SportsLeague>[]),
        service.search(q).catchError((_) => <SportsTeam>[]),
      ]),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: JasirSpinner());
        }
        final leagues = (snap.data?[0] as List<SportsLeague>?) ?? [];
        final teams = (snap.data?[1] as List<SportsTeam>?) ?? [];
        if (leagues.isEmpty && teams.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('ما لقينا نتائج — جرّب الاسم بالإنجليزي',
                  textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          );
        }
        return StatefulBuilder(
          builder: (context, setSheet) => ListView(
            children: [
              if (leagues.isNotEmpty) ...[
                _groupHeader(context, 'دوريات'),
                for (final l in leagues)
                  ListTile(
                    leading: const Icon(Icons.emoji_events_outlined),
                    title: Text(l.name),
                    trailing: _starButton(
                      context,
                      followed: followedLeagueIds.contains(l.id),
                      onFollow: () async {
                        await service.followLeague(l);
                        followedLeagueIds.add(l.id);
                        setSheet(() {});
                        return 'تُتابع الآن ${l.name} ⭐';
                      },
                    ),
                  ),
              ],
              if (teams.isNotEmpty) ...[
                _groupHeader(context, 'فرق'),
                for (final t in teams)
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(t.name),
                    subtitle: Text(t.league),
                    trailing: _starButton(
                      context,
                      followed: followedTeamIds.contains(t.id),
                      onFollow: () async {
                        await service.follow(t);
                        followedTeamIds.add(t.id);
                        setSheet(() {});
                        return 'تُتابع الآن ${t.name} ⭐';
                      },
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _groupHeader(BuildContext context, String t) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _starButton(BuildContext context, {required bool followed, required Future<String> Function() onFollow}) {
    return IconButton(
      icon: Icon(
        followed ? Icons.star : Icons.star_border,
        color: followed ? Theme.of(context).colorScheme.tertiary : null,
      ),
      onPressed: followed
          ? null
          : () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              try {
                final msg = await onFollow();
                messenger?.showSnackBar(SnackBar(content: Text(msg)));
              } catch (_) {
                messenger?.showSnackBar(const SnackBar(content: Text('تعذرت الإضافة')));
              }
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
    final s = SportsService();
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
          _MatchesTab(loader: () => s.lastMatches(team.id), emptyText: 'لا نتائج حديثة', upcoming: false),
          _MatchesTab(loader: () => s.nextMatches(team.id), emptyText: 'لا مباريات قادمة معلنة', upcoming: true),
          _TableTab(loader: () => s.teamTable(team.id), highlightTeam: team.name),
        ]),
      ),
    );
  }
}

/// تفاصيل دوري: ٣ تبويبات كسولة — النتائج/القادمة/الترتيب.
class LeagueDetailScreen extends StatelessWidget {
  final SportsLeague league;
  const LeagueDetailScreen({super.key, required this.league});

  @override
  Widget build(BuildContext context) {
    final s = SportsService();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(league.name),
          bottom: const TabBar(tabs: [
            Tab(text: 'النتائج'),
            Tab(text: 'القادمة'),
            Tab(text: 'الترتيب'),
          ]),
        ),
        body: TabBarView(children: [
          _MatchesTab(loader: () => s.leagueLast(league.id), emptyText: 'لا نتائج حديثة', upcoming: false),
          _MatchesTab(loader: () => s.leagueNext(league.id), emptyText: 'لا مباريات قادمة معلنة', upcoming: true),
          _TableTab(loader: () => s.leagueTable(league.id)),
        ]),
      ),
    );
  }
}

class _MatchesTab extends StatefulWidget {
  final Future<List<SportsMatch>> Function() loader;
  final String emptyText;
  final bool upcoming;
  const _MatchesTab({required this.loader, required this.emptyText, required this.upcoming});

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
    _future = widget.loader();
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
                  onPressed: () => setState(() => _future = widget.loader()),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }
        final matches = snap.data ?? [];
        if (matches.isEmpty) {
          return Center(child: Text(widget.emptyText, style: TextStyle(color: cs.onSurfaceVariant)));
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
                      Flexible(
                        child: Text(
                          '${m.date}${m.time.isNotEmpty ? '  •  ${m.time.substring(0, m.time.length >= 5 ? 5 : m.time.length)}' : ''}${m.league.isNotEmpty ? '  •  ${m.league}' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
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
  final Future<(String, List<TableRow_>)> Function() loader;
  final String? highlightTeam;
  const _TableTab({required this.loader, this.highlightTeam});

  @override
  State<_TableTab> createState() => _TableTabState();
}

class _TableTabState extends State<_TableTab> with AutomaticKeepAliveClientMixin {
  late Future<(String, List<TableRow_>)> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<JasirGroupColors>()!;
    return FutureBuilder<(String, List<TableRow_>)>(
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
                  onPressed: () => setState(() => _future = widget.loader()),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }
        final (season, rows) = snap.data ?? ('', <TableRow_>[]);
        if (rows.isEmpty) {
          return Center(child: Text('الترتيب غير متاح حالياً', style: TextStyle(color: cs.onSurfaceVariant)));
        }
        final hl = widget.highlightTeam;
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
                      color: hl != null && r.team == hl ? g.dailyContainer : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(width: 28, child: Text('${r.rank}')),
                          Expanded(
                            child: Text(
                              r.team,
                              style: TextStyle(
                                fontWeight: hl != null && r.team == hl ? FontWeight.w700 : FontWeight.w400,
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
