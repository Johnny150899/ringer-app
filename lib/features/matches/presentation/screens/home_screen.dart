import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/club_logos.dart';
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
    this.supabaseClient,
    this.canManageAnnouncements = false,
  });

  final List<dynamic>? matchesOverride;
  final DateTime? nowOverride;
  final SupabaseClient? supabaseClient;
  final bool canManageAnnouncements;

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
  Map<String, dynamic>? _announcement;

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
    _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    final client = widget.supabaseClient;
    if (client == null) return;
    try {
      final row = await client
          .from('club_announcements')
          .select('id, title, message, expires_at')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (mounted) setState(() => _announcement = row);
    } on PostgrestException {
      // Die Home-Seite bleibt bis zur Migration ohne Meldung nutzbar.
    }
  }

  Future<void> _manageAnnouncement() async {
    final titleController = TextEditingController(
      text: _announcement?['title'] as String? ?? '',
    );
    final messageController = TextEditingController(
      text: _announcement?['message'] as String? ?? '',
    );
    final currentExpiry = DateTime.tryParse(
      _announcement?['expires_at'] as String? ?? '',
    );
    final remainingDays = currentExpiry
        ?.difference(DateTime.now())
        .inHours
        .clamp(1, 24 * 30);
    int? durationDays = currentExpiry == null
        ? 14
        : remainingDays! <= 24
        ? 1
        : remainingDays <= 72
        ? 3
        : remainingDays <= 168
        ? 7
        : remainingDays <= 336
        ? 14
        : 30;
    final formKey = GlobalKey<FormState>();
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.campaign_rounded, color: Color(0xFFE90046)),
          title: Text(
            _announcement == null ? 'Vereinsmeldung' : 'Meldung bearbeiten',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Überschrift'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Bitte eine Überschrift eingeben.'
                      : null,
                ),
                TextFormField(
                  controller: messageController,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Mitteilung'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Bitte eine Mitteilung eingeben.'
                      : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: durationDays,
                  decoration: const InputDecoration(
                    labelText: 'Wie lange anzeigen?',
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 Tag')),
                    DropdownMenuItem(value: 3, child: Text('3 Tage')),
                    DropdownMenuItem(value: 7, child: Text('7 Tage')),
                    DropdownMenuItem(value: 14, child: Text('14 Tage')),
                    DropdownMenuItem(value: 30, child: Text('30 Tage')),
                    DropdownMenuItem(value: null, child: Text('Ohne Ablauf')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => durationDays = value),
                ),
              ],
            ),
          ),
          actions: [
            if (_announcement != null)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'delete'),
                child: const Text('Löschen'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, 'save');
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) {
      titleController.dispose();
      messageController.dispose();
      return;
    }
    try {
      final client = widget.supabaseClient!;
      if (action == 'delete') {
        await client
            .from('club_announcements')
            .delete()
            .eq('id', _announcement!['id']);
      } else {
        final values = {
          'title': titleController.text.trim(),
          'message': messageController.text.trim(),
          'expires_at': durationDays == null
              ? null
              : DateTime.now()
                    .add(Duration(days: durationDays!))
                    .toUtc()
                    .toIso8601String(),
        };
        if (_announcement == null) {
          await client.from('club_announcements').insert({
            ...values,
            'created_by': client.auth.currentUser!.id,
          });
        } else {
          await client
              .from('club_announcements')
              .update(values)
              .eq('id', _announcement!['id']);
        }
      }
      if (mounted) {
        setState(() => _announcement = null);
        await _loadAnnouncement();
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meldung nicht gespeichert: ${error.message}'),
          ),
        );
      }
    } finally {
      titleController.dispose();
      messageController.dispose();
    }
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
    final matchData = match is TeamMatch
        ? match.toJson()
        : Map<String, dynamic>.from(match as Map);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchDetailScreen(match: matchData),
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
        if (widget.canManageAnnouncements)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _manageAnnouncement,
                style: _debugButtonStyle(),
                icon: const Icon(Icons.campaign_rounded, size: 16),
                label: Text(
                  _announcement == null
                      ? 'Meldung erstellen'
                      : 'Meldung bearbeiten',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                  if (_announcement != null) ...[
                    _AnnouncementCard(announcement: _announcement!),
                    const SizedBox(height: 14),
                  ],
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
