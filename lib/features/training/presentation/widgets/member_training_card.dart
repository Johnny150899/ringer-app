part of '../screens/training_screen.dart';

class _MemberTrainingCard extends StatelessWidget {
  const _MemberTrainingCard({
    required this.session,
    required this.date,
    required this.response,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenDetails,
    required this.canRespond,
    required this.attendance,
    required this.occurrence,
    required this.canManage,
    required this.onManage,
  });

  final TrainingSession session;
  final DateTime date;
  final bool? response;
  final VoidCallback onAccept;
  final ValueChanged<String> onDecline;
  final VoidCallback onOpenDetails;
  final bool canRespond;
  final Future<_AttendanceData> attendance;
  final Map<String, dynamic>? occurrence;
  final bool canManage;
  final VoidCallback onManage;

  Future<void> _requestDeclineReason(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var enteredReason = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Absage begründen'),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (value) => enteredReason = value,
            decoration: const InputDecoration(
              labelText: 'Grund',
              hintText: 'z. B. krank oder verhindert',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Bitte gib einen Grund an.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, enteredReason.trim());
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Absage speichern'),
          ),
        ],
      ),
    );
    if (reason != null) onDecline(reason);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(
            'training-${session.group}-${date.year}-${date.month}-${date.day}',
          ),
          onTap: onOpenDetails,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sports_kabaddi_rounded,
                      size: 21,
                      color: AppColors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.group,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (canManage)
                      IconButton(
                        tooltip: 'Einzeltermin bearbeiten',
                        visualDensity: VisualDensity.compact,
                        onPressed: onManage,
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${_TrainingScreenState._weekdays[session.weekday]} · ${session.timeLabel} Uhr',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (occurrence?['is_cancelled'] == true) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'TRAINING FÄLLT AUS',
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ] else if ((occurrence?['note'] as String? ?? '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    occurrence!['note'] as String,
                    style: const TextStyle(color: AppColors.red, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<_AttendanceData>(
                        future: attendance,
                        builder: (context, snapshot) {
                          final data = snapshot.data;
                          return Text(
                            data == null
                                ? 'Teilnahmen laden …'
                                : '${data.accepted.length} Zusagen · '
                                      '${data.declined.length} Absagen · '
                                      '${data.openCount} offen',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ],
                ),
                if (canRespond) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ResponseButton(
                          label: 'Zusagen',
                          icon: Icons.check_rounded,
                          selected: response == true,
                          color: const Color(0xFF168A5B),
                          onTap: onAccept,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ResponseButton(
                          label: 'Absagen',
                          icon: Icons.close_rounded,
                          selected: response == false,
                          color: AppColors.red,
                          onTap: () => _requestDeclineReason(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
