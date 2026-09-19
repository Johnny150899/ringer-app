part of '../screens/user_management_screen.dart';

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onTap});
  final Map<String, dynamic> profile;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final name = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
        .trim();
    final roles = <String>[
      if (profile['membership_status'] == 'approved')
        'Mitglied'
      else if (profile['membership_status'] == 'pending')
        'Antrag offen'
      else
        'Fan',
      if (hasTrainerTask(profile)) 'Trainer',
      if (hasOrganizationTask(profile)) 'Organisation',
      if (profile['role'] == 'admin') 'Admin',
    ];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFCE8EF),
                child: Icon(Icons.person_outline, color: AppColors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Unbekanntes Profil' : name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: roles
                          .map(
                            (role) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F3F7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                role,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
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
