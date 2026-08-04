import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/club_logos.dart';
import '../services/ligadb_service.dart';
import 'match_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.matchesOverride, this.nowOverride});

  final List<dynamic>? matchesOverride;
  final DateTime? nowOverride;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Map<String, dynamic> _resultTestMatch = {
    'BegegnungsID': 78926,
    'KampftagIst': '2025-09-13T00:00:00',
    'Beginn': '20:00',
    'HeimMannschaft': 'ASV Bruchsal',
    'GastMannschaft': 'KSC Olympia Graben-Neudorf',
    'HeimOrganisationsID': 163,
    'GastOrganisationsID': 165,
    'PunkteHeimWertung': 12,
    'PunkteGastWertung': 19,
  };

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
  bool _showPastMatchPreview = false;

  @override
  void initState() {
    super.initState();
    _service = LigaDbService();
    _teamMatches = widget.matchesOverride == null
        ? [_service.getFirstTeamMatches(), null]
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

  ButtonStyle _debugButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white38),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    );
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MatchDetailScreen(match: Map<String, dynamic>.from(match as Map)),
      ),
    );
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
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 5,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openMatchDetails(context, _resultTestMatch),
                    style: _debugButtonStyle(),
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text(
                      'Einzelkämpfe',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(
                      () => _showPastMatchPreview = !_showPastMatchPreview,
                    ),
                    style: _debugButtonStyle(),
                    icon: Icon(
                      _showPastMatchPreview
                          ? Icons.visibility_off_outlined
                          : Icons.history_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _showPastMatchPreview
                          ? 'Ergebnis ausblenden'
                          : 'Letztes Ergebnis testen',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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
                return const _StatusView(
                  icon: Icons.cloud_off_rounded,
                  message: 'Die Kämpfe konnten nicht geladen werden.',
                );
              }

              final matches = <dynamic>[
                ...?snapshot.data,
                if (_showPastMatchPreview &&
                    !(snapshot.data ?? []).any(
                      (match) => match['BegegnungsID'] == 78926,
                    ))
                  _resultTestMatch,
              ];
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
                  const Text(
                    'Alle Termine des KSC Olympia auf einen Blick.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (nextMatch != null) ...[
                    const SizedBox(height: 18),
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

class _TeamSwitcher extends StatelessWidget {
  const _TeamSwitcher({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x3300142B),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _TeamSwitchItem(
            label: '1. Mannschaft',
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          _TeamSwitchItem(
            label: '2. Mannschaft',
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
        ],
      ),
    );
  }
}

class _TeamSwitchItem extends StatelessWidget {
  const _TeamSwitchItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x2600142B),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? const Color(0xFF061E39) : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedMatchCard extends StatelessWidget {
  const _FeaturedMatchCard({
    required this.homeName,
    required this.guestName,
    required this.homeLogo,
    required this.guestLogo,
    required this.date,
    required this.time,
    required this.onTap,
  });

  final String homeName;
  final String guestName;
  final String homeLogo;
  final String guestLogo;
  final String date;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFC),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3300142B),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              _TeamsRow(
                homeName: homeName,
                guestName: guestName,
                homeLogo: homeLogo,
                guestLogo: guestLogo,
                featured: true,
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFE4E7EC)),
              const SizedBox(height: 14),
              _ScheduleRow(date: date, time: time),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.homeName,
    required this.guestName,
    required this.homeLogo,
    required this.guestLogo,
    required this.date,
    required this.time,
    required this.onTap,
    this.result,
  });

  final String homeName;
  final String guestName;
  final String homeLogo;
  final String guestLogo;
  final String date;
  final String time;
  final VoidCallback onTap;
  final String? result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white),
            ),
            child: Column(
              children: [
                _TeamsRow(
                  homeName: homeName,
                  guestName: guestName,
                  homeLogo: homeLogo,
                  guestLogo: guestLogo,
                  result: result,
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE4E7EC)),
                const SizedBox(height: 10),
                _ScheduleRow(date: date, time: time, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamsRow extends StatelessWidget {
  const _TeamsRow({
    required this.homeName,
    required this.guestName,
    required this.homeLogo,
    required this.guestLogo,
    this.featured = false,
    this.result,
  });

  final String homeName;
  final String guestName;
  final String homeLogo;
  final String guestLogo;
  final bool featured;
  final String? result;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _Team(
            name: homeName,
            logo: homeLogo,
            logoSize: featured ? 58 : 46,
            fontSize: featured ? 14 : 12,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            width: result == null ? (featured ? 42 : 36) : 58,
            height: featured ? 42 : 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF061E39),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              result ?? 'VS',
              style: TextStyle(
                color: Colors.white,
                fontSize: featured ? 12 : 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Expanded(
          child: _Team(
            name: guestName,
            logo: guestLogo,
            logoSize: featured ? 58 : 46,
            fontSize: featured ? 14 : 12,
          ),
        ),
      ],
    );
  }
}

class _Team extends StatelessWidget {
  const _Team({
    required this.name,
    required this.logo,
    required this.logoSize,
    required this.fontSize,
  });

  final String name;
  final String logo;
  final double logoSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Image.asset(
            logo,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.shield_outlined, color: Color(0xFF667085)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF101828),
            fontSize: fontSize,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.date,
    required this.time,
    this.compact = false,
  });

  final String date;
  final String time;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScheduleItem(
            icon: Icons.calendar_today_rounded,
            value: date,
            compact: compact,
          ),
        ),
        Container(width: 1, height: 24, color: const Color(0xFFE4E7EC)),
        Expanded(
          child: _ScheduleItem(
            icon: Icons.schedule_rounded,
            value: time,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  const _ScheduleItem({
    required this.icon,
    required this.value,
    required this.compact,
  });

  final IconData icon;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: compact ? 15 : 18, color: const Color(0xFFE4003A)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF667085),
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoUpcomingMatches extends StatelessWidget {
  const _NoUpcomingMatches();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_available_rounded, color: Colors.white),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aktuell ist kein weiterer Kampf geplant.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.message,
    this.loading = false,
  });

  final IconData icon;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator(color: Colors.white)
            else
              Icon(icon, color: Colors.white, size: 38),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
