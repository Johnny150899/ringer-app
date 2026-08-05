import 'package:flutter/material.dart';
import '../../../../core/widgets/feature_placeholder.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.newspaper_rounded,
      title: 'News',
      description:
          'Neuigkeiten, Ergebnisse und Berichte aus dem Verein folgen in Kürze.',
    );
  }
}
