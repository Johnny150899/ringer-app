import 'package:supabase_flutter/supabase_flutter.dart';

class UserAccessSnapshot {
  const UserAccessSnapshot({
    this.hasMemberAccess = false,
    this.canReviewMemberships = false,
    this.isAdmin = false,
    this.canPublishClubNews = false,
    this.canRespondTraining = false,
    this.trainingGroups = const [],
    this.pendingMembershipCount = 0,
  });

  final bool hasMemberAccess;
  final bool canReviewMemberships;
  final bool isAdmin;
  final bool canPublishClubNews;
  final bool canRespondTraining;
  final List<String> trainingGroups;
  final int pendingMembershipCount;
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
    final profile = await _client
        .from('profiles')
        .select('role, membership_status, can_respond_training')
        .eq('id', user.id)
        .maybeSingle();
    final role = profile?['role'] as String?;
    final approved = profile?['membership_status'] == 'approved';
    final canReview = approved && (role == 'trainer' || role == 'admin');
    final results = await Future.wait<Object>([
      if (approved)
        _client
            .from('profile_training_groups')
            .select('group_name')
            .eq('user_id', user.id)
      else
        Future.value(const <Map<String, dynamic>>[]),
      if (canReview)
        _client
            .from('profiles')
            .count()
            .eq('role', 'member')
            .eq('membership_status', 'pending')
      else
        Future.value(0),
    ]);
    final rows = List<Map<String, dynamic>>.from(results[0] as List);
    final snapshot = UserAccessSnapshot(
      hasMemberAccess:
          approved &&
          (role == 'member' || role == 'trainer' || role == 'admin'),
      canReviewMemberships: canReview,
      isAdmin: approved && role == 'admin',
      canPublishClubNews:
          approved &&
          (role == 'trainer' || role == 'organization' || role == 'admin'),
      canRespondTraining: approved && profile?['can_respond_training'] == true,
      trainingGroups: rows
          .map((row) => row['group_name'] as String)
          .toList(growable: false),
      pendingMembershipCount: results[1] as int,
    );
    _cached = snapshot;
    return snapshot;
  }
}
