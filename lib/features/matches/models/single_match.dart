class SingleMatch {
  SingleMatch.fromJson(Map<String, dynamic> json)
    : _json = Map.unmodifiable(json);

  final Map<String, dynamic> _json;

  dynamic operator [](String key) => _json[key];

  String get weightClass => _text(_json['Gewichtsklasse']);
  String get style => _text(_json['Stilart']);
  String get homeWrestler => _text(_json['NameHeim']);
  String get guestWrestler => _text(_json['NameGast']);
  String get result => _text(_json['Wertung']);

  static String _text(dynamic value) => value?.toString().trim() ?? '';
}
