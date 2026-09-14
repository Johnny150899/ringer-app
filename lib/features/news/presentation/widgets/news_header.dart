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
    if (!canPublish) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: AppGlassIconButton(
          tooltip: 'Vereinsbeitrag erstellen',
          icon: Icons.post_add_rounded,
          onPressed: onCreate,
          size: 42,
        ),
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
