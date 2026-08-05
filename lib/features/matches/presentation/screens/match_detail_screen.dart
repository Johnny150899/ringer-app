import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/club_logos.dart';
import '../../data/services/ligadb_service.dart';

part '../widgets/match_venue_widgets.dart';
part '../widgets/match_summary_widgets.dart';
part '../widgets/single_match_widgets.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.match,
    this.singleMatchesOverride,
    this.venueOverride,
  });

  final Map<String, dynamic> match;
  final List<dynamic>? singleMatchesOverride;
  final Map<String, dynamic>? venueOverride;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  late final LigaDbService _service;
  late final Future<List<dynamic>> _singleMatches;
  late final Future<Map<String, dynamic>?> _venue;

  @override
  void initState() {
    super.initState();
    _service = LigaDbService();
    _singleMatches = widget.singleMatchesOverride != null
        ? Future.value(widget.singleMatchesOverride)
        : _service.getSingleMatches(_asInt(widget.match['BegegnungsID']) ?? 0);
    _venue = widget.venueOverride != null
        ? Future.value(widget.venueOverride)
        : _service.getVenueForMatch(widget.match);
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  static int? _asInt(dynamic value) {
    return value is int ? value : int.tryParse(value?.toString() ?? '');
  }

  String _text(dynamic value, {String fallback = '–'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String _number(dynamic value) {
    if (value == null) return '–';
    final number = value is num ? value : num.tryParse(value.toString());
    if (number == null) return _text(value);
    return number % 1 == 0 ? number.toInt().toString() : number.toString();
  }

  String _date() {
    final raw = _text(
      widget.match['KampftagIst'] ?? widget.match['KampfTagIst'],
      fallback: 'Termin folgt',
    );
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day.$month.${parsed.year}';
  }

  String _duration(dynamic seconds) {
    final total = _asInt(seconds);
    if (total == null || total <= 0) return '–';
    final minutes = total ~/ 60;
    final rest = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$rest min';
  }

  String _style(dynamic value) {
    return switch (_text(value).toUpperCase()) {
      'G' => 'Gr.-röm.',
      'L' => 'Freistil',
      final style => style,
    };
  }

  Future<void> _openGoogleMaps(Map<String, dynamic> venue) async {
    final venueName = _text(venue['name'], fallback: '');
    final address = _text(venue['address'], fallback: '');
    final query = [
      venueName,
      address,
    ].where((part) => part.isNotEmpty).join(', ');
    if (query.isEmpty) return;

    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Maps konnte nicht geöffnet werden.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeName = _text(widget.match['HeimMannschaft']);
    final guestName = _text(widget.match['GastMannschaft']);
    final homeLogo = ClubLogos.forClub(
      homeName,
      organisationId: _asInt(widget.match['HeimOrganisationsID']),
    );
    final guestLogo = ClubLogos.forClub(
      guestName,
      organisationId: _asInt(widget.match['GastOrganisationsID']),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF061E39),
      appBar: AppBar(
        title: const Text('Kampfdetails'),
        toolbarHeight: 56,
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF061E39),
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD9003D), Color(0xFF741044), Color(0xFF063662)],
            stops: [0, .46, 1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<List<dynamic>>(
          future: _singleMatches,
          builder: (context, snapshot) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _MatchSummary(
                  homeName: homeName,
                  guestName: guestName,
                  homeLogo: homeLogo,
                  guestLogo: guestLogo,
                  homeScore: _number(widget.match['PunkteHeimWertung']),
                  guestScore: _number(widget.match['PunkteGastWertung']),
                  date: _date(),
                  time: _text(
                    widget.match['Beginn'],
                    fallback: 'Uhrzeit folgt',
                  ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<Map<String, dynamic>?>(
                  future: _venue,
                  builder: (context, venueSnapshot) {
                    if (venueSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const _VenueLoading();
                    }
                    final venue = venueSnapshot.data;
                    if (venue == null) return const SizedBox.shrink();

                    return _VenueCard(
                      venueName: _text(
                        venue['name'],
                        fallback: 'Wettkampfstätte',
                      ),
                      address: _text(
                        venue['address'],
                        fallback: 'Ort nicht hinterlegt',
                      ),
                      onOpenMaps: () => _openGoogleMaps(venue),
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Einzelkämpfe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const _DetailStatus(
                    loading: true,
                    message: 'Einzelkämpfe werden geladen …',
                  )
                else if (snapshot.hasError)
                  const _DetailStatus(
                    message: 'Noch keine Einzelergebnisse verfügbar.',
                  )
                else if ((snapshot.data ?? []).isEmpty)
                  const _DetailStatus(
                    message: 'Noch keine Einzelergebnisse verfügbar.',
                  )
                else
                  ...(snapshot.data ?? []).map(
                    (singleMatch) => _SingleMatchCard(
                      weight: '${_text(singleMatch['Gewichtsklasse'])} kg',
                      style: _style(singleMatch['Stilart']),
                      homeName: _text(singleMatch['NameHeim']),
                      guestName: _text(singleMatch['NameGast']),
                      homePoints: _number(singleMatch['HPunkte']),
                      guestPoints: _number(singleMatch['GPUNKTE']),
                      result: _text(singleMatch['Wertung']),
                      duration: _duration(singleMatch['KampfzeitSekunden']),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
