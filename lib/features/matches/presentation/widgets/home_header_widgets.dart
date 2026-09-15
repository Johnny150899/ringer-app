part of '../screens/home_screen.dart';

class _TeamSwitcher extends StatelessWidget {
  const _TeamSwitcher({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      borderRadius: 15,
      padding: const EdgeInsets.all(3),
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
