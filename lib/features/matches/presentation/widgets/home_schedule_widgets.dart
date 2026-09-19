part of '../screens/home_screen.dart';

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
  const _NoUpcomingMatches({
    this.seasonCompleted = false,
    required this.season,
    required this.onOpenTable,
  });
  final bool seasonCompleted;
  final int season;
  final VoidCallback onOpenTable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (seasonCompleted) ...[
                  Text(
                    'Saison $season abgeschlossen',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  seasonCompleted
                      ? 'Im September geht’s wieder auf die Matte. Sobald die neuen Kampftermine feststehen, findest du sie hier.'
                      : 'Aktuell ist kein weiterer Kampf geplant.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (seasonCompleted) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onOpenTable,
                    icon: const Icon(Icons.leaderboard_outlined),
                    label: const Text('Zur Saisontabelle'),
                  ),
                ],
              ],
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
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final bool loading;
  final VoidCallback? onRetry;

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
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
