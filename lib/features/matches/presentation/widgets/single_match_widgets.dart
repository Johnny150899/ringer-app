part of '../screens/match_detail_screen.dart';

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

  double? _pointValue(String value) {
    return double.tryParse(value.replaceAll(',', '.'));
  }

  Color _nameColor({required bool home}) {
    final homeValue = _pointValue(homePoints);
    final guestValue = _pointValue(guestPoints);
    if (homeValue == null || guestValue == null || homeValue == guestValue) {
      return const Color(0xFF101828);
    }
    if (home && homeValue > guestValue) return const Color(0xFFE4003A);
    if (!home && guestValue > homeValue) return const Color(0xFF1565C0);
    return const Color(0xFF101828);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _InfoChip(label: weight),
              const SizedBox(width: 5),
              _InfoChip(label: style, secondary: true),
              const Spacer(),
              Text(
                result,
                style: const TextStyle(
                  color: Color(0xFFE4003A),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  homeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _nameColor(home: true),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _Points(home: homePoints, guest: guestPoints),
              Expanded(
                child: Text(
                  guestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _nameColor(home: false),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (duration != '–') ...[
            const SizedBox(height: 5),
            Text(
              duration,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 10),
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
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF061E39),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$home : $guest',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
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
