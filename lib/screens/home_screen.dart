import 'package:flutter/material.dart';

import '../services/ligadb_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _text(dynamic value, {String fallback = 'Noch offen'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String _teams(dynamic match) {
    final home = _text(match['HeimMannschaft'], fallback: 'Heimteam');
    final guest = _text(match['GastMannschaft'], fallback: 'Gastteam');
    return '$home  vs  $guest';
  }

  String _schedule(dynamic match) {
    final date = _text(match['KampfTagIst'], fallback: 'Termin folgt');
    final time = _text(match['Beginn'], fallback: 'Uhrzeit folgt');
    return '$date · $time';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: LigaDbService().getAllKscMatches(),
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

        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return const _StatusView(
            icon: Icons.event_busy_rounded,
            message: 'Aktuell sind keine Kämpfe eingetragen.',
          );
        }

        final nextMatch = matches.first;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
          children: [
            const Text(
              'Bereit für den nächsten Kampf?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Alle Termine des KSC Olympia auf einen Blick.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4003A),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'NÄCHSTER KAMPF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: .7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _teams(nextMatch),
                    style: const TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 22,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 20,
                        color: Color(0xFFE4003A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _schedule(nextMatch),
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle(title: 'Kommende Kämpfe'),
            const SizedBox(height: 12),
            ...matches
                .skip(1)
                .take(5)
                .map(
                  (match) => _MatchCard(
                    teams: _teams(match),
                    schedule: _schedule(match),
                  ),
                ),
          ],
        );
      },
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

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.teams, required this.schedule});

  final String teams;
  final String schedule;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE4003A).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.sports_mma_rounded,
              color: Color(0xFFE4003A),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teams,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  schedule,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
        ],
      ),
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
