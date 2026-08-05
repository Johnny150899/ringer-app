part of '../screens/training_screen.dart';

class _TrainingGroupCard extends StatelessWidget {
  const _TrainingGroupCard({
    required this.group,
    required this.sessions,
    required this.weekdayLabel,
    required this.canEdit,
    required this.onEdit,
  });

  final String group;
  final List<TrainingSession> sessions;
  final String Function(int weekday) weekdayLabel;
  final bool canEdit;
  final ValueChanged<TrainingSession> onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.sports_kabaddi_rounded,
                  size: 21,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE4E7EC)),
          ),
          ...sessions.map(
            (session) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      weekdayLabel(session.weekday),
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${session.timeLabel} Uhr',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (canEdit) ...[
                    const Spacer(),
                    IconButton(
                      tooltip: 'Trainingszeit bearbeiten',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onEdit(session),
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
