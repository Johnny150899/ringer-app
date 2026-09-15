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
    required this.title,
    required this.isAuthenticated,
    required this.canReviewMemberships,
    required this.canManageUsers,
    required this.pendingMembershipCount,
    required this.onAccountTap,
    required this.onLegalTap,
    required this.onMembershipRequestsTap,
    required this.onUserManagementTap,
  });

  final String title;
  final bool isAuthenticated;
  final bool canReviewMemberships;
  final bool canManageUsers;
  final int pendingMembershipCount;
  final VoidCallback onAccountTap;
  final VoidCallback onLegalTap;
  final VoidCallback onMembershipRequestsTap;
  final VoidCallback onUserManagementTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 9, 14, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x12000000), Color(0x26000000)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(bottom: BorderSide(color: Color(0x24FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox.square(
            dimension: 46,
            child: Image.asset(
              ClubLogos.kscOlympiaGrabenNeudorf,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                const SizedBox(width: 5),
              ],
              if (canReviewMemberships) ...[
                _HeaderAction(
                  key: const ValueKey('membership-requests-header-button'),
                  tooltip: 'Anträge',
                  icon: Icons.how_to_reg_rounded,
                  onTap: onMembershipRequestsTap,
                  badge: pendingMembershipCount > 0
                      ? pendingMembershipCount
                      : null,
                ),
                const SizedBox(width: 5),
              ],
              _HeaderMenu(
                isAuthenticated: isAuthenticated,
                onAccountTap: onAccountTap,
                onLegalTap: onLegalTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _HeaderMenuItem { account, legal }

class _HeaderMenu extends StatelessWidget {
  const _HeaderMenu({
    required this.isAuthenticated,
    required this.onAccountTap,
    required this.onLegalTap,
  });

  final bool isAuthenticated;
  final VoidCallback onAccountTap;
  final VoidCallback onLegalTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .1),
    shape: CircleBorder(
      side: BorderSide(color: Colors.white.withValues(alpha: .18)),
    ),
    child: SizedBox.square(
      dimension: 39,
      child: PopupMenuButton<_HeaderMenuItem>(
        key: const ValueKey('header-menu-button'),
        tooltip: 'Menü: Konto und Rechtliches',
        icon: const Icon(Icons.menu_rounded, color: Colors.white),
        iconSize: 22,
        padding: EdgeInsets.zero,
        onSelected: (item) {
          switch (item) {
            case _HeaderMenuItem.account:
              onAccountTap();
            case _HeaderMenuItem.legal:
              onLegalTap();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _HeaderMenuItem.account,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(isAuthenticated ? 'Mein Konto' : 'Anmelden'),
            ),
          ),
          const PopupMenuItem(
            value: _HeaderMenuItem.legal,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Info & Rechtliches'),
            ),
          ),
        ],
      ),
    ),
  );
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
        color: Colors.white.withValues(alpha: .1),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: .18)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 39,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.white),
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
