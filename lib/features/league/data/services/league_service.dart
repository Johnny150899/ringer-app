import '../../../matches/data/services/ligadb_service.dart';
import '../../../matches/domain/models/team_match.dart';
import '../../domain/models/league_overview.dart';
import '../../domain/models/league_page_data.dart';
import '../../domain/models/league_standing.dart';
import '../../domain/models/league_team_config.dart';
import 'league_cache_store.dart';

class LeagueService {
  LeagueService({LigaDbService? ligaDbService, LeagueCacheStore? cacheStore})
    : _ligaDbService = ligaDbService ?? LigaDbService(),
      _cacheStore = cacheStore ?? SharedPreferencesLeagueCacheStore(),
      _ownsService = ligaDbService == null;

  static const int kscOrganisationId = 165;
  static const _fallbacks = <int, List<LeagueTeamConfig>>{
    2026: [
      LeagueTeamConfig(
        season: 2026,
        teamIndex: 1,
        leagueId: 1227,
        teamId: 13215,
        label: '1. Mannschaft',
      ),
      LeagueTeamConfig(
        season: 2026,
        teamIndex: 2,
        leagueId: 1225,
        teamId: 13518,
        label: '2. Mannschaft',
      ),
    ],
    2025: [
      LeagueTeamConfig(
        season: 2025,
        teamIndex: 1,
        leagueId: 1189,
        teamId: 12888,
        label: '1. Mannschaft',
      ),
      LeagueTeamConfig(
        season: 2025,
        teamIndex: 2,
        leagueId: 1191,
        teamId: 12904,
        label: '2. Mannschaft',
      ),
    ],
    2024: [
      LeagueTeamConfig(
        season: 2024,
        teamIndex: 1,
        leagueId: 1110,
        teamId: 12199,
        label: '1. Mannschaft',
      ),
      LeagueTeamConfig(
        season: 2024,
        teamIndex: 2,
        leagueId: 1129,
        teamId: 12362,
        label: '2. Mannschaft',
      ),
    ],
    2023: [
      LeagueTeamConfig(
        season: 2023,
        teamIndex: 1,
        leagueId: 1054,
        teamId: 11695,
        label: '1. Mannschaft',
      ),
      LeagueTeamConfig(
        season: 2023,
        teamIndex: 2,
        leagueId: 1064,
        teamId: 11778,
        label: '2. Mannschaft',
      ),
    ],
  };

  final LigaDbService _ligaDbService;
  final LeagueCacheStore _cacheStore;
  final bool _ownsService;
  final Map<int, List<LeagueTeamConfig>> _resolvedSeasons = {};
  Future<List<int>>? _availableSeasonsRequest;

  Future<LeaguePageData> loadPage({int? season, int teamIndex = 1}) async {
    final seasons = await availableSeasons();
    final selectedSeason = season != null && seasons.contains(season)
        ? season
        : seasons.first;
    final configs = await resolveSeason(selectedSeason);
    final config = configs.firstWhere(
      (item) => item.teamIndex == teamIndex,
      orElse: () => configs.first,
    );
    try {
      final overview = await loadOverview(
        leagueId: config.leagueId,
        teamId: config.teamId,
      );
      await _cacheStore.saveOverview(config, overview);
      return LeaguePageData(
        seasons: seasons,
        config: config,
        overview: overview,
      );
    } on Object {
      final cached = await _cacheStore.readOverview(config);
      if (cached == null) rethrow;
      return LeaguePageData(
        seasons: seasons,
        config: config,
        overview: cached,
        isCached: true,
      );
    }
  }

  Future<LeaguePageData?> readCachedPage({
    int? season,
    int teamIndex = 1,
  }) async {
    final seasons = await availableSeasons();
    final selectedSeason = season != null && seasons.contains(season)
        ? season
        : seasons.first;
    final configs = await resolveSeason(selectedSeason);
    final config = configs.firstWhere(
      (item) => item.teamIndex == teamIndex,
      orElse: () => configs.first,
    );
    final overview = await _cacheStore.readOverview(config);
    if (overview == null) return null;
    return LeaguePageData(
      seasons: seasons,
      config: config,
      overview: overview,
      isCached: true,
    );
  }

  Future<List<int>> availableSeasons() =>
      _availableSeasonsRequest ??= _fetchAvailableSeasons();

  Future<List<int>> _fetchAvailableSeasons() async {
    try {
      final current = await _ligaDbService.getCurrentSeason();
      return List<int>.generate(4, (index) => current - index);
    } on Object {
      final latestKnown = _fallbacks.keys.reduce(
        (latest, year) => year > latest ? year : latest,
      );
      return List<int>.generate(4, (index) => latestKnown - index);
    }
  }

  Future<List<LeagueTeamConfig>> resolveSeason(int season) async {
    final resolved = _resolvedSeasons[season];
    if (resolved != null) return resolved;

    // Bekannte Spielzeiten haben stabile Liga- und Mannschafts-IDs. Der
    // direkte Zugriff vermeidet beim Wechsel auf ein altes Jahr eine teure
    // Suche durch sämtliche Nordbaden-Ligen und deren Mannschaften.
    final fallback = _fallbacks[season];
    if (fallback != null) {
      _resolvedSeasons[season] = fallback;
      return fallback;
    }

    final cached = await _cacheStore.readConfigs(season);
    if (cached != null && cached.isNotEmpty) {
      _resolvedSeasons[season] = cached;
      return cached;
    }

    try {
      final discovered = await _discoverSeason(season);
      if (discovered.isNotEmpty) {
        await _cacheStore.saveConfigs(season, discovered);
        _resolvedSeasons[season] = discovered;
        return discovered;
      }
    } on Object {
      // Cache und bekannte IDs werden darunter als robuste Alternative genutzt.
    }
    throw StateError('Für $season wurde keine KSC-Liga gefunden.');
  }

  Future<List<LeagueTeamConfig>> _discoverSeason(int season) async {
    final leagues = await _ligaDbService.getLeagues(season);
    final nordbaden = leagues
        .where((league) {
          final region = league['VerbandsregionName']?.toString().toLowerCase();
          return region?.contains('nordbaden') == true;
        })
        .toList(growable: false);
    final candidates = await Future.wait(
      nordbaden.map((league) async {
        final leagueId = _asInt(league['SaisonLigaID']);
        if (leagueId == null) return const <LeagueTeamConfig>[];
        final List<Map<String, dynamic>> teams;
        try {
          teams = await _ligaDbService.getLeagueTeams(leagueId);
        } on Object {
          return const <LeagueTeamConfig>[];
        }
        final result = <LeagueTeamConfig>[];
        for (final team in teams) {
          if (_asInt(team['OrgID']) != kscOrganisationId) continue;
          final index = _asInt(team['TeamIndex']) ?? _inferTeamIndex(team);
          if (index != 1 && index != 2) continue;
          final teamId = _asInt(team['TeamID']);
          if (teamId == null) continue;
          result.add(
            LeagueTeamConfig(
              season: season,
              teamIndex: index,
              leagueId: leagueId,
              teamId: teamId,
              label: '$index. Mannschaft',
            ),
          );
        }
        return result;
      }),
    );
    final configs = <LeagueTeamConfig>[];
    for (final candidate in candidates.expand((items) => items)) {
      configs.removeWhere((item) => item.teamIndex == candidate.teamIndex);
      configs.add(candidate);
    }
    configs.sort((a, b) => a.teamIndex.compareTo(b.teamIndex));
    return configs;
  }

  int _inferTeamIndex(Map<String, dynamic> team) {
    final name = team['TeamName']?.toString() ?? '';
    return RegExp(r'\bII\b|\b2\b').hasMatch(name) ? 2 : 1;
  }

  Future<LeagueOverview> loadOverview({
    required int leagueId,
    required int teamId,
  }) async {
    final results = await Future.wait([
      _ligaDbService.getLeagueTable(leagueId),
      _ligaDbService.getLeagueTeams(leagueId),
      _ligaDbService.getLeagueMatches(leagueId),
    ]);
    final table = results[0] as List<Map<String, dynamic>>;
    final teams = results[1] as List<Map<String, dynamic>>;
    final matches = results[2] as List<TeamMatch>;
    final records = _records(matches);
    final standings = table.isEmpty
        ? teams.indexed
              .map(
                (entry) => _standingFromTeam(entry.$2, entry.$1 + 1, records),
              )
              .toList()
        : table.map((row) => _standingFromTable(row, records)).toList();
    standings.sort((a, b) => a.position.compareTo(b.position));
    return LeagueOverview(
      standings: standings,
      matches: matches,
      teamId: teamId,
    );
  }

  Map<int, _Record> _records(List<TeamMatch> matches) {
    final records = <int, _Record>{};
    for (final match in matches) {
      final homeId = _asInt(match['MannschaftenIDHeim']);
      final guestId = _asInt(match['MannschaftenIDGast']);
      final homeScore = _asNum(match['PunkteHeimWertung']);
      final guestScore = _asNum(match['PunkteGastWertung']);
      if (homeId == null ||
          guestId == null ||
          homeScore == null ||
          guestScore == null) {
        continue;
      }
      records.putIfAbsent(homeId, _Record.new).add(homeScore, guestScore);
      records.putIfAbsent(guestId, _Record.new).add(guestScore, homeScore);
    }
    return records;
  }

  LeagueStanding _standingFromTeam(
    Map<String, dynamic> team,
    int fallbackPosition,
    Map<int, _Record> records,
  ) {
    final teamId = _asInt(team['TeamID']) ?? 0;
    final record = records[teamId] ?? _Record();
    return LeagueStanding(
      position: fallbackPosition,
      teamId: teamId,
      teamName: _text(team['TeamName']),
      matches: record.matches,
      wins: record.wins,
      losses: record.losses,
      draws: record.draws,
      pointsFor: record.pointsFor,
      pointsAgainst: record.pointsAgainst,
      tablePointsFor: record.tablePointsFor,
      tablePointsAgainst: record.tablePointsAgainst,
    );
  }

  LeagueStanding _standingFromTable(
    Map<String, dynamic> row,
    Map<int, _Record> records,
  ) {
    final teamId = _asInt(row['TeamID']) ?? 0;
    final record = records[teamId] ?? _Record();
    return LeagueStanding(
      position: _asInt(row['Platzierung']) ?? 0,
      teamId: teamId,
      teamName: _text(row['TeamName']),
      matches: _asInt(row['AnzahlKaempfe']) ?? record.matches,
      wins: record.wins,
      losses: record.losses,
      draws: record.draws,
      pointsFor: _asNum(row['PlusPunkte']) ?? record.pointsFor,
      pointsAgainst: _asNum(row['MinusPunkte']) ?? record.pointsAgainst,
      tablePointsFor: _asInt(row['WertungPlus']) ?? record.tablePointsFor,
      tablePointsAgainst:
          _asInt(row['WertungMinus']) ?? record.tablePointsAgainst,
    );
  }

  void close() {
    if (_ownsService) _ligaDbService.close();
  }

  static int? _asInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');
  static num? _asNum(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '');
  static String _text(dynamic value) => value?.toString().trim() ?? '';
}

class _Record {
  int matches = 0, wins = 0, losses = 0, draws = 0;
  num pointsFor = 0, pointsAgainst = 0;
  int tablePointsFor = 0, tablePointsAgainst = 0;

  void add(num ownScore, num opponentScore) {
    matches++;
    pointsFor += ownScore;
    pointsAgainst += opponentScore;
    if (ownScore > opponentScore) {
      wins++;
      tablePointsFor += 2;
    } else if (ownScore < opponentScore) {
      losses++;
      tablePointsAgainst += 2;
    } else {
      draws++;
      tablePointsFor++;
      tablePointsAgainst++;
    }
  }
}
