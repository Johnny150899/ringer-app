part of '../screens/home_screen.dart';

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
