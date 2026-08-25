import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/app_glass_surface.dart';
import '../../../matches/domain/models/team_match.dart';
import '../../../matches/presentation/screens/match_detail_screen.dart';
import '../../data/services/league_service.dart';
import '../../domain/models/league_page_data.dart';
import '../../domain/models/league_standing.dart';
import '../../domain/models/league_team_config.dart';
import '../widgets/league_navigation.dart';

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key, this.nowOverride, this.service});

  final DateTime? nowOverride;
  final LeagueService? service;

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  late final LeagueService _service;
  late Future<LeaguePageData> _page;
  int? _selectedSeason;
  int? _currentSeason;
  int _selectedTeamIndex = 1;
  int _requestGeneration = 0;
  LeaguePageData? _lastPage;
  bool _isUpdating = false;
  _ResultScope _resultScope = _ResultScope.league;
  DateTime get _now => widget.nowOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LeagueService();
    _page = _loadInitial();
  }

  Future<LeaguePageData> _loadFresh() async {
    return _service.loadPage(
      season: _selectedSeason,
      teamIndex: _selectedTeamIndex,
    );
  }

  Future<LeaguePageData> _loadInitial() async {
    final cached = await _service.readCachedPage(
      season: _selectedSeason,
      teamIndex: _selectedTeamIndex,
    );
    if (cached != null) {
      _lastPage = cached;
      _currentSeason = cached.seasons.first;
      unawaited(Future<void>.microtask(_refresh));
      return cached;
    }
    final fresh = await _loadFresh();
    _lastPage = fresh;
    _currentSeason = fresh.seasons.first;
    return fresh;
  }

  Future<void> _refresh() async {
    final generation = ++_requestGeneration;
    if (mounted) setState(() => _isUpdating = true);
    try {
      final page = await _loadFresh();
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _lastPage = page;
        _currentSeason = page.seasons.first;
        _page = Future<LeaguePageData>.value(page);
        _isUpdating = false;
      });
    } on Object {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isUpdating = false);
      }
      if (_lastPage == null) rethrow;
    }
  }

  void _retry() => _replaceLoad();

  void _selectTeam(int index) {
    final teamIndex = index + 1;
    if (teamIndex == _selectedTeamIndex) return;
    _selectedTeamIndex = teamIndex;
    _replaceLoad();
  }

  void _selectSeason(int season) {
    if (season == _selectedSeason) return;
    _selectedSeason = season;
    _resultScope = season == _currentSeason
        ? _ResultScope.league
        : _ResultScope.ksc;
    _replaceLoad();
  }

  void _replaceLoad() {
    final generation = ++_requestGeneration;
    setState(() => _isUpdating = true);
    unawaited(_loadSelection(generation));
  }

  Future<void> _loadSelection(int generation) async {
    final cached = await _service.readCachedPage(
      season: _selectedSeason,
      teamIndex: _selectedTeamIndex,
    );
    if (cached != null && mounted && generation == _requestGeneration) {
      _lastPage = cached;
      _currentSeason = cached.seasons.first;
      setState(() {
        _page = Future<LeaguePageData>.value(cached);
      });
    }
    try {
      final fresh = await _loadFresh();
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _lastPage = fresh;
        _currentSeason = fresh.seasons.first;
        _page = Future<LeaguePageData>.value(fresh);
        _isUpdating = false;
      });
    } on Object {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _isUpdating = false);
      if (cached == null && _lastPage == null) {
        setState(() {
          _page = Future<LeaguePageData>.error(StateError(''));
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.service == null) _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LeaguePageData>(
      future: _page,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _lastPage == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _LeagueError(onRetry: _retry);
        }
        final data = snapshot.data ?? _lastPage!;
        final overview = data.overview;
        final config = data.config;
        final selectedSeason = config.season;
        final isCurrentSeason = selectedSeason == data.seasons.first;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 94),
            children: [
              if (_isUpdating) ...[
                const LinearProgressIndicator(
                  color: AppColors.red,
                  backgroundColor: Colors.white24,
                  minHeight: 2,
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Liga',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Tabellen, Ergebnisse und alle Begegnungen.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 15),
              LeagueTeamSwitcher(
                selectedIndex: config.teamIndex - 1,
                onSelected: _selectTeam,
              ),
              const SizedBox(height: 9),
              LeagueSeasonSwitcher(
                seasons: data.seasons,
                selectedSeason: selectedSeason,
                onSelected: _selectSeason,
              ),
              if (data.isCached) ...[
                const SizedBox(height: 10),
                const _CachedDataNotice(),
              ],
              const SizedBox(height: 14),
              _LeagueSummary(
                config: config,
                season: selectedSeason,
                isCurrentSeason: isCurrentSeason,
                standing: overview.ownStanding,
                lastMatch: _lastOwnMatch(overview.matches, config.teamId),
                nextMatch: _nextOwnMatch(overview.matches, config.teamId),
                onMatchTap: _openMatch,
              ),
              const SizedBox(height: 18),
              const _LeagueSectionTitle('Tabelle'),
              const SizedBox(height: 9),
              _StandingsCard(
                standings: overview.standings,
                ownTeamId: config.teamId,
              ),
              const SizedBox(height: 7),
              const _TableLegend(),
              const SizedBox(height: 18),
              _LeagueSectionTitle(
                isCurrentSeason
                    ? 'Letzte Liga-Ergebnisse'
                    : 'Kämpfe $selectedSeason',
              ),
              const SizedBox(height: 8),
              _ResultScopeSwitcher(
                scope: _resultScope,
                onChanged: (scope) => setState(() => _resultScope = scope),
              ),
              const SizedBox(height: 9),
              _LeagueResults(
                matches: _resultScope == _ResultScope.league
                    ? _completedLeagueMatches(overview.matches)
                    : _completedOwnMatches(overview.matches, config.teamId),
                onTap: _openMatch,
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMatch(TeamMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchDetailScreen(match: match.toJson()),
      ),
    );
  }

  bool _isOwnMatch(TeamMatch match, int teamId) =>
      _asInt(match['MannschaftenIDHeim']) == teamId ||
      _asInt(match['MannschaftenIDGast']) == teamId;

  TeamMatch? _nextOwnMatch(List<TeamMatch> matches, int teamId) {
    final upcoming = matches.where((match) {
      final date = _date(match);
      return _isOwnMatch(match, teamId) &&
          date != null &&
          !date.isBefore(DateTime(_now.year, _now.month, _now.day)) &&
          !_hasResult(match);
    }).toList()..sort((a, b) => _date(a)!.compareTo(_date(b)!));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  TeamMatch? _lastOwnMatch(List<TeamMatch> matches, int teamId) {
    final completed =
        matches
            .where((match) => _isOwnMatch(match, teamId) && _hasResult(match))
            .toList()
          ..sort((a, b) => _date(b)!.compareTo(_date(a)!));
    return completed.isEmpty ? null : completed.first;
  }

  List<TeamMatch> _completedLeagueMatches(List<TeamMatch> matches) {
    final completed = matches.where(_hasResult).toList()
      ..sort((a, b) => _date(b)!.compareTo(_date(a)!));
    return completed.take(8).toList(growable: false);
  }

  List<TeamMatch> _completedOwnMatches(List<TeamMatch> matches, int teamId) {
    final completed =
        matches
            .where((match) => _isOwnMatch(match, teamId) && _hasResult(match))
            .toList()
          ..sort((a, b) => _date(b)!.compareTo(_date(a)!));
    return completed;
  }

  static bool _hasResult(TeamMatch match) =>
      match['PunkteHeimWertung'] != null && match['PunkteGastWertung'] != null;
  static DateTime? _date(TeamMatch match) =>
      DateTime.tryParse(match['KampftagIst']?.toString() ?? '');
  static int? _asInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');
}

enum _ResultScope { ksc, league }

class _LeagueSummary extends StatelessWidget {
  const _LeagueSummary({
    required this.config,
    required this.season,
    required this.isCurrentSeason,
    required this.standing,
    required this.lastMatch,
    required this.nextMatch,
    required this.onMatchTap,
  });

  final LeagueTeamConfig config;
  final int season;
  final bool isCurrentSeason;
  final LeagueStanding? standing;
  final TeamMatch? lastMatch;
  final TeamMatch? nextMatch;
  final ValueChanged<TeamMatch> onMatchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.label,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Saison $season · ${_seasonStatus()}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _PositionBadge(
                standing: standing,
                isCurrentSeason: isCurrentSeason,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryValue(
                value: standing?.matches.toString() ?? '0',
                label: 'Kämpfe',
              ),
              _SummaryValue(
                value: standing == null
                    ? '0 · 0 · 0'
                    : '${standing!.wins} · ${standing!.draws} · ${standing!.losses}',
                label: 'S · U · N',
              ),
              _SummaryValue(
                value: standing?.tablePointsLabel ?? '0:0',
                label: 'Punkte',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (lastMatch == null && nextMatch == null)
            Text(
              isCurrentSeason
                  ? 'Die Saison hat noch nicht begonnen.'
                  : 'Für diese Saison sind keine Kämpfe hinterlegt.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            if (lastMatch != null)
              _CompactMatch(
                title: 'Letzter Kampf',
                match: lastMatch!,
                onTap: () => onMatchTap(lastMatch!),
              ),
            if (lastMatch != null && nextMatch != null)
              const Divider(height: 18),
            if (nextMatch != null)
              _CompactMatch(
                title: 'Nächster Kampf',
                match: nextMatch!,
                onTap: () => onMatchTap(nextMatch!),
              ),
          ],
        ],
      ),
    );
  }

  String _seasonStatus() {
    if (!isCurrentSeason) return 'Abgeschlossen';
    if (standing?.hasStarted == true) return 'Laufend';
    return 'Vorsaison';
  }
}

class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.standing, required this.isCurrentSeason});
  final LeagueStanding? standing;
  final bool isCurrentSeason;

  @override
  Widget build(BuildContext context) {
    final started = standing?.hasStarted == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: started ? AppColors.red : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        started
            ? '${standing!.position}. Platz'
            : isCurrentSeason
            ? 'Vorsaison'
            : 'Keine Daten',
        style: TextStyle(
          color: started ? Colors.white : AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({required this.standings, required this.ownTeamId});
  final List<LeagueStanding> standings;
  final int ownTeamId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _TableHeader(),
          ...standings.map(
            (standing) => _StandingRow(
              standing: standing,
              highlighted: standing.teamId == ownTeamId,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('#', style: _headerStyle)),
          Expanded(child: Text('Mannschaft', style: _headerStyle)),
          SizedBox(width: 28, child: Text('K', style: _headerStyle)),
          SizedBox(width: 42, child: Text('S:N', style: _headerStyle)),
          SizedBox(width: 38, child: Text('Pkt.', style: _headerStyle)),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    color: AppColors.muted,
    fontSize: 10,
    fontWeight: FontWeight.w800,
  );
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.standing, required this.highlighted});
  final LeagueStanding standing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.red.withValues(alpha: .08)
            : Colors.transparent,
        border: const Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${standing.position}.',
              style: TextStyle(
                color: highlighted ? AppColors.red : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              standing.teamName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: highlighted ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text('${standing.matches}', style: _cellStyle),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${standing.wins}:${standing.losses}',
              style: _cellStyle,
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(standing.tablePointsLabel, style: _cellStyle),
          ),
        ],
      ),
    );
  }

  static const _cellStyle = TextStyle(
    color: AppColors.navy,
    fontSize: 11,
    fontWeight: FontWeight.w800,
  );
}

class _LeagueResults extends StatelessWidget {
  const _LeagueResults({required this.matches, required this.onTap});
  final List<TeamMatch> matches;
  final ValueChanged<TeamMatch> onTap;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const AppGlassSurface(
        padding: EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Noch keine Liga-Ergebnisse verfügbar.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: matches
          .map(
            (match) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ResultCard(match: match, onTap: () => onTap(match)),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.match, required this.onTap});
  final TeamMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Expanded(child: _TeamNames(match: match)),
              const SizedBox(width: 8),
              Text(
                '${_score(match['PunkteHeimWertung'])}:${_score(match['PunkteGastWertung'])}',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMatch extends StatelessWidget {
  const _CompactMatch({
    required this.title,
    required this.match,
    required this.onTap,
  });
  final String title;
  final TeamMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasResult = match['PunkteHeimWertung'] != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _TeamNames(match: match),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              hasResult
                  ? '${_score(match['PunkteHeimWertung'])}:${_score(match['PunkteGastWertung'])}'
                  : _dateLabel(match),
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _TeamNames extends StatelessWidget {
  const _TeamNames({required this.match});
  final TeamMatch match;
  @override
  Widget build(BuildContext context) {
    return Text(
      '${match.homeTeam} – ${match.guestTeam}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _LeagueSectionTitle extends StatelessWidget {
  const _LeagueSectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CachedDataNotice extends StatelessWidget {
  const _CachedDataNotice();

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    borderRadius: 14,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Offline-Daten – letzter erfolgreicher Stand',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TableLegend extends StatelessWidget {
  const _TableLegend();

  @override
  Widget build(BuildContext context) => const Text(
    'K = Kämpfe · S/U/N = Siege/Unentschieden/Niederlagen · Pkt. = Tabellenpunkte',
    style: TextStyle(color: Colors.white70, fontSize: 10.5),
  );
}

class _ResultScopeSwitcher extends StatelessWidget {
  const _ResultScopeSwitcher({required this.scope, required this.onChanged});

  final _ResultScope scope;
  final ValueChanged<_ResultScope> onChanged;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    borderRadius: 14,
    padding: const EdgeInsets.all(3),
    child: Row(
      children: _ResultScope.values
          .map((value) {
            final selected = value == scope;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    value == _ResultScope.ksc
                        ? 'KSC-Kämpfe'
                        : 'Alle Ergebnisse',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? AppColors.navy : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    ),
  );
}

class _LeagueError extends StatelessWidget {
  const _LeagueError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Die Ligadaten konnten nicht geladen werden.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}

String _score(dynamic value) {
  if (value is num) {
    return value % 1 == 0 ? '${value.toInt()}' : '$value';
  }
  return value?.toString() ?? '–';
}

String _dateLabel(TeamMatch match) {
  final date = DateTime.tryParse(match['KampftagIst']?.toString() ?? '');
  if (date == null) return 'Termin offen';
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
}
