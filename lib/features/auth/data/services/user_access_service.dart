import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/club_tasks.dart';

class UserAccessSnapshot {
  const UserAccessSnapshot({
    this.role = 'fan',
    this.hasMemberAccess = false,
    this.hasClubAccess = false,
    this.canReviewMemberships = false,
    this.canProcessApplications = false,
    this.isAdmin = false,
    this.canPublishClubNews = false,
    this.canRespondTraining = false,
    this.trainingGroups = const [],
    this.pendingMembershipCount = 0,
    this.shouldShowMembershipWelcome = false,
  });

  final String role;
  final bool hasMemberAccess;
  final bool hasClubAccess;
  final bool canReviewMemberships;
  final bool canProcessApplications;
  final bool isAdmin;
  final bool canPublishClubNews;
  final bool canRespondTraining;
  final List<String> trainingGroups;
  final int pendingMembershipCount;
  final bool shouldShowMembershipWelcome;
}

class UserAccessService {
  UserAccessService(this._client);

  final SupabaseClient _client;
  UserAccessSnapshot? _cached;
  Future<UserAccessSnapshot>? _inFlight;

  Future<UserAccessSnapshot> load({bool force = false}) {
    if (!force && _cached != null) return Future.value(_cached);
    if (!force && _inFlight != null) return _inFlight!;
    final request = _loadRemote();
    _inFlight = request;
    return request.whenComplete(() => _inFlight = null);
  }

  void invalidate() => _cached = null;

  Future<UserAccessSnapshot> _loadRemote() async {
    final user = _client.auth.currentUser;
    if (user == null) return const UserAccessSnapshot();
    Map<String, dynamic>? profile;
    try {
      profile = await _client
          .from('profiles')
          .select(
            'role, is_trainer, is_organization, membership_status, can_respond_training, '
            'membership_approved_at, membership_welcome_seen_at',
          )
          .eq('id', user.id)
          .maybeSingle();
    } on PostgrestException {
      // Abwärtskompatibel, solange die Welcome-Migration noch nicht läuft.
      profile = await _client
          .from('profiles')
          .select('role, membership_status, can_respond_training')
          .eq('id', user.id)
          .maybeSingle();
    }
    final role = profile?['role'] as String?;
    final approved = profile?['membership_status'] == 'approved';
    final trainer = hasTrainerTask(profile ?? {});
    final organization = hasOrganizationTask(profile ?? {});
    final canReview = approved && (trainer || role == 'admin');
    var canProcess = false;
    if (approved) {
      try {
        canProcess = await _client.rpc<bool>(
          'can_process_membership_applications',
        );
      } on PostgrestException {
        /* Migration required; do not grant access by default. */
      }
    }
    final results = await Future.wait<Object>([
      if (approved)
        _client
            .from('profile_training_groups')
            .select('group_name')
            .eq('user_id', user.id)
      else
        Future.value(const <Map<String, dynamic>>[]),
      if (canProcess)
        _client.from('membership_applications').count().inFilter('status', [
          'received',
          'processing',
        ])
      else
        Future.value(0),
      if (canReview)
        _client.from('trial_training_requests').count().eq('status', 'open')
      else
        Future.value(0),
    ]);
    final rows = List<Map<String, dynamic>>.from(results[0] as List);
    final snapshot = UserAccessSnapshot(
      role: role ?? 'fan',
      hasMemberAccess: approved && (role != null && role != 'fan'),
      hasClubAccess: approved && role != null && role != 'fan',
      canReviewMemberships: canReview,
      canProcessApplications: canProcess,
      isAdmin: approved && role == 'admin',
      canPublishClubNews:
          approved && (trainer || organization || role == 'admin'),
      canRespondTraining: approved && profile?['can_respond_training'] == true,
      trainingGroups: rows
          .map((row) => row['group_name'] as String)
          .toList(growable: false),
      pendingMembershipCount: (results[1] as int) + (results[2] as int),
      shouldShowMembershipWelcome:
          approved &&
          role == 'member' &&
          profile?['membership_approved_at'] != null &&
          profile?['membership_welcome_seen_at'] == null,
    );
    _cached = snapshot;
    return snapshot;
  }
}
