import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/constants/club_logos.dart';
import '../../../../core/widgets/app_glass_surface.dart';
import '../../data/services/ligadb_service.dart';
import '../../domain/models/team_match.dart';
import 'match_detail_screen.dart';

part '../widgets/home_header_widgets.dart';
part '../widgets/home_match_cards.dart';
part '../widgets/home_schedule_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.matchesOverride,
    this.nowOverride,
    this.firstTeamMatchesFuture,
  });

  final List<dynamic>? matchesOverride;
  final DateTime? nowOverride;
  final Future<List<TeamMatch>>? firstTeamMatchesFuture;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final RegExp _multipleSpaces = RegExp(r'\s+');

  static const Map<String, String> _shortTeamNames = {
    'ksc olympia graben-neudorf': 'KSC Olympia',
    'ksc graben-neudorf ii': 'KSC Olympia II',
    'rkg reilingen-hockenheim ii': 'RKG Reilingen II',
    'svg nieder-liebersbach': 'SVG Nieder-L.',
    'svg 04 weingarten ii': 'SVG Weingarten II',
    'rg ladenburg-rohrbach': 'RG Ladenburg',
    'rg ladenburg -rohrbach iii': 'RG Ladenburg III',
    'rsc eiche sandhofen ii': 'RSC Sandhofen II',
    'falken bergstrasse': 'Falken Bergstraße',
    'falken bergstrasse ii': 'Falken Bergstraße II',
  };

  late final LigaDbService _service;
  late final List<Future<List<dynamic>>?> _teamMatches;
  int _selectedTeam = 0;

  @override
  void initState() {
    super.initState();
    _service = LigaDbService();
    _teamMatches = widget.matchesOverride == null
        ? [
            widget.firstTeamMatchesFuture ?? _service.getFirstTeamMatches(),
            null,
          ]
        : [
            Future.value(widget.matchesOverride),
            Future.value(widget.matchesOverride),
          ];
  }

  void _selectTeam(int index) {
    if (index == _selectedTeam) return;

    if (_teamMatches[index] == null) {
      _teamMatches[index] = _service.getSecondTeamMatches();
    }
    setState(() => _selectedTeam = index);
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  String _text(dynamic value, {String fallback = 'Noch offen'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  int? _int(dynamic value) {
    return value is int ? value : int.tryParse(value?.toString() ?? '');
  }

  String _homeName(dynamic match) {
    return _text(match['HeimMannschaft'], fallback: 'Heimteam');
  }

  String _guestName(dynamic match) {
    return _text(match['GastMannschaft'], fallback: 'Gastteam');
  }

  String _shortName(String name) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll('ß', 'ss')
        .replaceAll(_multipleSpaces, ' ');

    return _shortTeamNames[normalized] ?? name.trim();
  }

  String _date(dynamic match) {
    final raw = _text(
      match['KampftagIst'] ?? match['KampfTagIst'],
      fallback: 'Termin folgt',
    );
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day.$month.${parsed.year}';
  }

  String _time(dynamic match) {
    return _text(match['Beginn'], fallback: 'Uhrzeit folgt');
  }

  DateTime? _matchStart(dynamic match) {
    final rawDate = match['KampftagIst'] ?? match['KampfTagIst'];
    final date = DateTime.tryParse(rawDate?.toString() ?? '');
    if (date == null) return null;

    final timeParts = _text(match['Beginn'], fallback: '00:00').split(':');
    final hour = int.tryParse(timeParts.first) ?? 0;
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  bool _isPast(dynamic match, DateTime now) {
    final start = _matchStart(match);
    return start != null && start.add(const Duration(hours: 3)).isBefore(now);
  }

  String _score(dynamic value) {
    final number = value is num ? value : num.tryParse(value?.toString() ?? '');
    if (number == null) return '–';
    return number % 1 == 0 ? number.toInt().toString() : number.toString();
  }

  String _result(dynamic match) {
    return '${_score(match['PunkteHeimWertung'])} : '
        '${_score(match['PunkteGastWertung'])}';
  }

  String _homeLogo(dynamic match) {
    final name = _homeName(match);
    return ClubLogos.forClub(
      name,
      organisationId: _int(match['HeimOrganisationsID']),
    );
  }

  String _guestLogo(dynamic match) {
    final name = _guestName(match);
    return ClubLogos.forClub(
      name,
      organisationId: _int(match['GastOrganisationsID']),
    );
  }

  void _openMatchDetails(BuildContext context, dynamic match) {
    final matchData = match is TeamMatch
        ? match.toJson()
        : Map<String, dynamic>.from(match as Map);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchDetailScreen(match: matchData),
      ),
    );
  }

  void _retryMatches() {
    setState(() {
      _teamMatches[_selectedTeam] = _selectedTeam == 0
          ? _service.getFirstTeamMatches()
          : _service.getSecondTeamMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: _TeamSwitcher(
            selectedIndex: _selectedTeam,
            onSelected: _selectTeam,
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _teamMatches[_selectedTeam]!,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _StatusView(
                  icon: Icons.sync_rounded,
                  message: 'Kämpfe werden geladen …',
                  loading: true,
                );
              }

              if (snapshot.hasError) {
                return _StatusView(
                  icon: Icons.cloud_off_rounded,
                  message: 'Die Kämpfe konnten nicht geladen werden.',
                  onRetry: _retryMatches,
                );
              }

              final matches = <dynamic>[...?snapshot.data];
              if (matches.isEmpty) {
                return const _StatusView(
                  icon: Icons.event_busy_rounded,
                  message: 'Aktuell sind keine Kämpfe eingetragen.',
                );
              }

              final now = widget.nowOverride ?? DateTime.now();
              final upcomingMatches =
                  matches.where((match) => !_isPast(match, now)).toList()
                    ..sort((a, b) {
                      final aDate = _matchStart(a);
                      final bDate = _matchStart(b);
                      if (aDate == null) return 1;
                      if (bDate == null) return -1;
                      return aDate.compareTo(bDate);
                    });
              final pastMatches =
                  matches.where((match) => _isPast(match, now)).toList()
                    ..sort((a, b) {
                      final aDate = _matchStart(a);
                      final bDate = _matchStart(b);
                      if (aDate == null) return 1;
                      if (bDate == null) return -1;
                      return bDate.compareTo(aDate);
                    });
              final nextMatch = upcomingMatches.isEmpty
                  ? null
                  : upcomingMatches.first;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
                children: [
                  if (nextMatch != null) ...[
                    const _SectionTitle(title: 'Nächster Kampf'),
                    const SizedBox(height: 12),
                    _FeaturedMatchCard(
                      homeName: _shortName(_homeName(nextMatch)),
                      guestName: _shortName(_guestName(nextMatch)),
                      homeLogo: _homeLogo(nextMatch),
                      guestLogo: _guestLogo(nextMatch),
                      date: _date(nextMatch),
                      time: _time(nextMatch),
                      onTap: () => _openMatchDetails(context, nextMatch),
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
                    const _NoUpcomingMatches(),
                  ],
                  if (upcomingMatches.length > 1) ...[
                    const SizedBox(height: 28),
                    const _SectionTitle(title: 'Kommende Kämpfe'),
                    const SizedBox(height: 12),
                    ...upcomingMatches
                        .skip(1)
                        .take(5)
                        .map(
                          (match) => _MatchCard(
                            homeName: _shortName(_homeName(match)),
                            guestName: _shortName(_guestName(match)),
                            homeLogo: _homeLogo(match),
                            guestLogo: _guestLogo(match),
                            date: _date(match),
                            time: _time(match),
                            onTap: () => _openMatchDetails(context, match),
                          ),
                        ),
                  ],
                  if (pastMatches.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const _SectionTitle(title: 'Letzte Ergebnisse'),
                    const SizedBox(height: 12),
                    ...pastMatches
                        .take(5)
                        .map(
                          (match) => _MatchCard(
                            homeName: _shortName(_homeName(match)),
                            guestName: _shortName(_guestName(match)),
                            homeLogo: _homeLogo(match),
                            guestLogo: _guestLogo(match),
                            date: _date(match),
                            time: _time(match),
                            result: _result(match),
                            onTap: () => _openMatchDetails(context, match),
                          ),
                        ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
