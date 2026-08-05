part of '../screens/user_management_screen.dart';

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.processing,
    required this.onRoleChanged,
    required this.onConfigureTraining,
    required this.canManageRoles,
  });

  final Map<String, dynamic> profile;
  final bool processing;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onConfigureTraining;
  final bool canManageRoles;

  @override
  Widget build(BuildContext context) {
    final firstName = profile['first_name'] as String? ?? '';
    final lastName = profile['last_name'] as String? ?? '';
    final combinedName = '$firstName $lastName'.trim();
    final name = combinedName.isEmpty ? 'Unbekanntes Profil' : combinedName;
    final role = profile['role'] as String? ?? 'fan';
    final status = profile['membership_status'] as String? ?? 'not_requested';
    final color = _UserManagementScreenState._roleColor(role);
    final trainingGroups = List<Map<String, dynamic>>.from(
      profile['profile_training_groups'] as List? ?? const [],
    ).map((row) => row['group_name'] as String).toList(growable: false);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: const Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (trainingGroups.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Aktiver Ringer · ${trainingGroups.join(', ')}',
                        style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      status == 'pending'
                          ? 'Mitgliedschaft offen'
                          : status == 'rejected'
                          ? 'Antrag abgelehnt'
                          : status == 'approved'
                          ? 'Freigeschaltet'
                          : 'Fan-Konto',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (processing)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (canManageRoles)
                PopupMenuButton<String>(
                  tooltip: 'Rolle ändern',
                  initialValue: role,
                  onSelected: onRoleChanged,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'fan', child: Text('Fan')),
                    PopupMenuItem(value: 'member', child: Text('Mitglied')),
                    PopupMenuItem(value: 'trainer', child: Text('Trainer')),
                    PopupMenuItem(
                      value: 'organization',
                      child: Text('Organisation'),
                    ),
                    PopupMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _UserManagementScreenState._roleLabel(role),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.expand_more_rounded, size: 17, color: color),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: processing ? null : onConfigureTraining,
              icon: const Icon(Icons.sports_kabaddi_rounded, size: 17),
              label: Text(
                trainingGroups.isEmpty
                    ? 'Trainingsgruppen festlegen'
                    : 'Trainingsgruppen bearbeiten',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 44,
          ),
          const SizedBox(height: 10),
          const Text(
            'Benutzer konnten nicht geladen werden.',
            style: TextStyle(color: Colors.white),
          ),
          TextButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
        ],
      ),
    );
  }
}
