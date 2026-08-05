import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/club_logos.dart';
import '../features/auth/presentation/screens/account_gate_screen.dart';
import '../features/auth/presentation/screens/user_management_screen.dart';
import '../features/livestream/presentation/screens/livestream_screen.dart';
import '../features/matches/presentation/screens/home_screen.dart';
import '../features/news/presentation/screens/news_screen.dart';
import '../features/team/presentation/screens/team_screen.dart';
import '../features/training/presentation/screens/training_screen.dart';
import 'app_theme.dart';

part 'widgets/app_shell_widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.supabaseClient});

  final SupabaseClient? supabaseClient;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late bool _isAuthenticated;
  bool _hasMemberAccess = false;
  bool _canReviewMemberships = false;
  bool _isAdmin = false;
  bool _canPublishClubNews = false;
  bool _canRespondTraining = false;
  List<String> _trainingGroups = const [];
  int _pendingMembershipCount = 0;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = widget.supabaseClient?.auth.currentSession != null;
    _refreshPermissions();
    _authSubscription = widget.supabaseClient?.auth.onAuthStateChange.listen((
      state,
    ) async {
      if (mounted) {
        setState(() => _isAuthenticated = state.session != null);
        await _refreshPermissions();
      }
    });
  }

  Future<void> _refreshPermissions() async {
    final client = widget.supabaseClient;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      if (mounted) {
        setState(() {
          _hasMemberAccess = false;
          _canReviewMemberships = false;
          _isAdmin = false;
          _canPublishClubNews = false;
          _canRespondTraining = false;
          _trainingGroups = const [];
          _pendingMembershipCount = 0;
        });
      }
      return;
    }
    try {
      final profile = await client
          .from('profiles')
          .select(
            'role, membership_status, can_respond_training, training_group',
          )
          .eq('id', user.id)
          .maybeSingle();
      final role = profile?['role'] as String?;
      final approved = profile?['membership_status'] == 'approved';
      final trainingRows = approved
          ? await client
                .from('profile_training_groups')
                .select('group_name')
                .eq('user_id', user.id)
          : const <Map<String, dynamic>>[];
      final trainingGroups = List<Map<String, dynamic>>.from(
        trainingRows,
      ).map((row) => row['group_name'] as String).toList(growable: false);
      final canReview = approved && (role == 'trainer' || role == 'admin');
      var pendingCount = 0;
      if (canReview) {
        pendingCount = await client
            .from('profiles')
            .count()
            .eq('role', 'member')
            .eq('membership_status', 'pending');
      }
      if (mounted) {
        setState(() {
          _hasMemberAccess =
              approved &&
              (role == 'member' || role == 'trainer' || role == 'admin');
          _canReviewMemberships = canReview;
          _isAdmin = approved && role == 'admin';
          _canPublishClubNews =
              approved &&
              (role == 'trainer' || role == 'organization' || role == 'admin');
          _canRespondTraining =
              approved && profile?['can_respond_training'] == true;
          _trainingGroups = trainingGroups;
          _pendingMembershipCount = pendingCount;
        });
      }
    } on PostgrestException {
      if (mounted) {
        setState(() {
          _hasMemberAccess = false;
          _canReviewMemberships = false;
          _isAdmin = false;
          _canPublishClubNews = false;
          _canRespondTraining = false;
          _trainingGroups = const [];
          _pendingMembershipCount = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openAccount() async {
    final didLogin = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AccountGateScreen()));
    if (didLogin == true && mounted) {
      setState(() => _selectedIndex = 0);
    }
    await _refreshPermissions();
  }

  Future<void> _openMembershipRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MembershipRequestsScreen()),
    );
    await _refreshPermissions();
  }

  Future<void> _openUserManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserManagementScreen(canManageRoles: _isAdmin),
      ),
    );
    await _refreshPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        supabaseClient: widget.supabaseClient,
        canManageAnnouncements: _canReviewMemberships,
      ),
      TrainingScreen(
        memberAccess: _hasMemberAccess,
        isAdmin: _isAdmin,
        supabaseClient: widget.supabaseClient,
        canRespond: _canRespondTraining,
        trainingGroups: _trainingGroups,
        canManageSessions: _canReviewMemberships,
      ),
      NewsScreen(
        supabaseClient: widget.supabaseClient,
        canPublishClubNews: _canPublishClubNews,
        isAdmin: _isAdmin,
      ),
      const TeamScreen(),
      LivestreamScreen(
        isAuthenticated: _isAuthenticated,
        onLogin: _openAccount,
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _AppHeader(
                isAuthenticated: _isAuthenticated,
                canReviewMemberships: _canReviewMemberships,
                canManageUsers: _canReviewMemberships,
                pendingMembershipCount: _pendingMembershipCount,
                onAccountTap: _openAccount,
                onMembershipRequestsTap: _openMembershipRequests,
                onUserManagementTap: _openUserManagement,
              ),
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: screens),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Training',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article_rounded),
            label: 'News',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv_rounded),
            label: 'Live',
          ),
        ],
      ),
    );
  }
}
