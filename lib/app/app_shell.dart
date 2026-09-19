import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/club_logos.dart';
import '../features/auth/data/services/user_access_service.dart';
import '../features/auth/presentation/screens/account_gate_screen.dart';
import '../features/auth/presentation/screens/user_management_screen.dart';
import '../features/league/presentation/screens/league_screen.dart';
import '../features/legal/presentation/screens/legal_screen.dart';
import '../features/matches/domain/models/team_match.dart';
import '../features/matches/presentation/screens/home_screen.dart';
import '../features/news/presentation/screens/news_screen.dart';
import '../features/training/presentation/screens/training_screen.dart';
import 'app_theme.dart';

part 'widgets/app_shell_widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.supabaseClient,
    this.userAccessService,
    this.firstTeamMatchesFuture,
  });

  final SupabaseClient? supabaseClient;
  final UserAccessService? userAccessService;
  final Future<List<TeamMatch>>? firstTeamMatchesFuture;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _contentNavigator = GlobalKey<NavigatorState>();
  final _contentRoutes = _ContentRouteObserver();
  bool _changingTab = false;
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};
  late bool _isAuthenticated;
  String _role = 'fan';
  bool _hasMemberAccess = false;
  bool _hasClubAccess = false;
  bool _canReviewMemberships = false;
  bool _canProcessApplications = false;
  bool _isAdmin = false;
  bool _canPublishClubNews = false;
  bool _canRespondTraining = false;
  List<String> _trainingGroups = const [];
  int _pendingMembershipCount = 0;
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _profileChannel;
  UserAccessService? _userAccessService;
  bool _assetsPrecached = false;
  bool _membershipWelcomeOpen = false;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = widget.supabaseClient?.auth.currentSession != null;
    final client = widget.supabaseClient;
    if (client != null) {
      _userAccessService =
          widget.userAccessService ?? UserAccessService(client);
    }
    _subscribeToProfileChanges();
    _refreshPermissions();
    _authSubscription = widget.supabaseClient?.auth.onAuthStateChange.listen((
      state,
    ) async {
      if (mounted) {
        setState(() => _isAuthenticated = state.session != null);
        _userAccessService?.invalidate();
        _subscribeToProfileChanges();
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
          _role = 'fan';
          _hasMemberAccess = false;
          _hasClubAccess = false;
          _canReviewMemberships = false;
          _canProcessApplications = false;
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
          _role = access.role;
          _hasMemberAccess = access.hasMemberAccess;
          _hasClubAccess = access.hasClubAccess;
          _canReviewMemberships = access.canReviewMemberships;
          _canProcessApplications = access.canProcessApplications;
          _isAdmin = access.isAdmin;
          _canPublishClubNews = access.canPublishClubNews;
          _canRespondTraining = access.canRespondTraining;
          _trainingGroups = access.trainingGroups;
          _pendingMembershipCount = access.pendingMembershipCount;
        });
        _showMembershipWelcomeIfNeeded(access);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _role = 'fan';
          _hasMemberAccess = false;
          _hasClubAccess = false;
          _canReviewMemberships = false;
          _isAdmin = false;
          _canProcessApplications = false;
          _canPublishClubNews = false;
          _canRespondTraining = false;
          _trainingGroups = const [];
          _pendingMembershipCount = 0;
        });
      }
    }
  }

  void _subscribeToProfileChanges() {
    final client = widget.supabaseClient;
    final userId = client?.auth.currentUser?.id;
    final previous = _profileChannel;
    _profileChannel = null;
    if (client != null && previous != null) {
      unawaited(client.removeChannel(previous));
    }
    if (client == null || userId == null) return;
    _profileChannel = client
        .channel('own-profile-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) {
            _userAccessService?.invalidate();
            unawaited(_refreshPermissions(force: true));
          },
        )
        .subscribe();
  }

  void _showMembershipWelcomeIfNeeded(UserAccessSnapshot access) {
    if (!access.shouldShowMembershipWelcome || _membershipWelcomeOpen) return;
    _membershipWelcomeOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.verified_rounded,
            color: Color(0xFF168A5B),
            size: 42,
          ),
          title: const Text(
            'Mitgliedschaft bestätigt!',
            textAlign: TextAlign.center,
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Willkommen im Mitgliederbereich. Neu für dich:'),
              SizedBox(height: 14),
              _MembershipFeature(
                icon: Icons.event_available_rounded,
                text: 'Mitgliederansicht der Trainings',
              ),
              _MembershipFeature(
                icon: Icons.groups_rounded,
                text: 'Zu- und Absagen der Trainingsgruppe einsehen',
              ),
              _MembershipFeature(
                icon: Icons.card_giftcard_rounded,
                text: 'Mitgliedervorteile und Empfehlungscode',
              ),
              _MembershipFeature(
                icon: Icons.lock_open_rounded,
                text: 'Weitere interne Vereinsfunktionen',
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Los geht’s'),
            ),
          ],
        ),
      );
      try {
        await widget.supabaseClient?.rpc<void>(
          'acknowledge_membership_welcome',
        );
      } on PostgrestException {
        // Die Bestätigung wird beim nächsten Start erneut angeboten.
      } finally {
        _membershipWelcomeOpen = false;
        _userAccessService?.invalidate();
      }
    });
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
    final client = widget.supabaseClient;
    final channel = _profileChannel;
    if (client != null && channel != null) {
      unawaited(client.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _openAccount() async {
    final didLogin = await _contentNavigator.currentState!.push<bool>(
      MaterialPageRoute(builder: (_) => const AccountGateScreen()),
    );
    if (didLogin == true && mounted) {
      setState(() => _selectedIndex = 0);
    }
    _userAccessService?.invalidate();
    await _refreshPermissions(force: true);
  }

  void _openLegalHub() {
    _contentNavigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const LegalHubScreen()),
    );
  }

  Future<void> _openMembershipRequests() async {
    await _contentNavigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => MembershipRequestsScreen(
          memberships: _canProcessApplications,
          trials: _canReviewMemberships,
        ),
      ),
    );
    _userAccessService?.invalidate();
    await _refreshPermissions(force: true);
  }

  Future<void> _openUserManagement() async {
    await _contentNavigator.currentState!.push(
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
      HomeScreen(firstTeamMatchesFuture: widget.firstTeamMatchesFuture),
      _visitedTabs.contains(1)
          ? TrainingScreen(
              memberAccess: _hasMemberAccess,
              isAdmin: _isAdmin,
              supabaseClient: widget.supabaseClient,
              canRespond: _canRespondTraining,
              trainingGroups: _trainingGroups,
              canManageSessions: _canReviewMemberships,
              canReviewTrialRequests: _canReviewMemberships,
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
          ? MembershipTabScreen(
              isAuthenticated: _isAuthenticated,
              hasClubAccess: _hasClubAccess,
              role: _role,
              onLogin: _openAccount,
            )
          : const SizedBox.shrink(),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: NavigatorPopHandler<Object?>(
          onPopWithResult: (result) =>
              _contentNavigator.currentState!.maybePop(result),
          child: Navigator(
            key: _contentNavigator,
            observers: [_contentRoutes],
            onDidRemovePage: (_) {},
            pages: [
              MaterialPage<void>(
                key: const ValueKey('main-tabs'),
                child: DecoratedBox(
                  decoration: const BoxDecoration(),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _AppHeader(
                          title: const [
                            'Home',
                            'Training',
                            'News',
                            'Liga',
                            'Verein',
                          ][_selectedIndex],
                          isAuthenticated: _isAuthenticated,
                          canReviewMemberships:
                              _canReviewMemberships || _canProcessApplications,
                          canManageUsers: _canReviewMemberships,
                          pendingMembershipCount: _pendingMembershipCount,
                          onAccountTap: _openAccount,
                          onLegalTap: _openLegalHub,
                          onMembershipRequestsTap: _openMembershipRequests,
                          onUserManagementTap: _openUserManagement,
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: screens,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
                        AppColors.navy.withValues(alpha: .45),
                        AppColors.navigationBlue.withValues(alpha: .32),
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
                      onDestinationSelected: (index) async {
                        if (_changingTab) return;
                        _changingTab = true;
                        try {
                          final navigator = _contentNavigator.currentState!;
                          while (navigator.canPop()) {
                            final previous = _contentRoutes.top;
                            if (!await navigator.maybePop() || !mounted) return;
                            if (identical(previous, _contentRoutes.top)) return;
                          }
                          if (!mounted) return;
                          setState(() {
                            _selectedIndex = index;
                            _visitedTabs.add(index);
                          });
                        } finally {
                          _changingTab = false;
                        }
                      },
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
                          icon: Icon(Icons.groups_outlined),
                          selectedIcon: _SelectedNavIcon(Icons.groups_rounded),
                          label: 'Verein',
                        ),
                      ],
                    ),
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

class _ContentRouteObserver extends NavigatorObserver {
  Route<dynamic>? top;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = route;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = previousRoute;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(top, route)) top = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (identical(top, oldRoute)) top = newRoute;
  }
}

class _MembershipFeature extends StatelessWidget {
  const _MembershipFeature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.red, size: 21),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
