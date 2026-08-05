part of '../screens/match_detail_screen.dart';

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
