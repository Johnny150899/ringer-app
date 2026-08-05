import 'package:flutter/material.dart';
import '../../../../core/widgets/feature_placeholder.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.fitness_center_rounded,
      title: 'Training',
      description:
          'Trainingszeiten, Einheiten und wichtige Hinweise erscheinen bald hier.',
    );
  }
}
