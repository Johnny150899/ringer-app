import 'package:flutter/material.dart';

import '../../../../core/widgets/app_glass_surface.dart';

class NewsHeader extends StatelessWidget {
  const NewsHeader({
    super.key,
    required this.canPublish,
    required this.onCreate,
  });

  final bool canPublish;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Neuigkeiten',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (canPublish)
                AppGlassIconButton(
                  tooltip: 'Vereinsbeitrag erstellen',
                  icon: Icons.post_add_rounded,
                  onPressed: onCreate,
                  size: 42,
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Aktuelles aus dem Verein und von Instagram',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class NewsSectionTitle extends StatelessWidget {
  const NewsSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 3, 20, 10),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
