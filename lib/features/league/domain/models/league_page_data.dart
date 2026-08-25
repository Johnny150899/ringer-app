import 'league_overview.dart';
import 'league_team_config.dart';

class LeaguePageData {
  const LeaguePageData({
    required this.seasons,
    required this.config,
    required this.overview,
    this.isCached = false,
  });

  final List<int> seasons;
  final LeagueTeamConfig config;
  final LeagueOverview overview;
  final bool isCached;
}
