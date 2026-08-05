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
      const NewsScreen(),
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

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.isAuthenticated,
    required this.canReviewMemberships,
    required this.canManageUsers,
    required this.pendingMembershipCount,
    required this.onAccountTap,
    required this.onMembershipRequestsTap,
    required this.onUserManagementTap,
  });

  final bool isAuthenticated;
  final bool canReviewMemberships;
  final bool canManageUsers;
  final int pendingMembershipCount;
  final VoidCallback onAccountTap;
  final VoidCallback onMembershipRequestsTap;
  final VoidCallback onUserManagementTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      decoration: const BoxDecoration(
        color: Color(0x10000000),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            ClubLogos.kscOlympiaGrabenNeudorf,
            width: 42,
            height: 42,
            fit: BoxFit.contain,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canManageUsers) ...[
                Material(
                  color: Colors.white24,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('user-management-header-button'),
                    customBorder: const CircleBorder(),
                    onTap: onUserManagementTap,
                    child: const SizedBox.square(
                      dimension: 38,
                      child: Icon(
                        Icons.manage_accounts_rounded,
                        size: 21,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (canReviewMemberships) ...[
                Material(
                  color: Colors.white24,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('membership-requests-header-button'),
                    customBorder: const CircleBorder(),
                    onTap: onMembershipRequestsTap,
                    child: SizedBox.square(
                      dimension: 38,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.how_to_reg_rounded,
                            size: 21,
                            color: Colors.white,
                          ),
                          if (pendingMembershipCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.red,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  pendingMembershipCount > 99
                                      ? '99+'
                                      : '$pendingMembershipCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Material(
                color: Colors.white24,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('account-button'),
                  customBorder: const CircleBorder(),
                  onTap: onAccountTap,
                  child: SizedBox.square(
                    dimension: 38,
                    child: Icon(
                      isAuthenticated ? Icons.person : Icons.person_outline,
                      size: 21,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
