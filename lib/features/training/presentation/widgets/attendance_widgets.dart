part of '../screens/training_screen.dart';

class _AttendanceSheet extends StatelessWidget {
  const _AttendanceSheet({
    required this.session,
    required this.date,
    required this.response,
    required this.declineReason,
    required this.attendance,
    required this.showDeclineReasons,
  });

  final TrainingSession session;
  final DateTime date;
  final bool? response;
  final String? declineReason;
  final _AttendanceData attendance;
  final bool showDeclineReasons;

  @override
  Widget build(BuildContext context) {
    final accepted = attendance.accepted;
    final declined = attendance.declined;
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .78,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        shrinkWrap: true,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Teilnahmen',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${session.group} · $dateLabel · ${session.timeLabel} Uhr',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AttendanceSection(
            title: 'Zusagen',
            names: accepted,
            color: const Color(0xFF168A5B),
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(height: 12),
          _AttendanceSection(
            title: 'Absagen',
            names: declined,
            color: AppColors.red,
            icon: Icons.cancel_rounded,
            notes: showDeclineReasons ? attendance.declineReasons : const {},
            selfNote: response == false ? declineReason : null,
          ),
          if (response == null) ...[
            const SizedBox(height: 14),
            const Text(
              'Du hast noch nicht geantwortet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({
    required this.title,
    required this.names,
    required this.color,
    required this.icon,
    this.selfNote,
    this.notes = const {},
  });

  final String title;
  final List<String> names;
  final Color color;
  final IconData icon;
  final String? selfNote;
  final Map<String, String> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '$title (${names.length})',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...names.map(
            (name) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: .11),
                    child: Text(
                      name.characters.first,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (name == 'Du' && selfNote != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            selfNote!,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (notes[name] case final note?) ...[
                          const SizedBox(height: 2),
                          Text(
                            note,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceData {
  const _AttendanceData({
    required this.accepted,
    required this.declined,
    required this.declineReasons,
    required this.openCount,
  });

  final List<String> accepted;
  final List<String> declined;
  final Map<String, String> declineReasons;
  final int openCount;
}

class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : color,
        backgroundColor: selected ? color : Colors.transparent,
        side: BorderSide(color: color.withValues(alpha: selected ? 1 : .45)),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
