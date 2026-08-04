import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/club_logos.dart';
import '../services/ligadb_service.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({super.key, required this.match});

  final Map<String, dynamic> match;

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
    _singleMatches = _service.getSingleMatches(
      _asInt(widget.match['BegegnungsID']) ?? 0,
    );
    _venue = _service.getVenueForMatch(widget.match);
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
                      isExactAddress: venue['isExactAddress'] == true,
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

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venueName,
    required this.address,
    required this.isExactAddress,
    required this.onOpenMaps,
  });

  final String venueName;
  final String address;
  final bool isExactAddress;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF061E39).withValues(alpha: .88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.location_on_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExactAddress
                      ? 'WETTKAMPFSTÄTTE LAUT LIGADB'
                      : 'AUSTRAGUNGSORT LAUT LIGADB',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  venueName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: onOpenMaps,
            tooltip: 'In Google Maps öffnen',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE4003A),
              foregroundColor: Colors.white,
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.all(9),
            ),
            icon: const Icon(Icons.map_rounded),
          ),
        ],
      ),
    );
  }
}

class _VenueLoading extends StatelessWidget {
  const _VenueLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.3, color: Colors.white),
      ),
    );
  }
}

class _MatchSummary extends StatelessWidget {
  const _MatchSummary({
    required this.homeName,
    required this.guestName,
    required this.homeLogo,
    required this.guestLogo,
    required this.homeScore,
    required this.guestScore,
    required this.date,
    required this.time,
  });

  final String homeName;
  final String guestName;
  final String homeLogo;
  final String guestLogo;
  final String homeScore;
  final String guestScore;
  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryTeam(name: homeName, logo: homeLogo),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Text(
                      '$homeScore : $guestScore',
                      style: const TextStyle(
                        color: Color(0xFF061E39),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'ERGEBNIS',
                      style: TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 9,
                        letterSpacing: .7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _SummaryTeam(name: guestName, logo: guestLogo),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE4E7EC)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Color(0xFFE4003A),
              ),
              const SizedBox(width: 6),
              Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 18),
              const Icon(
                Icons.schedule_rounded,
                size: 17,
                color: Color(0xFFE4003A),
              ),
              const SizedBox(width: 6),
              Text(time, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTeam extends StatelessWidget {
  const _SummaryTeam({required this.name, required this.logo});

  final String name;
  final String logo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Image.asset(logo, fit: BoxFit.contain),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF101828),
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SingleMatchCard extends StatelessWidget {
  const _SingleMatchCard({
    required this.weight,
    required this.style,
    required this.homeName,
    required this.guestName,
    required this.homePoints,
    required this.guestPoints,
    required this.result,
    required this.duration,
  });

  final String weight;
  final String style;
  final String homeName;
  final String guestName;
  final String homePoints;
  final String guestPoints;
  final String result;
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _InfoChip(label: weight),
              const SizedBox(width: 7),
              _InfoChip(label: style, secondary: true),
              const Spacer(),
              Text(
                result,
                style: const TextStyle(
                  color: Color(0xFFE4003A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text(
                  homeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _Points(home: homePoints, guest: guestPoints),
              Expanded(
                child: Text(
                  guestName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (duration != '–') ...[
            const SizedBox(height: 9),
            Text(
              duration,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _Points extends StatelessWidget {
  const _Points({required this.home, required this.guest});

  final String home;
  final String guest;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF061E39),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$home : $guest',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.secondary = false});

  final String label;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: secondary ? const Color(0xFFEAECF0) : const Color(0xFFE4003A),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: secondary ? const Color(0xFF344054) : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailStatus extends StatelessWidget {
  const _DetailStatus({required this.message, this.loading = false});

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.info_outline_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
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
