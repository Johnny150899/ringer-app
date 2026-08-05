import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/feature_placeholder.dart';

class LivestreamScreen extends StatelessWidget {
  const LivestreamScreen({
    super.key,
    required this.isAuthenticated,
    required this.onLogin,
  });

  final bool isAuthenticated;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    if (isAuthenticated) {
      return const FeaturePlaceholder(
        icon: Icons.live_tv_rounded,
        title: 'Livestream',
        description:
            'Sobald ein Kampf live übertragen wird, findest du den Stream hier.',
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Livestream für Fans',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Erstelle kostenlos ein Fan-Konto oder melde dich an, um unsere Livestreams zu sehen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('livestream-login-button'),
                  onPressed: onLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: const Text('Anmelden oder registrieren'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
