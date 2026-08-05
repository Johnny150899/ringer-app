class TeamMatch {
  TeamMatch.fromJson(Map<String, dynamic> json)
    : _json = Map.unmodifiable(json);

  final Map<String, dynamic> _json;

  dynamic operator [](String key) => _json[key];

  int get id => _asInt(_json['BegegnungsID']) ?? 0;
  String get homeTeam => _text(_json['HeimMannschaft']);
  String get guestTeam => _text(_json['GastMannschaft']);
  int? get homeOrganisationId => _asInt(_json['HeimOrganisationsID']);
  int? get guestOrganisationId => _asInt(_json['GastOrganisationsID']);

  Map<String, dynamic> toJson() => Map.of(_json);

  static int? _asInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  static String _text(dynamic value) => value?.toString().trim() ?? '';
}
