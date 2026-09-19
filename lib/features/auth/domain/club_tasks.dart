/// Task flags take precedence; legacy roles support installations before migration.
bool hasTrainerTask(Map<String, dynamic> profile) =>
    profile['is_trainer'] as bool? ?? profile['role'] == 'trainer';
bool hasOrganizationTask(Map<String, dynamic> profile) =>
    profile['is_organization'] as bool? ?? profile['role'] == 'organization';
String clubTaskLabel(Map<String, dynamic> profile) => [
  if (profile['role'] == 'admin') 'Admin',
  if (hasTrainerTask(profile)) 'Trainer',
  if (hasOrganizationTask(profile)) 'Organisation',
].join(' · ');
