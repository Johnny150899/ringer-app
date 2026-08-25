import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/config/network_policy.dart';
import '../../domain/models/single_match.dart';
import '../../domain/models/team_match.dart';

class LigaDbService {
  LigaDbService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const String baseUrl = 'https://ringen.liga-db.de/api';
  static const String clubSearchName = 'KSC Olympia';
  static const Duration requestTimeout = NetworkPolicy.requestTimeout;

  final http.Client _client;
  final bool _ownsClient;

  Future<int> getCurrentSeason() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/CurrentSeasons'))
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Aktuelle Saison konnte nicht geladen werden');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is int) return decoded;
    if (decoded is String) return int.parse(decoded);
    if (decoded is Map) {
      for (final key in const ['Saison', 'Season', 'year', 'Year']) {
        final parsed = int.tryParse(decoded[key]?.toString() ?? '');
        if (parsed != null) return parsed;
      }
    }
    throw const FormatException('Unbekanntes Saisonformat');
  }

  Future<List<int>> getAllSeasons() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/AllSeasons?region=0'))
        .timeout(requestTimeout);
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final seasons = <int>{};
    for (final item in decoded) {
      final direct = int.tryParse(item.toString());
      if (direct != null) {
        seasons.add(direct);
        continue;
      }
      if (item is Map) {
        for (final key in const ['Saison', 'Season', 'year', 'Year']) {
          final parsed = int.tryParse(item[key]?.toString() ?? '');
          if (parsed != null) seasons.add(parsed);
        }
      }
    }
    return seasons.toList()..sort((a, b) => b.compareTo(a));
  }

  Future<List<Map<String, dynamic>>> getLeagues(int season) async {
    final response = await _client
        .get(Uri.parse('$baseUrl/Ligen?saison=$season'))
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Ligen konnten nicht geladen werden');
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<List<TeamMatch>> getMatchesForTeam({
    required int saisonLigaId,
    required int mannschaftenId,
  }) async {
    final url = Uri.parse(
      '$baseUrl/TeamMatches?saisonLigaID=$saisonLigaId&mannschaftenID=$mannschaftenId',
    );

    final response = await _client.get(url).timeout(requestTimeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((item) => TeamMatch.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } else {
      throw Exception('Fehler beim Laden der Kämpfe');
    }
  }

  Future<List<TeamMatch>> getLeagueMatches(int saisonLigaId) async {
    final url = Uri.parse('$baseUrl/TeamMatches?saisonLigaID=$saisonLigaId');
    final response = await _client.get(url).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Fehler beim Laden der Ligakämpfe');
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => TeamMatch.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getLeagueTable(int saisonLigaId) async {
    final url = Uri.parse(
      '$baseUrl/ErgebnisTabelle?saisonLigaId=$saisonLigaId',
    );
    final response = await _client.get(url).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Fehler beim Laden der Ligatabelle');
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getLeagueTeams(int saisonLigaId) async {
    final url = Uri.parse('$baseUrl/Teams?saisonLigaId=$saisonLigaId');
    final response = await _client.get(url).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Fehler beim Laden der Ligamannschaften');
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<List<TeamMatch>> getAllKscMatches() async {
    final results = await Future.wait([
      getFirstTeamMatches(),
      getSecondTeamMatches(),
    ]);

    return [...results[0], ...results[1]];
  }

  Future<List<TeamMatch>> getFirstTeamMatches() {
    return getMatchesForTeam(saisonLigaId: 1227, mannschaftenId: 13215);
  }

  Future<List<TeamMatch>> getSecondTeamMatches() {
    return getMatchesForTeam(saisonLigaId: 1225, mannschaftenId: 13518);
  }

  Future<List<SingleMatch>> getSingleMatches(int begegnungsId) async {
    final url = Uri.parse('$baseUrl/SingleMatches?begegnungsID=$begegnungsId');
    final response = await _client.get(url).timeout(requestTimeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((item) => SingleMatch.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }
    throw Exception('Fehler beim Laden der Einzelkämpfe');
  }

  Future<Map<String, dynamic>?> getOrganisation(int organisationId) async {
    final url = Uri.parse('$baseUrl/Organisations?orgID=$organisationId');
    final response = await _client.get(url).timeout(requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Fehler beim Laden des Austragungsorts');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List && decoded.isNotEmpty) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getVenueForMatch(
    Map<String, dynamic> match,
  ) async {
    final venue = _venueFromMatch(match);
    if (venue != null) return venue;

    final organisationId = _asInt(match['HeimOrganisationsID']);
    if (organisationId == null) return null;

    final organisation = await getOrganisation(organisationId);
    if (organisation == null) return null;

    return {
      'name': organisation['OrgName'],
      'address': organisation['Ort'],
      'isExactAddress': false,
    };
  }

  Map<String, dynamic>? _venueFromMatch(Map<String, dynamic> match) {
    final nestedVenue =
        match['Wettkampfstaette'] ??
        match['Wettkampfstätte'] ??
        match['wettkampfstaette'];

    if (nestedVenue is Map) {
      final venue = Map<String, dynamic>.from(nestedVenue);
      final address = _firstText(venue, const [
        'KompletteAnschrift',
        'kompletteAnschrift',
        'Anschrift',
        'Adresse',
        'address',
      ]);
      if (address != null) {
        return {
          'name': _firstText(venue, const [
            'Bezeichnung',
            'Name',
            'Hallenname',
            'name',
          ]),
          'address': address,
          'isExactAddress': true,
        };
      }
    }

    final address = _firstText(match, const [
      'KompletteAnschrift',
      'WettkampfstaetteKompletteAnschrift',
      'WettkampfstaetteAnschrift',
      'AustragungsortAnschrift',
      'Adresse',
    ]);
    if (address == null) return null;

    return {
      'name': _firstText(match, const [
        'WettkampfstaetteName',
        'WettkampfstaetteBezeichnung',
        'Austragungsort',
      ]),
      'address': address,
      'isExactAddress': true,
    };
  }

  static int? _asInt(dynamic value) {
    return value is int ? value : int.tryParse(value?.toString() ?? '');
  }

  static String? _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return null;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
