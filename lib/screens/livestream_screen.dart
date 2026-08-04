import 'package:flutter/material.dart';
import '../widgets/feature_placeholder.dart';

class LivestreamScreen extends StatelessWidget {
  const LivestreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.live_tv_rounded,
      title: 'Livestream',
      description:
          'Sobald ein Kampf live übertragen wird, findest du den Stream hier.',
    );
  }
}
