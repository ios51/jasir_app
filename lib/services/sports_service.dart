import 'package:dio/dio.dart';
import 'api_client.dart';

/// فريق متابَع أو نتيجة بحث من TheSportsDB (عبر السيرفر — مع كاش هناك).
class SportsTeam {
  final String id;
  final String name;
  final String league;
  final String leagueId;
  final String badge; // رابط الشعار (قد يكون فارغاً)

  SportsTeam({required this.id, required this.name, required this.league, required this.leagueId, required this.badge});

  factory SportsTeam.fromSearch(Map<String, dynamic> j) => SportsTeam(
        id: (j['idTeam'] ?? '').toString(),
        name: (j['strTeam'] ?? '').toString(),
        league: (j['strLeague'] ?? '').toString(),
        leagueId: (j['idLeague'] ?? '').toString(),
        badge: (j['strBadge'] ?? j['strTeamBadge'] ?? '').toString(),
      );

  factory SportsTeam.fromFollow(Map<String, dynamic> j) => SportsTeam(
        id: (j['team_id'] ?? '').toString(),
        name: (j['team_name'] ?? '').toString(),
        league: (j['league'] ?? '').toString(),
        leagueId: '',
        badge: '',
      );
}

/// مباراة (نتيجة أو قادمة).
class SportsMatch {
  final String home;
  final String away;
  final String homeScore;
  final String awayScore;
  final String date;
  final String time;
  final String league;

  SportsMatch({required this.home, required this.away, required this.homeScore, required this.awayScore, required this.date, required this.time, required this.league});

  bool get played => homeScore.isNotEmpty;

  factory SportsMatch.fromJson(Map<String, dynamic> j) => SportsMatch(
        home: (j['strHomeTeam'] ?? '').toString(),
        away: (j['strAwayTeam'] ?? '').toString(),
        homeScore: (j['intHomeScore'] ?? '').toString().replaceAll('null', ''),
        awayScore: (j['intAwayScore'] ?? '').toString().replaceAll('null', ''),
        date: (j['dateEvent'] ?? '').toString(),
        time: ((j['strTimeLocal'] ?? j['strTime']) ?? '').toString(),
        league: (j['strLeague'] ?? '').toString(),
      );
}

/// دوري (نتيجة بحث أو متابَع).
class SportsLeague {
  final String id;
  final String name; // الاسم المعروض (معرّب إن توفر)

  SportsLeague({required this.id, required this.name});

  factory SportsLeague.fromSearch(Map<String, dynamic> j) {
    final ar = (j['strLeagueAr'] ?? '').toString();
    final en = (j['strLeague'] ?? '').toString();
    return SportsLeague(
      id: (j['idLeague'] ?? '').toString(),
      name: ar.isNotEmpty ? ar : en,
    );
  }

  factory SportsLeague.fromFollow(Map<String, dynamic> j) => SportsLeague(
        id: (j['league_id'] ?? '').toString(),
        name: (j['league_name'] ?? '').toString(),
      );
}

/// مباراة جارية الآن.
class LiveMatch {
  final String home;
  final String away;
  final String homeScore;
  final String awayScore;
  final String progress; // الدقيقة/الشوط
  final String league;

  LiveMatch({required this.home, required this.away, required this.homeScore, required this.awayScore, required this.progress, required this.league});

  factory LiveMatch.fromJson(Map<String, dynamic> j) => LiveMatch(
        home: (j['strHomeTeam'] ?? '').toString(),
        away: (j['strAwayTeam'] ?? '').toString(),
        homeScore: (j['intHomeScore'] ?? '0').toString(),
        awayScore: (j['intAwayScore'] ?? '0').toString(),
        progress: (j['strProgress'] ?? '').toString(),
        league: (j['strLeague'] ?? '').toString(),
      );
}

/// صف في جدول الترتيب.
class TableRow_ {
  final int rank;
  final String team;
  final int played;
  final int points;

  TableRow_({required this.rank, required this.team, required this.played, required this.points});

  factory TableRow_.fromJson(Map<String, dynamic> j) => TableRow_(
        rank: int.tryParse((j['intRank'] ?? '0').toString()) ?? 0,
        team: (j['strTeam'] ?? '').toString(),
        played: int.tryParse((j['intPlayed'] ?? '0').toString()) ?? 0,
        points: int.tryParse((j['intPoints'] ?? '0').toString()) ?? 0,
      );
}

class SportsService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<SportsTeam>> followed() async {
    final res = await _dio.get('/api/v1/football/follows');
    return ((res.data['teams'] ?? []) as List)
        .map((e) => SportsTeam.fromFollow(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// الفرق والدوريات المتابعة معاً (نداء واحد)
  Future<(List<SportsTeam>, List<SportsLeague>)> followedAll() async {
    final res = await _dio.get('/api/v1/football/follows');
    final teams = ((res.data['teams'] ?? []) as List)
        .map((e) => SportsTeam.fromFollow(Map<String, dynamic>.from(e)))
        .toList();
    final leagues = ((res.data['leagues'] ?? []) as List)
        .map((e) => SportsLeague.fromFollow(Map<String, dynamic>.from(e)))
        .toList();
    return (teams, leagues);
  }

  Future<List<SportsLeague>> searchLeagues(String q) async {
    final res = await _dio.get('/api/v1/football/leagues/search', queryParameters: {'q': q});
    return ((res.data ?? []) as List)
        .map((e) => SportsLeague.fromSearch(Map<String, dynamic>.from(e)))
        .where((l) => l.id.isNotEmpty && l.name.isNotEmpty)
        .toList();
  }

  Future<void> followLeague(SportsLeague l) => _dio.post('/api/v1/football/leagues/follows',
      data: {'leagueId': l.id, 'leagueName': l.name});

  Future<void> unfollowLeague(String leagueId) =>
      _dio.delete('/api/v1/football/leagues/follows/$leagueId');

  Future<List<SportsMatch>> leagueLast(String leagueId) async {
    final res = await _dio.get('/api/v1/football/league/$leagueId/last');
    return ((res.data ?? []) as List).map((e) => SportsMatch.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<SportsMatch>> leagueNext(String leagueId) async {
    final res = await _dio.get('/api/v1/football/league/$leagueId/next');
    return ((res.data ?? []) as List).map((e) => SportsMatch.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// إعداد تنبيهات الأهداف: all | important6 | important10 | off
  Future<String> alertsMode() async {
    try {
      final res = await _dio.get('/api/v1/football/alerts');
      return (res.data['mode'] ?? 'all').toString();
    } catch (_) {
      return 'all';
    }
  }

  Future<void> setAlertsMode(String mode) =>
      _dio.put('/api/v1/football/alerts', data: {'mode': mode});

  /// المباريات الجارية الآن لفرقي المتابعة
  Future<List<LiveMatch>> live() async {
    final res = await _dio.get('/api/v1/football/live');
    return ((res.data ?? []) as List).map((e) => LiveMatch.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<SportsTeam>> search(String q) async {
    final res = await _dio.get('/api/v1/football/search', queryParameters: {'q': q});
    return ((res.data ?? []) as List)
        .map((e) => SportsTeam.fromSearch(Map<String, dynamic>.from(e)))
        .where((t) => t.id.isNotEmpty && t.name.isNotEmpty)
        .toList();
  }

  Future<void> follow(SportsTeam t) => _dio.post('/api/v1/football/follows', data: {
        'teamId': t.id,
        'teamName': t.name,
        'league': '${t.league}|${t.leagueId}',
      });

  Future<void> unfollow(String teamId) => _dio.delete('/api/v1/football/follows/$teamId');

  Future<List<SportsMatch>> lastMatches(String teamId) async {
    final res = await _dio.get('/api/v1/football/team/$teamId/last');
    return ((res.data ?? []) as List).map((e) => SportsMatch.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<SportsMatch>> nextMatches(String teamId) async {
    final res = await _dio.get('/api/v1/football/team/$teamId/next');
    return ((res.data ?? []) as List).map((e) => SportsMatch.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// ترتيب دوري الفريق من معرف الفريق مباشرة — يعمل حتى لو ما خُزّن
  /// معرف الدوري وقت المتابعة.
  Future<(String, List<TableRow_>)> teamTable(String teamId) async {
    final res = await _dio.get('/api/v1/football/team/$teamId/table');
    final rows = ((res.data['table'] ?? []) as List)
        .map((e) => TableRow_.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ((res.data['season'] ?? '').toString(), rows);
  }

  Future<(String, List<TableRow_>)> leagueTable(String leagueId) async {
    final res = await _dio.get('/api/v1/football/table/$leagueId');
    final rows = ((res.data['table'] ?? []) as List)
        .map((e) => TableRow_.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ((res.data['season'] ?? '').toString(), rows);
  }
}
