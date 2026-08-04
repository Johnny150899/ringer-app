import 'package:flutter/material.dart';
import '../widgets/feature_placeholder.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.groups_rounded,
      title: 'Mannschaft',
      description: 'Lerne unsere Ringer, Trainer und das gesamte Team kennen.',
    );
  }
}
