import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/club_logos.dart';
import '../features/auth/data/services/user_access_service.dart';
import '../features/auth/presentation/screens/account_gate_screen.dart';
import '../features/auth/presentation/screens/user_management_screen.dart';
import '../features/league/presentation/screens/league_screen.dart';
import '../features/livestream/presentation/screens/livestream_screen.dart';
import '../features/matches/presentation/screens/home_screen.dart';
import '../features/news/presentation/screens/news_screen.dart';
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
  final Set<int> _visitedTabs = {0};
  late bool _isAuthenticated;
  bool _hasMemberAccess = false;
  bool _canReviewMemberships = false;
  bool _isAdmin = false;
  bool _canPublishClubNews = false;
  bool _canRespondTraining = false;
  List<String> _trainingGroups = const [];
  int _pendingMembershipCount = 0;
  StreamSubscription<AuthState>? _authSubscription;
  UserAccessService? _userAccessService;
  bool _assetsPrecached = false;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = widget.supabaseClient?.auth.currentSession != null;
    final client = widget.supabaseClient;
    if (client != null) _userAccessService = UserAccessService(client);
    _refreshPermissions();
    _authSubscription = widget.supabaseClient?.auth.onAuthStateChange.listen((
      state,
    ) async {
      if (mounted) {
        setState(() => _isAuthenticated = state.session != null);
        _userAccessService?.invalidate();
        await _refreshPermissions(force: true);
      }
    });
  }

  Future<void> _refreshPermissions({bool force = false}) async {
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
      final access = await _userAccessService!.load(force: force);
      if (mounted) {
        setState(() {
          _hasMemberAccess = access.hasMemberAccess;
          _canReviewMemberships = access.canReviewMemberships;
          _isAdmin = access.isAdmin;
          _canPublishClubNews = access.canPublishClubNews;
          _canRespondTraining = access.canRespondTraining;
          _trainingGroups = access.trainingGroups;
          _pendingMembershipCount = access.pendingMembershipCount;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assetsPrecached) return;
    _assetsPrecached = true;
    precacheImage(const AssetImage(ClubLogos.kscOlympiaGrabenNeudorf), context);
    precacheImage(const AssetImage(ClubLogos.defaultLogo), context);
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
    _userAccessService?.invalidate();
    await _refreshPermissions(force: true);
  }

  Future<void> _openMembershipRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MembershipRequestsScreen()),
    );
    _userAccessService?.invalidate();
    await _refreshPermissions(force: true);
  }

  Future<void> _openUserManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserManagementScreen(canManageRoles: _isAdmin),
      ),
    );
    _userAccessService?.invalidate();
    await _refreshPermissions(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        supabaseClient: widget.supabaseClient,
        canManageAnnouncements: _canReviewMemberships,
      ),
      _visitedTabs.contains(1)
          ? TrainingScreen(
              memberAccess: _hasMemberAccess,
              isAdmin: _isAdmin,
              supabaseClient: widget.supabaseClient,
              canRespond: _canRespondTraining,
              trainingGroups: _trainingGroups,
              canManageSessions: _canReviewMemberships,
            )
          : const SizedBox.shrink(),
      _visitedTabs.contains(2)
          ? NewsScreen(
              supabaseClient: widget.supabaseClient,
              canPublishClubNews: _canPublishClubNews,
              isAdmin: _isAdmin,
            )
          : const SizedBox.shrink(),
      _visitedTabs.contains(3) ? const LeagueScreen() : const SizedBox.shrink(),
      _visitedTabs.contains(4)
          ? LivestreamScreen(
              isAuthenticated: _isAuthenticated,
              onLogin: _openAccount,
            )
          : const SizedBox.shrink(),
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.navy.withValues(alpha: .70),
                      AppColors.navigationBlue.withValues(alpha: .56),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .18),
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    splashFactory: NoSplash.splashFactory,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                  ),
                  child: NavigationBar(
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysHide,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) => setState(() {
                      _selectedIndex = index;
                      _visitedTabs.add(index);
                    }),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: _SelectedNavIcon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.fitness_center),
                        selectedIcon: _SelectedNavIcon(Icons.fitness_center),
                        label: 'Training',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.article_outlined),
                        selectedIcon: _SelectedNavIcon(Icons.article_rounded),
                        label: 'News',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.leaderboard_outlined),
                        selectedIcon: _SelectedNavIcon(
                          Icons.leaderboard_rounded,
                        ),
                        label: 'Liga',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.live_tv_outlined),
                        selectedIcon: _SelectedNavIcon(Icons.live_tv_rounded),
                        label: 'Live',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
