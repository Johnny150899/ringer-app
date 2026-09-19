import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/features/auth/domain/club_tasks.dart';

void main() {
  test('trainer and organization can coexist', () {
    final p = {'role': 'trainer', 'is_trainer': true, 'is_organization': true};
    expect(hasTrainerTask(p), isTrue);
    expect(hasOrganizationTask(p), isTrue);
    expect(clubTaskLabel(p), 'Trainer · Organisation');
  });
  test('admin rights and tasks are independent', () {
    expect(
      clubTaskLabel({
        'role': 'admin',
        'is_trainer': true,
        'is_organization': true,
      }),
      'Admin · Trainer · Organisation',
    );
    expect(hasTrainerTask({'role': 'admin'}), isFalse);
  });
  test('legacy assignments survive until migration', () {
    expect(hasTrainerTask({'role': 'trainer'}), isTrue);
    expect(hasOrganizationTask({'role': 'organization'}), isTrue);
    expect(clubTaskLabel({'role': 'member'}), isEmpty);
  });
  test('explicitly removed flags override legacy role', () {
    expect(hasTrainerTask({'role': 'trainer', 'is_trainer': false}), isFalse);
    expect(
      hasOrganizationTask({'role': 'organization', 'is_organization': false}),
      isFalse,
    );
  });
}
