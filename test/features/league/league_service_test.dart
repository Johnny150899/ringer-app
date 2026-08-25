import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/features/league/data/services/league_cache_store.dart';
import 'package:ringer_app/features/league/data/services/league_service.dart';
import 'package:ringer_app/features/league/domain/models/league_overview.dart';
import 'package:ringer_app/features/league/domain/models/league_team_config.dart';
import 'package:ringer_app/features/matches/data/services/ligadb_service.dart';
import 'package:ringer_app/features/matches/domain/models/team_match.dart';

void main() {
  group('LeagueService', () {
    test(
      'erkennt eine neue Saison und beide Mannschaften automatisch',
      () async {
        final api = _FakeLigaDbService(currentSeason: 2027);
        final service = LeagueService(
          ligaDbService: api,
          cacheStore: _MemoryLeagueCache(),
        );

        final first = await service.loadPage(teamIndex: 1);
        final second = await service.loadPage(season: 2027, teamIndex: 2);

        expect(first.config.season, 2027);
        expect(first.config.leagueId, 2001);
        expect(first.config.teamId, 3001);
        expect(second.config.leagueId, 2002);
        expect(second.config.teamId, 3002);
        expect(first.seasons, [2027, 2026, 2025, 2024]);
        expect(api.getCurrentSeasonCalls, 1);
      },
    );

    test('liefert bei einem Netzwerkfehler den letzten Cache-Stand', () async {
      final cache = _MemoryLeagueCache();
      final config = const LeagueTeamConfig(
        season: 2026,
        teamIndex: 1,
        leagueId: 1227,
        teamId: 13215,
        label: '1. Mannschaft',
      );
      await cache.saveConfigs(2026, [config]);
      await cache.saveOverview(
        config,
        LeagueOverview(
          standings: const [],
          matches: const [],
          teamId: config.teamId,
        ),
      );
      final service = LeagueService(
        ligaDbService: _FakeLigaDbService(fail: true),
        cacheStore: cache,
      );

      final page = await service.loadPage(season: 2026);

      expect(page.isCached, isTrue);
      expect(page.overview.teamId, 13215);
    });

    test('leere Saison bleibt gültig und zeigt null Spiele', () async {
      final service = LeagueService(
        ligaDbService: _FakeLigaDbService(currentSeason: 2027),
        cacheStore: _MemoryLeagueCache(),
      );

      final page = await service.loadPage(season: 2027);

      expect(page.overview.matches, isEmpty);
      expect(page.overview.ownStanding?.matches, 0);
    });

    test('bekannte historische Saison ueberspringt die Liga-Suche', () async {
      final api = _FakeLigaDbService();
      final service = LeagueService(
        ligaDbService: api,
        cacheStore: _MemoryLeagueCache(),
      );

      final page = await service.loadPage(season: 2023);

      expect(page.config.leagueId, 1054);
      expect(page.config.teamId, 11695);
      expect(api.getLeaguesCalls, 0);
    });
  });
}

class _FakeLigaDbService extends LigaDbService {
  _FakeLigaDbService({this.currentSeason = 2026, this.fail = false});

  final int currentSeason;
  final bool fail;
  int getCurrentSeasonCalls = 0;
  int getLeaguesCalls = 0;

  void _check() {
    if (fail) throw Exception('offline');
  }

  @override
  Future<int> getCurrentSeason() async {
    _check();
    getCurrentSeasonCalls++;
    return currentSeason;
  }

  @override
  Future<List<int>> getAllSeasons() async {
    _check();
    return [currentSeason, 2026, 2025, 2024, 2023];
  }

  @override
  Future<List<Map<String, dynamic>>> getLeagues(int season) async {
    _check();
    getLeaguesCalls++;
    return const [
      {'SaisonLigaID': 2001, 'VerbandsregionName': 'Nordbaden'},
      {'SaisonLigaID': 2002, 'VerbandsregionName': 'Nordbaden'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getLeagueTeams(int id) async {
    _check();
    return [
      {
        'OrgID': 165,
        'TeamID': id == 2001 ? 3001 : 3002,
        'TeamIndex': id == 2001 ? 1 : 2,
        'TeamName': id == 2001 ? 'KSC Olympia' : 'KSC Olympia II',
      },
      const {'OrgID': 999, 'TeamID': 9999, 'TeamName': 'Gegner'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getLeagueTable(int id) async {
    _check();
    return const [];
  }

  @override
  Future<List<TeamMatch>> getLeagueMatches(int id) async {
    _check();
    return const [];
  }
}

class _MemoryLeagueCache implements LeagueCacheStore {
  final Map<String, LeagueOverview> _overviews = {};
  final Map<int, List<LeagueTeamConfig>> _configs = {};

  @override
  Future<LeagueOverview?> readOverview(LeagueTeamConfig config) async =>
      _overviews['${config.season}.${config.teamIndex}'];

  @override
  Future<void> saveOverview(
    LeagueTeamConfig config,
    LeagueOverview overview,
  ) async {
    _overviews['${config.season}.${config.teamIndex}'] = overview;
  }

  @override
  Future<List<LeagueTeamConfig>?> readConfigs(int season) async =>
      _configs[season];

  @override
  Future<void> saveConfigs(int season, List<LeagueTeamConfig> configs) async {
    _configs[season] = configs;
  }
}
