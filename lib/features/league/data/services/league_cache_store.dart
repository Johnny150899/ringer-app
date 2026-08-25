import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/league_overview.dart';
import '../../domain/models/league_team_config.dart';

abstract interface class LeagueCacheStore {
  Future<void> saveOverview(LeagueTeamConfig config, LeagueOverview overview);
  Future<LeagueOverview?> readOverview(LeagueTeamConfig config);
  Future<void> saveConfigs(int season, List<LeagueTeamConfig> configs);
  Future<List<LeagueTeamConfig>?> readConfigs(int season);
}

class SharedPreferencesLeagueCacheStore implements LeagueCacheStore {
  SharedPreferencesLeagueCacheStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<void> saveOverview(LeagueTeamConfig config, LeagueOverview overview) =>
      _preferences.setString(
        _overviewKey(config),
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'data': overview,
        }),
      );

  @override
  Future<LeagueOverview?> readOverview(LeagueTeamConfig config) async {
    final raw = await _preferences.getString(_overviewKey(config));
    if (raw == null) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return LeagueOverview.fromJson(
        Map<String, dynamic>.from(json['data'] as Map),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveConfigs(int season, List<LeagueTeamConfig> configs) =>
      _preferences.setString(
        'league.configs.$season',
        jsonEncode(configs.map((config) => config.toJson()).toList()),
      );

  @override
  Future<List<LeagueTeamConfig>?> readConfigs(int season) async {
    final raw = await _preferences.getString('league.configs.$season');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) => LeagueTeamConfig.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on Object {
      return null;
    }
  }

  String _overviewKey(LeagueTeamConfig config) =>
      'league.overview.${config.season}.${config.teamIndex}';
}
