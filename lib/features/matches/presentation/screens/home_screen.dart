import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/constants/club_logos.dart';
import '../../../../core/data/cached_loader.dart';
import '../../../../core/data/offline_cache.dart';
import '../../../../core/widgets/app_glass_surface.dart';
import '../../data/services/ligadb_service.dart';
import '../../domain/models/team_match.dart';
import 'match_detail_screen.dart';
import '../../../league/presentation/screens/league_screen.dart';

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
  final _cache = OfflineCache();
  final List<CachedLoader<List<dynamic>>?> _teamMatches = [null, null];
  int _selectedTeam = 0;

  @override
  void initState() {
    super.initState();
    _service = LigaDbService();
    _teamMatches[0] = _createLoader(0);
  }

  CachedLoader<List<dynamic>> _createLoader(int index) {
    var firstRequest = true;
    final loader = CachedLoader<List<dynamic>>(
      read: () async =>
          widget.matchesOverride ??
          await _cache.read('home.matches.2026.$index'),
      fetch: () {
        if (widget.matchesOverride != null) {
          return Future.value(widget.matchesOverride!);
        }
        if (index == 0 &&
            firstRequest &&
            widget.firstTeamMatchesFuture != null) {
          firstRequest = false;
          return widget.firstTeamMatchesFuture!;
        }
        return index == 0
            ? _service.getFirstTeamMatches()
            : _service.getSecondTeamMatches();
      },
      write: (rows) async {
        if (widget.matchesOverride == null) {
          await _cache.write(
            'home.matches.2026.$index',
            rows
                .map(
                  (row) => row is TeamMatch
                      ? row.toJson()
                      : Map<String, dynamic>.from(row as Map),
                )
                .toList(),
          );
        }
      },
    );
    unawaited(loader.start());
    return loader;
  }

  void _selectTeam(int index) {
    if (index == _selectedTeam) return;

    if (_teamMatches[index] == null) {
      _teamMatches[index] = _createLoader(index);
    }
    setState(() => _selectedTeam = index);
  }

  @override
  void dispose() {
    for (final loader in _teamMatches) {
      loader?.dispose();
    }
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
    unawaited(_teamMatches[_selectedTeam]!.refresh());
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
          child: AnimatedBuilder(
            animation: _teamMatches[_selectedTeam]!,
            builder: (context, _) {
              final state = _teamMatches[_selectedTeam]!;
              if (state.data == null && state.error == null) {
                return const _StatusView(
                  icon: Icons.sync_rounded,
                  message: 'Kämpfe werden geladen …',
                  loading: true,
                );
              }

              if (state.error != null && state.data == null) {
                return _StatusView(
                  icon: Icons.cloud_off_rounded,
                  message: 'Die Kämpfe konnten nicht geladen werden.',
                  onRetry: _retryMatches,
                );
              }

              final matches = <dynamic>[...?state.data];
              if (matches.isEmpty) {
                return _StatusView(
                  icon: Icons.event_busy_rounded,
                  message: state.error == null
                      ? 'Aktuell sind keine Kämpfe eingetragen.'
                      : 'Keine gespeicherten Kämpfe. Aktualisierung fehlgeschlagen.',
                  onRetry: state.updating ? null : _retryMatches,
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
              final seasonCompleted =
                  !state.cached &&
                  state.error == null &&
                  !state.updating &&
                  pastMatches.isNotEmpty &&
                  matches.every(
                    (match) =>
                        _isPast(match, now) &&
                        num.tryParse('${match['PunkteHeimWertung']}') != null &&
                        num.tryParse('${match['PunkteGastWertung']}') != null,
                  );

              return RefreshIndicator(
                onRefresh: state.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
                  children: [
                    if (state.updating)
                      const LinearProgressIndicator(minHeight: 2),
                    if (state.cached || state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextButton(
                          onPressed: state.updating ? null : _retryMatches,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white70,
                          ),
                          child: Text(
                            state.updating
                                ? 'Gespeicherter Stand · wird aktualisiert …'
                                : 'Gespeicherter Stand · Erneut versuchen',
                          ),
                        ),
                      ),
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
                      _NoUpcomingMatches(
                        season: 2026,
                        onOpenTable: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              backgroundColor: AppColors.navy,
                              appBar: AppBar(
                                title: const Text('Saisontabelle 2026'),
                              ),
                              body: LeagueScreen(
                                initialSeason: 2026,
                                initialTeamIndex: _selectedTeam + 1,
                              ),
                            ),
                          ),
                        ),
                        seasonCompleted: seasonCompleted,
                      ),
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
                      _SectionTitle(
                        title: seasonCompleted
                            ? 'Letztes Ergebnis'
                            : 'Letzte Ergebnisse',
                      ),
                      const SizedBox(height: 12),
                      ...pastMatches
                          .take(seasonCompleted ? 1 : 5)
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
