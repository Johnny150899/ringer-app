import '../../../matches/domain/models/team_match.dart';
import 'league_standing.dart';

class LeagueOverview {
  const LeagueOverview({
    required this.standings,
    required this.matches,
    required this.teamId,
  });

  final List<LeagueStanding> standings;
  final List<TeamMatch> matches;
  final int teamId;

  factory LeagueOverview.fromJson(Map<String, dynamic> json) => LeagueOverview(
    standings: (json['standings'] as List<dynamic>)
        .map(
          (item) =>
              LeagueStanding.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
    matches: (json['matches'] as List<dynamic>)
        .map(
          (item) => TeamMatch.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
    teamId: json['teamId'] as int,
  );

  Map<String, dynamic> toJson() => {
    'standings': standings.map((item) => item.toJson()).toList(growable: false),
    'matches': matches.map((item) => item.toJson()).toList(growable: false),
    'teamId': teamId,
  };

  LeagueStanding? get ownStanding {
    for (final standing in standings) {
      if (standing.teamId == teamId) return standing;
    }
    return null;
  }
}
