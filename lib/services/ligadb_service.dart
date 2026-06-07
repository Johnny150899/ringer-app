import 'dart:convert';
import 'package:http/http.dart' as http;

class LigaDbService {
  static const String baseUrl = 'https://ringen.liga-db.de/api';
  static const String clubSearchName = 'KSC Olympia';

  Future<List<dynamic>> getMatchesForTeam({
    required int saisonLigaId,
    required int mannschaftenId,
  }) async {
    final url = Uri.parse(
      '$baseUrl/TeamMatches?saisonLigaID=$saisonLigaId&mannschaftenID=$mannschaftenId',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Fehler beim Laden der Kämpfe');
    }
  }

  Future<List<dynamic>> getAllKscMatches() async {
    final firstTeamMatches = await getMatchesForTeam(
      saisonLigaId: 1227,
      mannschaftenId: 13215,
    );

    final secondTeamMatches = await getMatchesForTeam(
      saisonLigaId: 1225,
      mannschaftenId: 13518,
    );

    return [
      ...firstTeamMatches,
      ...secondTeamMatches,
    ];
  }
}