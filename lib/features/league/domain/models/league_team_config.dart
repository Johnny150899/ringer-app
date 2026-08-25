class LeagueTeamConfig {
  const LeagueTeamConfig({
    required this.season,
    required this.teamIndex,
    required this.leagueId,
    required this.teamId,
    required this.label,
  });

  final int season;
  final int teamIndex;
  final int leagueId;
  final int teamId;
  final String label;

  Map<String, dynamic> toJson() => {
    'season': season,
    'teamIndex': teamIndex,
    'leagueId': leagueId,
    'teamId': teamId,
    'label': label,
  };

  factory LeagueTeamConfig.fromJson(Map<String, dynamic> json) =>
      LeagueTeamConfig(
        season: json['season'] as int,
        teamIndex: json['teamIndex'] as int,
        leagueId: json['leagueId'] as int,
        teamId: json['teamId'] as int,
        label: json['label'] as String,
      );
}
