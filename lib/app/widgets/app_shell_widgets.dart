part of '../app_shell.dart';

class _SelectedNavIcon extends StatelessWidget {
  const _SelectedNavIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 19),
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
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 9),
      decoration: const BoxDecoration(
        color: Color(0x16000000),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Image.asset(
              ClubLogos.kscOlympiaGrabenNeudorf,
              fit: BoxFit.contain,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canManageUsers) ...[
                _HeaderAction(
                  key: const ValueKey('user-management-header-button'),
                  tooltip: 'Benutzer verwalten',
                  icon: Icons.manage_accounts_rounded,
                  onTap: onUserManagementTap,
                ),
                const SizedBox(width: 8),
              ],
              if (canReviewMemberships) ...[
                _HeaderAction(
                  key: const ValueKey('membership-requests-header-button'),
                  tooltip: 'Mitgliedsanträge',
                  icon: Icons.how_to_reg_rounded,
                  onTap: onMembershipRequestsTap,
                  badge: pendingMembershipCount > 0
                      ? pendingMembershipCount
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              _HeaderAction(
                key: const ValueKey('account-button'),
                tooltip: isAuthenticated ? 'Mein Konto' : 'Anmelden',
                icon: isAuthenticated ? Icons.person : Icons.person_outline,
                onTap: onAccountTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: .14),
        shape: const CircleBorder(side: BorderSide(color: Colors.white12)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 42,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 21, color: Colors.white),
                if (badge != null)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
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
    );
  }
}
