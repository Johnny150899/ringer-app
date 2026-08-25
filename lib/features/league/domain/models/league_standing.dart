class LeagueStanding {
  const LeagueStanding({
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.tablePointsFor,
    required this.tablePointsAgainst,
  });

  final int position;
  final int teamId;
  final String teamName;
  final int matches;
  final int wins;
  final int losses;
  final int draws;
  final num pointsFor;
  final num pointsAgainst;
  final int tablePointsFor;
  final int tablePointsAgainst;

  factory LeagueStanding.fromJson(Map<String, dynamic> json) => LeagueStanding(
    position: json['position'] as int,
    teamId: json['teamId'] as int,
    teamName: json['teamName'] as String,
    matches: json['matches'] as int,
    wins: json['wins'] as int,
    losses: json['losses'] as int,
    draws: json['draws'] as int,
    pointsFor: json['pointsFor'] as num,
    pointsAgainst: json['pointsAgainst'] as num,
    tablePointsFor: json['tablePointsFor'] as int,
    tablePointsAgainst: json['tablePointsAgainst'] as int,
  );

  Map<String, dynamic> toJson() => {
    'position': position,
    'teamId': teamId,
    'teamName': teamName,
    'matches': matches,
    'wins': wins,
    'losses': losses,
    'draws': draws,
    'pointsFor': pointsFor,
    'pointsAgainst': pointsAgainst,
    'tablePointsFor': tablePointsFor,
    'tablePointsAgainst': tablePointsAgainst,
  };

  bool get hasStarted => matches > 0;

  String get recordLabel => '$wins S · $draws U · $losses N';
  String get scoreLabel => '${_number(pointsFor)}:${_number(pointsAgainst)}';
  String get tablePointsLabel => '$tablePointsFor:$tablePointsAgainst';

  static String _number(num value) => value % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(1).replaceAll('.', ',');
}
