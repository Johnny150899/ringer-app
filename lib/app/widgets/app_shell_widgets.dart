part of '../app_shell.dart';

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
